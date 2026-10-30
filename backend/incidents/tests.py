import io
import uuid
from unittest import mock

from django.core.files.uploadedfile import SimpleUploadedFile
from PIL import Image

from core.constants import ACCEPTE, AFFECTE, ANNULE, EN_COURS, NOUVEAU, REFUSE, RESOLU
from core.tests_utils import SenAlertTestCase
from notifications.models import Notification

from .models import EvenementDossier, Incident, PieceJointe

URL = '/api/incidents/'


class CreationIncidentTests(SenAlertTestCase):
    def setUp(self):
        super().setUp()
        self.awa = self.en_tant_que(self.citoyen())

    def test_creation_avec_reference_service_et_historique(self):
        r = self.client.post(URL, self.incident_payload(), format='json')
        self.assertEqual(r.status_code, 201, r.data)
        self.assertRegex(r.data['reference'], r'^INC-\d{4}-\d{6}$')
        self.assertEqual(r.data['statut'], NOUVEAU)
        self.assertEqual(r.data['service_nom'], 'Sapeurs-pompiers')  # service par défaut de la catégorie
        self.assertEqual(r.data['gravite'], 'elevee')
        inc = Incident.objects.get()
        self.assertEqual(inc.citoyen, self.awa)
        self.assertTrue(EvenementDossier.objects.filter(incident=inc, type='creation').exists())
        # Visible dans l'historique du citoyen
        self.assertEqual(self.client.get(URL).data['count'], 1)

    def test_categorie_inconnue_refusee(self):
        r = self.client.post(URL, self.incident_payload(type_incident='martien'), format='json')
        self.assertEqual(r.status_code, 400)

    def test_position_obligatoire_et_dans_le_senegal(self):
        p = self.incident_payload()
        del p['latitude'], p['longitude']
        self.assertEqual(self.client.post(URL, p, format='json').status_code, 400)
        r = self.client.post(URL, self.incident_payload(latitude=48.85, longitude=2.35), format='json')
        self.assertEqual(r.status_code, 400)
        self.assertIn('Sénégal', r.data['detail'])

    def test_region_estimee_depuis_la_position(self):
        p = self.incident_payload(latitude=16.03, longitude=-16.48)
        del p['region']
        r = self.client.post(URL, p, format='json')
        self.assertEqual(r.data['region'], 'saint_louis')

    def test_autre_exige_une_description(self):
        r = self.client.post(URL, self.incident_payload(type_incident='autre', description=''), format='json')
        self.assertEqual(r.status_code, 400)

    def test_idempotence_double_envoi(self):
        """Scénario 10 : une requête répétée ne crée pas plusieurs dossiers."""
        cle = str(uuid.uuid4())
        r1 = self.client.post(URL, self.incident_payload(client_request_id=cle), format='json')
        r2 = self.client.post(URL, self.incident_payload(client_request_id=cle), format='json')
        self.assertEqual((r1.status_code, r2.status_code), (201, 200))
        self.assertEqual(r1.data['reference'], r2.data['reference'])
        self.assertEqual(Incident.objects.count(), 1)

    def test_photo_reencodee_sans_exif(self):
        img = Image.new('RGB', (80, 60), 'red')
        exif = Image.Exif()
        exif[0x8825] = {2: (14.0, 41.0, 0.0)}  # bloc GPS
        f = io.BytesIO()
        img.save(f, 'JPEG', exif=exif)
        photo = SimpleUploadedFile('p.jpg', f.getvalue(), content_type='image/jpeg')
        r = self.client.post(URL, {**self.incident_payload(), 'photos': [photo]}, format='multipart')
        self.assertEqual(r.status_code, 201, r.data)
        pj = PieceJointe.objects.get()
        with pj.fichier.open('rb') as fh:
            self.assertFalse(Image.open(fh).getexif())
        # Le fichier n'est servi qu'au propriétaire (et aux agents/superadmin autorisés).
        self.assertEqual(self.client.get(r.data['photos'][0]['url']).status_code, 200)
        self.en_tant_que(self.citoyen('intrus'))
        self.assertEqual(self.client.get(r.data['photos'][0]['url']).status_code, 404)

    def test_fichier_non_image_refuse(self):
        faux = SimpleUploadedFile('virus.jpg', b'MZ\x90\x00 pas une image', content_type='image/jpeg')
        r = self.client.post(URL, {**self.incident_payload(), 'photos': [faux]}, format='multipart')
        self.assertEqual(r.status_code, 400)
        self.assertEqual(Incident.objects.count(), 0, 'aucun dossier partiel')

    def test_fichier_trop_lourd_refuse(self):
        with self.settings(PIECE_JOINTE_TAILLE_MAX=100):
            photo = SimpleUploadedFile('p.png', self.image().read(), content_type='image/png')
            r = self.client.post(URL, {**self.incident_payload(), 'photos': [photo]}, format='multipart')
        self.assertEqual(r.status_code, 400)

    def test_agent_ne_cree_pas_de_signalement(self):
        self.en_tant_que(self.agent())
        self.assertEqual(self.client.post(URL, self.incident_payload(), format='json').status_code, 403)

    def test_non_authentifie(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.client.get(URL).status_code, 401)
        self.assertEqual(self.client.post(URL, self.incident_payload(), format='json').status_code, 401)

    def test_doublon_potentiel_detecte(self):
        self.client.post(URL, self.incident_payload(), format='json')
        r = self.client.post(URL, self.incident_payload(latitude=14.7005), format='json')
        inc = Incident.objects.get(reference=r.data['reference'])
        self.assertIsNotNone(inc.doublon_potentiel_de)
        self.assertNotIn('doublon_potentiel_de', r.data, 'information réservée au superadmin')


