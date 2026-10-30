"""Tests des fonctionnalités v3.1 : alertes de zone, communauté, géocodage, chiffres publics, niveaux."""

from datetime import timedelta
from unittest import mock

import requests
from django.utils import timezone

from alerts.models import AlerteZone
from core.models import JournalAudit
from core.tests_utils import SenAlertTestCase
from incidents.models import Commentaire, Confirmation, Incident
from notifications.models import Notification


class AlertesZoneTests(SenAlertTestCase):
    URL = '/api/alertes/zones/'

    def publier(self, **kw):
        data = {'titre': 'Fortes pluies attendues', 'message': 'Évitez les zones basses.', 'niveau': 'danger', 'regions': ['dakar']}
        data.update(kw)
        with self.captureOnCommitCallbacks(execute=True):
            return self.client.post(self.URL, data, format='json')

    def test_publication_reservee_et_notification_ciblee(self):
        dakar, matam = self.citoyen('awa', 'dakar'), self.citoyen('ali', 'matam')
        agent = self.agent('pompier', zones=['dakar'])
        self.en_tant_que(dakar)
        self.assertEqual(self.publier().status_code, 403)
        self.en_tant_que(self.superadmin())
        r = self.publier()
        self.assertEqual(r.status_code, 201, r.data)
        notifies = set(Notification.objects.filter(type='alerte_zone').values_list('destinataire', flat=True))
        self.assertEqual(notifies, {dakar.pk, agent.pk})
        self.assertNotIn(matam.pk, notifies)
        self.assertTrue(JournalAudit.objects.filter(action='alerte_zone.publication').exists())

    def test_lecture_publique_des_alertes_en_cours_seulement(self):
        AlerteZone.objects.create(titre='En cours', message='m', regions=['dakar'])
        AlerteZone.objects.create(titre='Terminée', message='m', regions=['dakar'], date_fin=timezone.now() - timedelta(hours=1),
                                  date_debut=timezone.now() - timedelta(days=1))
        AlerteZone.objects.create(titre='Nationale', message='m', regions=[])
        r = self.client.get(self.URL, {'region': 'dakar'})
        self.assertEqual(r.status_code, 200)
        self.assertEqual({a['titre'] for a in r.data['results']}, {'En cours', 'Nationale'})
        self.assertEqual(self.client.get(self.URL, {'region': 'matam'}).data['count'], 1)

    def test_validation_et_fin(self):
        self.en_tant_que(self.superadmin())
        self.assertEqual(self.publier(regions=['atlantide']).status_code, 400)
        r = self.publier(date_fin=(timezone.now() - timedelta(days=1)).isoformat())
        self.assertEqual(r.status_code, 400)
        a = self.publier().data
        r = self.client.post(f"{self.URL}{a['id']}/terminer/")
        self.assertFalse(r.data['en_cours'])


