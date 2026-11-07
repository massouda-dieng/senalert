import uuid
from datetime import timedelta

from django.utils import timezone

from core.constants import ACCEPTE, AFFECTE, NOUVEAU, REGIONS, ROLE_SUPERADMIN
from core.tests_utils import SenAlertTestCase
from notifications.models import Notification

from .models import AlerteSOS

URL = '/api/alertes/sos/'


class SOSTests(SenAlertTestCase):
    def setUp(self):
        super().setUp()
        self.awa = self.en_tant_que(self.citoyen('awa', region='dakar'))

    def test_sos_avec_gps(self):
        r = self.client.post(URL, {'latitude': 14.69, 'longitude': -17.44, 'precision_gps': 9}, format='json')
        self.assertEqual(r.status_code, 201, r.data)
        self.assertRegex(r.data['reference'], r'^SOS-\d{4}-\d{6}$')
        self.assertFalse(r.data['deja_enregistree'])
        self.assertEqual(r.data['source_position'], 'gps')
        self.assertEqual(r.data['gravite'], 'critique')

    def test_sos_sans_gps_sans_position_inventee(self):
        r = self.client.post(URL, {}, format='json')
        self.assertEqual(r.status_code, 201)
        self.assertIsNone(r.data['latitude'])
        self.assertEqual(r.data['source_position'], 'indisponible')
        self.assertEqual(r.data['region'], 'dakar', 'région du profil, explicitement')

    def test_idempotence(self):
        cle = str(uuid.uuid4())
        r1 = self.client.post(URL, {'client_request_id': cle}, format='json')
        r2 = self.client.post(URL, {'client_request_id': cle}, format='json')
        self.assertEqual((r1.status_code, r2.status_code), (201, 200))
        self.assertTrue(r2.data['deja_enregistree'])
        self.assertEqual(AlerteSOS.objects.count(), 1)

    def test_double_declenchement_rapproche(self):
        self.client.post(URL, {}, format='json')
        r = self.client.post(URL, {'client_request_id': str(uuid.uuid4())}, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(AlerteSOS.objects.count(), 1)
        AlerteSOS.objects.update(date_creation=timezone.now() - timedelta(minutes=5))
        self.assertEqual(self.client.post(URL, {}, format='json').status_code, 201)

    def test_authentification_requise(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.client.post(URL, {}, format='json').status_code, 401)

    def test_sos_part_au_superviseur_de_la_structure_la_plus_proche(self):
        """Le SOS va à la structure de secours la plus proche ; son superviseur est prévenu et affecte un agent."""
        pompier = self.agent('pompier', 'pompiers', ['dakar'])
        matam = (REGIONS['matam']['lat'], REGIONS['matam']['lng'])
        policier_matam = self.agent('policier', 'police', ['matam'], structure=self.structure('police', matam))
        responsable = self.superviseur('responsable', structure=pompier.structure)
        chef = self.superadmin()
        with self.captureOnCommitCallbacks(execute=True):
            r = self.client.post(URL, {'latitude': 14.69, 'longitude': -17.44}, format='json')
        self.assertEqual(r.data['statut'], NOUVEAU, "aucun agent n'est désigné automatiquement")
        self.assertEqual(r.data['structure'], pompier.structure_id, 'la structure dotée d’un superviseur')
        self.assertFalse(Notification.objects.filter(type='affectation').exists())
        notifies = set(Notification.objects.filter(type='nouvelle_alerte').values_list('destinataire', flat=True))
        self.assertEqual(notifies, {responsable.pk, chef.pk})
        self.assertFalse(Notification.objects.filter(destinataire=policier_matam).exists())

        self.en_tant_que(responsable)
        with self.captureOnCommitCallbacks(execute=True):
            r = self.client.post(f"{URL}{r.data['id']}/affecter/", {'agent': pompier.pk}, format='json')
        self.assertEqual(r.data['statut'], AFFECTE)
        self.assertTrue(Notification.objects.filter(destinataire=pompier, type='affectation').exists())

    def test_sos_avec_structure_choisie_et_photo(self):
        caserne = self.structure('pompiers')
        r = self.client.post(URL, {'type_urgence': 'incendie', 'structure': caserne.pk, 'latitude': 14.69,
                                   'longitude': -17.44, 'photos': [self.image()]}, format='multipart')
        self.assertEqual(r.status_code, 201, r.data)
        self.assertEqual(r.data['structure'], caserne.pk)
        self.assertEqual(len(r.data['photos']), 1)
        self.assertEqual(self.client.get(r.data['photos'][0]['url']).status_code, 200)
        self.en_tant_que(self.citoyen('autre'))
        self.assertEqual(self.client.get(r.data['photos'][0]['url']).status_code, 404)

    def test_le_citoyen_change_de_structure_tant_que_le_sos_n_est_pas_affecte(self):
        r = self.client.post(URL, {'type_urgence': 'medicale', 'latitude': 14.69, 'longitude': -17.44}, format='json')
        autre = self.client.get('/api/structures/', {'lat': 14.69, 'lng': -17.44, 'type_urgence': 'medicale'}).data[1]
        self.assertEqual(autre['service_code'], 'sante')
        nouveau_responsable = self.superviseur('nouveau', structure=self.structure_par_id(autre['id']))
        with self.captureOnCommitCallbacks(execute=True):
            r2 = self.client.post(f"{URL}{r.data['id']}/changer-structure/", {'structure': autre['id']}, format='json')
        self.assertEqual(r2.status_code, 200, r2.data)
        self.assertEqual(r2.data['structure'], autre['id'])
        self.assertTrue(Notification.objects.filter(destinataire=nouveau_responsable, type='nouvelle_alerte').exists())
        police = self.structure('police')
        self.assertEqual(self.client.post(f"{URL}{r.data['id']}/changer-structure/", {'structure': police.pk},
                                          format='json').status_code, 400)
        self.en_tant_que(self.citoyen('intrus'))
        self.assertEqual(self.client.post(f"{URL}{r.data['id']}/changer-structure/", {'structure': autre['id']},
                                          format='json').status_code, 404)

    def test_photo_ajoutee_apres_l_envoi_du_sos(self):
        r = self.client.post(URL, {'latitude': 14.69, 'longitude': -17.44}, format='json')
        r2 = self.client.post(f"{URL}{r.data['id']}/completer/", {'photos': [self.image()]}, format='multipart')
        self.assertEqual(r2.status_code, 200, r2.data)
        self.assertEqual(len(r2.data['photos']), 1)

    def test_sos_structure_incompatible_refusee(self):
        police = self.structure('police')
        r = self.client.post(URL, {'type_urgence': 'medicale', 'structure': police.pk}, format='json')
        self.assertEqual(r.status_code, 400)

    def test_sos_sans_agent_disponible_va_au_superviseur(self):
        self.agent('pompier', 'pompiers', ['dakar'], disponible=False)
        r = self.client.post(URL, {'latitude': 14.69, 'longitude': -17.44}, format='json')
        self.assertEqual(r.data['statut'], 'nouveau')
        self.assertIsNotNone(r.data['structure'], 'structure de secours la plus proche, son superviseur affectera')

    def test_historique_et_prise_en_charge(self):
        policier = self.agent('policier', 'police', ['dakar'])
        r = self.client.post(URL, {'latitude': 14.69, 'longitude': -17.44}, format='json')
        self.assertEqual(self.client.get(URL).data['count'], 1)
        self.en_tant_que(self.citoyen('autre'))
        self.assertEqual(self.client.get(URL).data['count'], 0)
        self.en_tant_que(self.superadmin())
        self.client.post(f"{URL}{r.data['id']}/affecter/", {'agent': policier.pk}, format='json')
        self.en_tant_que(policier)
        r = self.client.post(f"{URL}{r.data['id']}/accepter/")
        self.assertEqual(r.data['statut'], ACCEPTE)
        self.assertEqual(r.data['intervention']['agent'], policier.pk)

    def test_superadmin_liste_tout(self):
        self.client.post(URL, {}, format='json')
        self.en_tant_que(self.superadmin())
        self.assertEqual(self.client.get(URL).data['count'], 1)
        self.assertEqual(self.client.get(URL, {'statut': 'nouveau', 'region': 'dakar'}).data['count'], 1)
        self.assertEqual(self.client.get(URL, {'statut': 'resolu'}).data['count'], 0)