class VisibiliteTests(SenAlertTestCase):
    def setUp(self):
        super().setUp()
        self.awa = self.citoyen('awa')
        self.inc = Incident.objects.create(citoyen=self.awa, type_incident='incendie', latitude=14.7, longitude=-17.45,
                                           region='dakar', service_id=self.service('pompiers'))

    def service(self, code):
        from core.models import Service
        return Service.objects.get(code=code).pk

    def test_citoyen_ne_voit_que_ses_dossiers(self):
        """Scénario 6 : accès refusé aux données d'un autre compte."""
        self.en_tant_que(self.citoyen('intrus'))
        self.assertEqual(self.client.get(URL).data['count'], 0)
        self.assertEqual(self.client.get(f'{URL}{self.inc.pk}/').status_code, 404)
        self.assertEqual(self.client.post(f'{URL}{self.inc.pk}/annuler/', {'motif': 'x'}, format='json').status_code, 404)

    def test_agent_du_bon_service_et_de_la_zone(self):
        self.en_tant_que(self.agent('pompier', 'pompiers', ['dakar']))
        self.assertEqual(self.client.get(URL).data['count'], 1)

    def test_agent_autre_service_ou_autre_zone(self):
        self.en_tant_que(self.agent('policier', 'police', ['dakar']))
        self.assertEqual(self.client.get(URL).data['count'], 0)
        self.assertEqual(self.client.get(f'{URL}{self.inc.pk}/').status_code, 404)
        self.en_tant_que(self.agent('pompier_matam', 'pompiers', ['matam']))
        self.assertEqual(self.client.get(URL).data['count'], 0)

    def test_contact_citoyen_reserve_agent_affecte(self):
        self.awa.telephone = '771234567'
        self.awa.save()
        pompier = self.agent('pompier', 'pompiers', ['dakar'])
        self.en_tant_que(pompier)
        self.assertIsNone(self.client.get(f'{URL}{self.inc.pk}/').data['citoyen_contact'])
        self.client.post(f'{URL}{self.inc.pk}/prendre-en-charge/')
        self.assertEqual(self.client.get(f'{URL}{self.inc.pk}/').data['citoyen_contact']['telephone'], '771234567')

    def test_carte_minimale_et_arrondie(self):
        self.en_tant_que(self.citoyen('autre'))
        r = self.client.get(f'{URL}carte/')
        self.assertEqual(len(r.data['resultats']), 1)
        point = r.data['resultats'][0]
        self.assertNotIn('description', point)
        self.assertEqual(point['latitude'], round(self.inc.latitude, 3))