class CommunauteTests(SenAlertTestCase):
    URL = '/api/incidents/communaute/'

    def setUp(self):
        super().setUp()
        self.awa = self.citoyen('awa')
        self.inc = Incident.objects.create(citoyen=self.awa, type_incident='inondation', region='dakar', latitude=14.7123,
                                           longitude=-17.4567, description='Mon adresse exacte et mon nom')

    def test_fil_sans_donnees_personnelles_et_trie_par_distance(self):
        Incident.objects.create(type_incident='accident', region='thies', latitude=14.79, longitude=-16.93)
        self.en_tant_que(self.citoyen('voisin'))
        r = self.client.get(self.URL, {'lat': 14.71, 'lng': -17.45, 'rayon_km': 100})
        self.assertEqual(r.status_code, 200)
        premier = r.data['results'][0]
        self.assertEqual(premier['id'], self.inc.pk)
        self.assertNotIn('description', premier)
        self.assertEqual(premier['latitude'], 14.712)
        self.assertIsNotNone(premier['distance_m'])

    def test_confirmation_idempotente_et_pas_sur_son_propre_signalement(self):
        self.en_tant_que(self.awa)
        self.assertEqual(self.client.post(f'{self.URL}{self.inc.pk}/confirmer/').status_code, 400)
        self.en_tant_que(self.citoyen('voisin'))
        for _ in range(2):
            r = self.client.post(f'{self.URL}{self.inc.pk}/confirmer/')
        self.assertEqual(r.data['nb_confirmations'], 1)
        self.assertEqual(self.client.delete(f'{self.URL}{self.inc.pk}/confirmer/').data['nb_confirmations'], 0)
        self.en_tant_que(self.agent())
        self.assertEqual(self.client.post(f'{self.URL}{self.inc.pk}/confirmer/').status_code, 403)

    def test_confirmations_visibles_du_superadmin(self):
        Confirmation.objects.create(incident=self.inc, citoyen=self.citoyen('voisin'))
        self.en_tant_que(self.superadmin())
        self.assertEqual(self.client.get(f'/api/incidents/{self.inc.pk}/').data['nb_confirmations'], 1)

    def test_commentaires_et_moderation(self):
        voisin = self.en_tant_que(self.citoyen('voisin'))
        voisin.first_name, voisin.last_name = 'Moussa', 'Ndiaye'
        voisin.save()
        r = self.client.post(f'{self.URL}{self.inc.pk}/commentaires/', {'texte': 'La route est coupée côté marché'}, format='json')
        self.assertEqual(r.status_code, 201)
        self.assertEqual(r.data['auteur_nom'], 'Moussa N.', 'jamais le nom complet')
        self.assertEqual(self.client.post(f'{self.URL}{self.inc.pk}/commentaires/', {'texte': 'x'}, format='json').status_code, 400)
        cid = r.data['id']
        self.assertEqual(self.client.post(f'{self.URL}commentaires/{cid}/masquer/').status_code, 403)
        self.en_tant_que(self.superadmin())
        self.assertTrue(self.client.post(f'{self.URL}commentaires/{cid}/masquer/').data['masque'])
        self.en_tant_que(voisin)
        self.assertEqual(self.client.get(f'{self.URL}{self.inc.pk}/commentaires/').data, [])
        self.assertTrue(Commentaire.objects.get(pk=cid).masque)

    def test_incidents_rejetes_absents_du_fil(self):
        self.inc.statut = 'refuse'
        self.inc.save()
        self.en_tant_que(self.citoyen('voisin'))
        self.assertEqual(self.client.get(self.URL).data['count'], 0)
        self.assertEqual(self.client.post(f'{self.URL}{self.inc.pk}/confirmer/').status_code, 404)


class CarteEtVitrineTests(SenAlertTestCase):
    def test_geocodage(self):
        self.en_tant_que(self.citoyen())
        rep = mock.Mock(status_code=200)
        rep.json.return_value = [{'display_name': 'Place de l’Indépendance, Dakar', 'lat': '14.668', 'lon': '-17.432', 'type': 'square'}]
        with mock.patch('core.views.requests.get', return_value=rep) as get:
            r = self.client.get('/api/geocodage/', {'q': 'Place Indépendance'})
        self.assertEqual(r.data['resultats'][0]['latitude'], 14.668)
        self.assertEqual(get.call_args.kwargs['params']['countrycodes'], 'sn')
        with mock.patch('core.views.requests.get', side_effect=requests.ConnectionError):
            self.assertEqual(self.client.get('/api/geocodage/', {'q': 'autre lieu'}).status_code, 503)
        self.assertEqual(self.client.get('/api/geocodage/', {'q': 'ab'}).status_code, 400)

    def test_chiffres_publics_reels(self):
        Incident.objects.create(type_incident='incendie', region='dakar', statut='resolu')
        self.citoyen()
        r = self.client.get('/api/statistiques-publiques/')
        self.assertEqual(r.status_code, 200)
        self.assertEqual((r.data['signalements'], r.data['resolus'], r.data['citoyens']), (1, 1, 1))
        self.assertFalse(r.data['donnees_demo'])

    def test_niveaux_regions_pour_tout_utilisateur_connecte(self):
        self.assertEqual(self.client.get('/api/analyse/niveaux-regions/').status_code, 401)
        self.en_tant_que(self.citoyen())
        r = self.client.get('/api/analyse/niveaux-regions/')
        self.assertEqual(len(r.data['zones']), 14)
        self.assertNotIn('score', r.data['zones'][0])
