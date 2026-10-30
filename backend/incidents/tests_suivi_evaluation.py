from datetime import timedelta
from django.utils import timezone

from core.models import Service
from core.tests_utils import SenAlertTestCase
from incidents.models import Incident, Intervention


class SuiviEtEvaluationTests(SenAlertTestCase):
    def setUp(self):
        super().setUp()
        self.awa = self.citoyen('awa')
        self.moussa = self.agent('moussa', 'pompiers', ['dakar'])
        self.autre = self.agent('ibou', 'pompiers', ['dakar'])
        self.inc = Incident.objects.create(citoyen=self.awa, type_incident='incendie', description='Feu de cuisine important',
                                           latitude=14.6928, longitude=-17.4467, region='dakar',
                                           service=Service.objects.get(code='pompiers'))
        self.url = f'/api/incidents/{self.inc.pk}/'

    def prise_en_charge(self):
        self.en_tant_que(self.moussa)
        self.assertEqual(self.client.post(self.url + 'prendre-en-charge/').status_code, 200)

    def test_position_agent_visible_du_citoyen_pendant_intervention(self):
        self.en_tant_que(self.moussa)
        # Avant prise en charge : refus
        self.assertEqual(self.client.post(self.url + 'position-agent/', {'latitude': 14.70, 'longitude': -17.45}).status_code, 409)
        self.prise_en_charge()
        r = self.client.post(self.url + 'position-agent/', {'latitude': 14.7019, 'longitude': -17.4467, 'precision': 12}, format='json')
        self.assertEqual(r.status_code, 200, r.data)
        self.assertAlmostEqual(r.data['distance_m'], 1012, delta=20)
        # Un autre agent ne peut pas usurper la position
        self.en_tant_que(self.autre)
        self.assertIn(self.client.post(self.url + 'position-agent/', {'latitude': 1, 'longitude': 1}).status_code, (403, 404))
        # Le citoyen voit la position et la distance, pas l'identité
        self.en_tant_que(self.awa)
        inter = self.client.get(self.url).data['intervention']
        self.assertEqual(inter['agent_nom'], 'Agent de secours')
        self.assertIsNotNone(inter['position_agent'])
        # Position trop ancienne : masquée
        Intervention.objects.update(position_date=timezone.now() - timedelta(minutes=30))
        self.assertIsNone(self.client.get(self.url).data['intervention']['position_agent'])

    def test_position_effacee_a_la_resolution_puis_evaluation_unique(self):
        self.prise_en_charge()
        self.client.post(self.url + 'position-agent/', {'latitude': 14.70, 'longitude': -17.45}, format='json')
        self.client.post(self.url + 'demarrer/')
        # Évaluation impossible avant résolution
        self.en_tant_que(self.awa)
        self.assertEqual(self.client.post(self.url + 'evaluer/', {'note': 5}).status_code, 409)
        self.en_tant_que(self.moussa)
        self.assertEqual(self.client.post(self.url + 'resoudre/', {'compte_rendu': 'Feu maîtrisé, aucun blessé.'}).status_code, 200)
        self.assertIsNone(Intervention.objects.get().position_lat)
        # Seul le déclarant évalue
        self.assertIn(self.client.post(self.url + 'evaluer/', {'note': 5}).status_code, (403, 404))
        self.en_tant_que(self.awa)
        self.assertEqual(self.client.post(self.url + 'evaluer/', {'note': 6}).status_code, 400)
        with self.captureOnCommitCallbacks(execute=True):
            r = self.client.post(self.url + 'evaluer/', {'note': 4, 'commentaire': 'Rapide et efficace'}, format='json')
        self.assertEqual(r.status_code, 200, r.data)
        self.assertEqual(r.data['intervention']['note_satisfaction'], 4)
        self.assertTrue(self.moussa.notifications.filter(titre__contains='4/5').exists())
        self.assertEqual(self.client.post(self.url + 'evaluer/', {'note': 1}).status_code, 409)
        # Statistiques de la supervision
        self.en_tant_que(self.superadmin())
        sat = self.client.get('/api/tableau-de-bord/statistiques/').data['satisfaction']
        self.assertEqual((sat['moyenne'], sat['nombre'], sat['taux_reponse']), (4.0, 1, 100.0))
        self.assertEqual(sat['par_service'][0]['service'], 'Sapeurs-pompiers')