class WorkflowTests(SenAlertTestCase):
    def setUp(self):
        super().setUp()
        self.awa = self.citoyen('awa')
        self.chef = self.superadmin()
        self.pompier = self.agent('pompier', 'pompiers', ['dakar'])
        self.en_tant_que(self.awa)
        self.ref = self.client.post(URL, self.incident_payload(), format='json').data
        self.url = f"{URL}{self.ref['id']}/"

    def action(self, user, nom, **data):
        self.en_tant_que(user)
        with self.captureOnCommitCallbacks(execute=True):
            return self.client.post(f'{self.url}{nom}/', data, format='json')

    def test_parcours_complet(self):
        """Scénarios 2, 3, 4 : affectation, acceptation, mise à jour, suivi par le citoyen."""
        r = self.action(self.chef, 'affecter', agent=self.pompier.pk)
        self.assertEqual(r.status_code, 200, r.data)
        self.assertEqual(r.data['statut'], AFFECTE)
        self.assertTrue(Notification.objects.filter(destinataire=self.pompier, type='affectation').exists())

        self.assertEqual(self.action(self.pompier, 'accepter').data['statut'], ACCEPTE)
        self.assertEqual(self.action(self.pompier, 'demarrer').data['statut'], EN_COURS)
        r = self.action(self.pompier, 'resoudre', compte_rendu='Feu maîtrisé, aucun blessé.', difficultes='Accès étroit')
        self.assertEqual(r.data['statut'], RESOLU)

        self.en_tant_que(self.awa)
        d = self.client.get(self.url).data
        self.assertEqual(d['statut'], RESOLU)
        self.assertIsNotNone(d['date_prise_en_charge'])
        self.assertEqual(d['intervention']['compte_rendu'], 'Feu maîtrisé, aucun blessé.')
        self.assertNotIn('difficultes', d['intervention'])
        self.assertEqual(d['intervention']['agent_nom'], 'Agent de secours', "pas d'identité de l'agent")
        evs = self.client.get(f'{self.url}evenements/').data
        self.assertEqual([e['statut_apres'] for e in evs if e['type'] == 'transition'], [AFFECTE, ACCEPTE, EN_COURS, RESOLU])
        self.assertFalse(any(e['type'] == 'affectation' for e in evs), 'événements internes masqués')
        types_notif = set(Notification.objects.filter(destinataire=self.awa).values_list('type', flat=True))
        self.assertEqual(types_notif, {'statut', 'resolution'})

    def test_compte_rendu_obligatoire(self):
        self.action(self.pompier, 'prendre-en-charge')
        r = self.action(self.pompier, 'resoudre', compte_rendu='ok')
        self.assertEqual(r.status_code, 400)

    def test_transition_invalide_409(self):
        r = self.action(self.pompier, 'demarrer')
        self.assertEqual(r.status_code, 409)  # « nouveau » : le démarrage est impossible
        self.action(self.pompier, 'prendre-en-charge')
        r = self.action(self.pompier, 'accepter')
        self.assertEqual(r.status_code, 409)

    def test_concurrence_deux_agents(self):
        autre = self.agent('pompier2', 'pompiers', ['dakar'])
        self.assertEqual(self.action(self.pompier, 'prendre-en-charge').status_code, 200)
        self.assertEqual(self.action(autre, 'prendre-en-charge').status_code, 404)  # n'est plus visible

    def test_agent_ne_peut_pas_affecter(self):
        self.assertEqual(self.action(self.pompier, 'affecter', agent=self.pompier.pk).status_code, 403)

    def test_decliner_remet_en_nouveau(self):
        self.action(self.chef, 'affecter', agent=self.pompier.pk)
        r = self.action(self.pompier, 'decliner', motif='Équipe déjà engagée')
        self.assertEqual(r.data['statut'], NOUVEAU)
        self.assertTrue(Notification.objects.filter(destinataire=self.chef).exists())

    def test_reaffectation(self):
        autre = self.agent('pompier2', 'pompiers', ['dakar'])
        self.action(self.chef, 'affecter', agent=self.pompier.pk)
        self.action(self.pompier, 'accepter')
        r = self.action(self.chef, 'affecter', agent=autre.pk, message='Plus proche')
        self.assertEqual(r.data['statut'], AFFECTE)
        self.assertEqual(r.data['intervention']['agent'], autre.pk)
        self.assertTrue(Notification.objects.filter(destinataire=self.pompier, titre='Intervention retirée').exists())
        self.en_tant_que(self.pompier)
        self.assertEqual(self.client.get(self.url).status_code, 404)

    def test_annulation_citoyen_puis_impossible(self):
        r = self.action(self.awa, 'annuler', motif='Fausse alerte')
        self.assertEqual(r.data['statut'], ANNULE)
        self.assertEqual(self.action(self.awa, 'annuler', motif='encore').status_code, 409)

    def test_rejet_par_superadmin(self):
        self.assertEqual(self.action(self.chef, 'rejeter', motif='Signalement non fondé').data['statut'], REFUSE)

    def test_complement_citoyen_notifie_agent(self):
        self.action(self.pompier, 'prendre-en-charge')
        self.en_tant_que(self.awa)
        with self.captureOnCommitCallbacks(execute=True):
            r = self.client.post(f'{self.url}completer/', {'message': 'Le feu a gagné le bâtiment voisin'}, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertTrue(Notification.objects.filter(destinataire=self.pompier, type='complement').exists())

    def test_echec_notification_ne_supprime_pas_le_dossier(self):
        """Scénario 9."""
        self.en_tant_que(self.awa)
        with mock.patch('notifications.service.envoyer_push', side_effect=RuntimeError('FCM en panne')), \
                self.captureOnCommitCallbacks(execute=True):
            r = self.client.post(URL, self.incident_payload(latitude=14.75), format='json')
        self.assertEqual(r.status_code, 201)
        self.assertTrue(Incident.objects.filter(reference=r.data['reference']).exists())

    def test_statut_push_non_configure_trace(self):
        self.action(self.chef, 'affecter', agent=self.pompier.pk)
        n = Notification.objects.get(destinataire=self.pompier)
        self.assertEqual(n.statut_push, 'aucun_appareil')
        from accounts.models import DeviceToken
        DeviceToken.objects.create(user=self.pompier, token='t1')
        self.action(self.chef, 'affecter', agent=self.pompier.pk, message='rappel')
        self.assertEqual(Notification.objects.filter(destinataire=self.pompier).latest('pk').statut_push, 'non_configure')
