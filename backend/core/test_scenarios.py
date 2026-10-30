"""Scénarios de bout en bout (API) correspondant au cahier de recette."""

from unittest import mock

from django.test import override_settings
from django.utils import timezone

from core.tests_utils import MDP, SenAlertTestCase


class ScenariosBoutEnBout(SenAlertTestCase):
    def jetons(self, ident):
        r = self.client.post('/api/auth/connexion/', {'username': ident, 'password': MDP}, format='json')
        self.assertEqual(r.status_code, 200, r.data)
        return r.data

    def avec(self, jetons):
        self.client.force_authenticate(None)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {jetons['access']}")

    def test_scenarios_1_a_6(self):
        self.citoyen('awa')
        self.superadmin('chef')
        pompier = self.agent('pompier', 'pompiers', ['dakar'])

        # 1. Le citoyen se connecte, crée un incident, consulte son dossier
        citoyen = self.jetons('awa@test.sn')
        self.assertEqual(citoyen['utilisateur']['role'], 'citoyen')
        self.avec(citoyen)
        with self.captureOnCommitCallbacks(execute=True):
            inc = self.client.post('/api/incidents/', self.incident_payload(), format='json').data
        self.assertEqual(self.client.get(f"/api/incidents/{inc['id']}/").data['reference'], inc['reference'])

        # 2. Le superadmin consulte puis affecte
        self.avec(self.jetons('chef'))
        self.assertEqual(self.client.get('/api/incidents/', {'q': inc['reference']}).data['count'], 1)
        with self.captureOnCommitCallbacks(execute=True):
            r = self.client.post(f"/api/incidents/{inc['id']}/affecter/", {'agent': pompier.pk}, format='json')
        self.assertEqual(r.data['statut'], 'affecte')

        # 3. L'agent reçoit l'affectation, accepte, met à jour
        self.avec(self.jetons('pompier'))
        notifs = self.client.get('/api/notifications/').data['results']
        self.assertTrue(any(n['type'] == 'affectation' for n in notifs))
        self.assertEqual(self.client.get('/api/incidents/', {'affecte_a_moi': True}).data['count'], 1)
        with self.captureOnCommitCallbacks(execute=True):
            self.client.post(f"/api/incidents/{inc['id']}/accepter/")
            r = self.client.post(f"/api/incidents/{inc['id']}/demarrer/")
        self.assertEqual(r.data['statut'], 'en_cours')

        # 4. Le citoyen voit l'évolution
        self.avec(citoyen)
        self.assertEqual(self.client.get(f"/api/incidents/{inc['id']}/").data['statut'], 'en_cours')
        self.assertGreaterEqual(self.client.get('/api/notifications/compteur/').data['non_lues'], 2)

        # 5. Les indicateurs suivent
        self.avec(self.jetons('chef'))
        s = self.client.get('/api/tableau-de-bord/statistiques/').data
        self.assertEqual(s['resume']['en_cours'], 1)

        # 6. Accès non autorisés refusés
        self.avec(citoyen)
        self.assertEqual(self.client.get('/api/tableau-de-bord/statistiques/').status_code, 403)
        self.assertEqual(self.client.get('/api/gestion/utilisateurs/').status_code, 403)
        self.assertEqual(self.client.post(f"/api/incidents/{inc['id']}/resoudre/", {'compte_rendu': 'x' * 20}, format='json').status_code, 403)

    @override_settings(GOOGLE_CLIENT_IDS=['web'])
    def test_scenario_7_google_sans_role_privilegie(self):
        claims = {'iss': 'accounts.google.com', 'aud': 'web', 'sub': '42', 'email': 'nouveau@gmail.com',
                  'email_verified': True, 'exp': timezone.now().timestamp() + 60}
        with mock.patch('google.oauth2.id_token.verify_oauth2_token', return_value=claims):
            r1 = self.client.post('/api/auth/google/', {'id_token': 't'}, format='json')
            r2 = self.client.post('/api/auth/google/', {'id_token': 't'}, format='json')
        self.assertEqual((r1.status_code, r2.status_code), (201, 200))
        self.assertEqual(r2.data['utilisateur']['role'], 'citoyen')
        self.assertEqual(r1.data['utilisateur']['id'], r2.data['utilisateur']['id'])

    def test_scenario_8_ia_en_panne_sos_fonctionne(self):
        self.citoyen('awa')
        self.avec(self.jetons('awa'))
        with override_settings(GROQ_API_KEY='x'), mock.patch('analyse.assistant.requests.post', side_effect=ConnectionError):
            self.assertEqual(self.client.post('/api/analyse/assistant/', {'message': 'aide'}, format='json').status_code, 200)
        self.assertEqual(self.client.post('/api/alertes/sos/', {}, format='json').status_code, 201)
        self.assertEqual(self.client.get('/api/fiches-secours/').status_code, 200)
