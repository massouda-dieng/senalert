import logging
from unittest import mock

import requests

from core.logging import masquer
from core.models import Categorie, JournalAudit, Parametre
from core.tests_utils import SenAlertTestCase


class ConfigurationTests(SenAlertTestCase):
    def test_configuration_publique_sans_numeros_non_verifies(self):
        r = self.client.get('/api/configuration/')
        self.assertEqual(r.status_code, 200)
        numeros = [n['numero'] for n in r.data['numeros_urgence']]
        self.assertEqual(numeros, ['17', '18'])
        self.assertEqual(len(r.data['regions']), 14)
        self.assertIn('ne remplace pas', r.data['avertissement'])
        self.assertFalse(r.data['google_actif'])

    def test_categories_lecture_connectee_ecriture_superadmin(self):
        self.en_tant_que(self.citoyen())
        self.assertEqual(self.client.get('/api/categories/').status_code, 200)
        self.assertEqual(self.client.post('/api/categories/', {'code': 'x', 'libelle': 'X'}).status_code, 403)
        self.en_tant_que(self.superadmin())
        r = self.client.post('/api/categories/', {'code': 'eboulement', 'libelle': 'Éboulement'}, format='json')
        self.assertEqual(r.status_code, 201)
        self.assertTrue(JournalAudit.objects.filter(action='config.creation_categorie').exists())
        r = self.client.patch(f"/api/categories/{r.data['id']}/", {'actif': False}, format='json')
        self.assertFalse(Categorie.objects.get(code='eboulement').actif)

    def test_parametres_valides_et_journalises(self):
        self.en_tant_que(self.superadmin())
        url = '/api/parametres/delais_prise_en_charge_minutes/'
        self.assertEqual(self.client.patch(url, {'valeur': 'texte'}, format='json').status_code, 400)
        self.assertEqual(self.client.patch(url, {'valeur': {'pirate': 1}}, format='json').status_code, 400)
        r = self.client.patch(url, {'valeur': {'sos': 5, 'incident': 45}}, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(Parametre.get('delais_prise_en_charge_minutes')['sos'], 5)
        self.assertTrue(JournalAudit.objects.filter(action='config.modification_parametre').exists())

    def test_audit_reserve_superadmin(self):
        self.en_tant_que(self.agent())
        self.assertEqual(self.client.get('/api/audit/').status_code, 403)

    def test_fiches_secours_publiques(self):
        r = self.client.get('/api/fiches-secours/')
        self.assertEqual(r.status_code, 200)
        self.assertGreaterEqual(len(r.data), 10)
        self.assertFalse(r.data[0]['validee'], 'non validées par un professionnel tant que valide_par est vide')

    def test_documentation_openapi(self):
        self.assertEqual(self.client.get('/api/schema/').status_code, 200)


class ServicesProximiteTests(SenAlertTestCase):
    URL = '/api/services-proximite/'

    def setUp(self):
        super().setUp()
        from django.core.cache import caches
        caches['default'].clear()
        caches['osm'].clear()
        self.en_tant_que(self.citoyen())

    def test_derniers_resultats_si_serveurs_satures(self):
        from django.core.cache import caches
        elements = [{'type': 'node', 'id': 1, 'lat': 14.6929, 'lon': -17.4468, 'tags': {'amenity': 'police', 'name': 'Commissariat'}}]
        with mock.patch('core.views.interroger_overpass', return_value=elements):
            self.assertFalse(self.client.get(self.URL, {'lat': 14.69, 'lng': -17.44}).data['donnees_anciennes'])
        caches['default'].clear()  # le cache court a expiré
        with mock.patch('core.views.interroger_overpass', side_effect=requests.ConnectionError):
            r = self.client.get(self.URL, {'lat': 14.69, 'lng': -17.44})
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.data['donnees_anciennes'])
        self.assertEqual(r.data['resultats'][0]['nom'], 'Commissariat')

    def test_miroir_overpass_si_principal_sature(self):
        from core.views import interroger_overpass
        ok = mock.Mock(status_code=200, **{'json.return_value': {'elements': [{'id': 1}]}})
        with self.settings(OVERPASS_URLS=['https://principal', 'https://miroir']), \
                mock.patch('core.views.requests.post', side_effect=[requests.Timeout(), ok]) as post:
            self.assertEqual(interroger_overpass(14.69, -17.44, 1000, ['police']), [{'id': 1}])
        self.assertEqual([c.args[0] for c in post.call_args_list], ['https://principal', 'https://miroir'])

    def test_donnees_osm_triees_par_distance(self):
        elements = [
            {'type': 'node', 'id': 1, 'lat': 14.70, 'lon': -17.44, 'tags': {'amenity': 'pharmacy', 'name': 'Pharmacie A'}},
            {'type': 'way', 'id': 2, 'center': {'lat': 14.692, 'lon': -17.446}, 'tags': {'amenity': 'hospital', 'name': 'Hôpital B', 'phone': '+221 33 000 00 00'}},
            {'type': 'node', 'id': 3, 'lat': 15.5, 'lon': -16.0, 'tags': {'amenity': 'police'}},
        ]
        with mock.patch('core.views.interroger_overpass', return_value=elements):
            r = self.client.get(self.URL, {'lat': 14.6928, 'lng': -17.4467, 'rayon': 3000})
        self.assertEqual([x['nom'] for x in r.data['resultats']], ['Hôpital B', 'Pharmacie A'])
        self.assertIn('OpenStreetMap', r.data['source'])
        self.assertIsNone(r.data['resultats'][1]['telephone'], 'aucune donnée inventée')

    def test_osm_indisponible_503(self):
        with mock.patch('core.views.interroger_overpass', side_effect=requests.ConnectionError):
            r = self.client.get(self.URL, {'lat': 14.69, 'lng': -17.44})
        self.assertEqual(r.status_code, 503)

    def test_parametres_requis(self):
        self.assertEqual(self.client.get(self.URL).status_code, 400)


class JournalisationTests(SenAlertTestCase):
    def test_secrets_masques(self):
        self.assertNotIn('abc123', masquer('password=abc123'))
        self.assertNotIn('eyJhbGc', masquer('Authorization: Bearer eyJhbGciOi.xx'))
        self.assertNotIn('gsk_ABCDEF', masquer('clé gsk_ABCDEF123'))

    def test_erreur_interne_generique(self):
        with mock.patch('core.views.ConfigurationPubliqueView.get', side_effect=RuntimeError('détail interne secret')):
            logging.disable(logging.CRITICAL)
            r = self.client.get('/api/configuration/')
            logging.disable(logging.NOTSET)
        self.assertEqual(r.status_code, 500)
        self.assertNotIn('secret', str(r.data))


class SmsSecoursTests(SenAlertTestCase):
    def test_numero_expose_seulement_si_actif(self):
        self.assertIsNone(self.client.get('/api/configuration/').data['sms_secours'])
        Parametre.objects.update_or_create(cle='sms_secours', defaults={'valeur': {'actif': True, 'numero': '+221770000000'}})
        from django.core.cache import cache
        cache.clear()
        self.assertEqual(self.client.get('/api/configuration/').data['sms_secours'], '+221770000000')
