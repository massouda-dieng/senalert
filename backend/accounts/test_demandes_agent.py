from accounts.models import DemandeCompteAgent, User
from core.models import JournalAudit, Service
from core.tests_utils import SenAlertTestCase
from notifications.models import Notification

URL = '/api/auth/demandes-agent/'
GESTION = '/api/gestion/demandes-agent/'
MDP_AGENT = 'Brigade-Dakar-2026'


class DemandeCompteAgentTests(SenAlertTestCase):
    def demande(self, **extra):
        corps = {'prenom': 'Cheikh', 'nom': 'Diallo', 'email': 'cheikh@police.sn', 'telephone': '771234567',
                 'matricule': 'P-0042', 'service': Service.objects.get(code='police').pk, 'structure': 'Commissariat de Plateau',
                 'fonction': 'Brigadier', 'zones': ['dakar'], 'mot_de_passe': MDP_AGENT, **extra}
        return self.client.post(URL, corps, format='json')

    def test_parcours_complet_demande_validation_connexion(self):
        chef = self.superadmin()
        with self.captureOnCommitCallbacks(execute=True):
            r = self.demande()
        self.assertEqual(r.status_code, 201, r.data)
        d = DemandeCompteAgent.objects.get()
        self.assertNotIn(MDP_AGENT, d.mot_de_passe_hash)
        self.assertFalse(User.objects.filter(email='cheikh@police.sn').exists())
        self.assertTrue(Notification.objects.filter(destinataire=chef, titre__icontains='demande').exists())

        # Avant validation : connexion impossible, avec un message explicite (seulement si le mot de passe correspond)
        r = self.client.post('/api/auth/connexion/', {'username': 'cheikh@police.sn', 'password': MDP_AGENT}, format='json')
        self.assertEqual(r.status_code, 401)
        self.assertIn('attente de validation', r.data['detail'])
        r = self.client.post('/api/auth/connexion/', {'username': 'cheikh@police.sn', 'password': 'mauvais-mdp-123'}, format='json')
        self.assertNotIn('attente', r.data['detail'])

        self.en_tant_que(chef)
        self.assertEqual(self.client.get(GESTION, {'statut': 'en_attente'}).data['count'], 1)
        r = self.client.post(f'{GESTION}{d.pk}/valider/')
        self.assertEqual(r.status_code, 200, r.data)
        user = User.objects.get(email='cheikh@police.sn')
        self.assertEqual(user.role, 'agent')
        self.assertEqual(user.profil_agent.service.code, 'police')
        self.assertEqual(user.profil_agent.zones, ['dakar'])
        self.assertTrue(JournalAudit.objects.filter(action='admin.validation_demande_agent').exists())
        # Déjà traitée
        self.assertEqual(self.client.post(f'{GESTION}{d.pk}/valider/').status_code, 409)

        self.client.force_authenticate(user=None)
        r = self.client.post('/api/auth/connexion/', {'username': 'cheikh@police.sn', 'password': MDP_AGENT}, format='json')
        self.assertEqual(r.status_code, 200, r.data)
        self.assertEqual(r.data['utilisateur']['role'], 'agent')

    def test_refus_avec_motif(self):
        self.demande()
        d = DemandeCompteAgent.objects.get()
        self.en_tant_que(self.superadmin())
        self.assertEqual(self.client.post(f'{GESTION}{d.pk}/refuser/', {}, format='json').status_code, 400)
        r = self.client.post(f'{GESTION}{d.pk}/refuser/', {'motif': 'Matricule inconnu'}, format='json')
        self.assertEqual(r.status_code, 200)
        d.refresh_from_db()
        self.assertEqual((d.statut, d.mot_de_passe_hash), ('refusee', ''))
        self.assertFalse(User.objects.filter(email='cheikh@police.sn').exists())
        # Le refus ne se devine pas depuis la page de connexion
        self.client.force_authenticate(user=None)
        r = self.client.post('/api/auth/connexion/', {'username': 'cheikh@police.sn', 'password': 'nimporte-quoi-123'}, format='json')
        self.assertEqual(r.status_code, 401)
        self.assertNotIn('refus', r.data['detail'])

    def test_validations_du_formulaire(self):
        self.citoyen('awa')
        self.assertIn('email', self.demande(email='awa@test.sn').data['champs'])
        self.assertIn('mot_de_passe', str(self.demande(mot_de_passe='123').data))
        self.assertIn('zones', self.demande(zones=[]).data['champs'])
        self.assertEqual(self.demande().status_code, 201)
        self.assertIn('email', self.demande().data['champs'])  # demande déjà en cours

    def test_seul_le_superadmin_gere_les_demandes(self):
        self.demande()
        d = DemandeCompteAgent.objects.get()
        for u in (self.citoyen(), self.agent()):
            self.en_tant_que(u)
            self.assertEqual(self.client.get(GESTION).status_code, 403)
            self.assertEqual(self.client.post(f'{GESTION}{d.pk}/valider/').status_code, 403)
        self.client.force_authenticate(user=None)
        self.assertEqual(self.client.get(GESTION).status_code, 401)
        self.assertNotIn('mot_de_passe_hash', str(self.demande(email='x@y.sn').data))
