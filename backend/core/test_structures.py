"""Structures, superviseurs de structure et choix de l'agent par le citoyen (remarques de l'encadreur)."""
from core.constants import AFFECTE, NOUVEAU, REGIONS, ROLE_AGENT
from core.models import JournalAudit, Structure
from core.tests_utils import MDP, SenAlertTestCase
from incidents.models import Incident
from notifications.models import Notification

URL = '/api/incidents/'
STRUCTURES = '/api/structures/'
GESTION = '/api/gestion/utilisateurs/'


class StructuresProchesTests(SenAlertTestCase):
    def setUp(self):
        super().setUp()
        self.en_tant_que(self.citoyen())

    def test_structures_proches_triees_et_filtrees_par_categorie(self):
        r = self.client.get(STRUCTURES, {'lat': 14.70, 'lng': -17.45, 'categorie': 'incendie'})
        self.assertEqual(r.status_code, 200)
        self.assertTrue(r.data)
        self.assertEqual({s['service_code'] for s in r.data}, {'pompiers'})
        distances = [s['distance_m'] for s in r.data]
        self.assertEqual(distances, sorted(distances))

    def test_structures_avec_agents_disponibles_comptes(self):
        pompier = self.agent('pompier')
        self.agent('absent', disponible=False)
        r = self.client.get(STRUCTURES, {'lat': 14.70, 'lng': -17.45, 'service': 'pompiers', 'limite': 1})
        self.assertEqual(r.data[0]['id'], pompier.structure_id)
        self.assertEqual(r.data[0]['nb_agents_disponibles'], 1)

    def test_agents_proposes_sans_donnees_personnelles(self):
        pompier = self.agent('pompier')
        pompier.last_name, pompier.telephone = 'Sarr', '770000000'
        pompier.save()
        pompier.profil_agent.fonction = 'Sapeur-pompier'
        pompier.profil_agent.save()
        self.agent('absent', disponible=False)
        r = self.client.get(f'{STRUCTURES}{pompier.structure_id}/agents/')
        self.assertEqual(r.data, [{'id': pompier.pk, 'prenom': 'Pompier', 'fonction': 'Sapeur-pompier', 'missions_actives': 0}])

    def test_gambie_exclue_et_agences_par_region(self):
        self.assertFalse(Structure.objects.filter(nom__icontains='Kotu').exists())
        for service in ('senelec', 'onas'):
            self.assertEqual(Structure.objects.filter(service__code=service).count(), len(REGIONS))

    def test_seul_le_superadmin_modifie_les_structures(self):
        s = self.structure('pompiers')
        self.assertEqual(self.client.patch(f'{STRUCTURES}{s.pk}/', {'nom': 'X'}, format='json').status_code, 403)
        self.en_tant_que(self.superadmin())
        r = self.client.patch(f'{STRUCTURES}{s.pk}/', {'latitude': 14.71, 'longitude': -17.46}, format='json')
        self.assertEqual(r.status_code, 200, r.data)
        self.assertEqual(self.client.patch(f'{STRUCTURES}{s.pk}/', {'latitude': 48.8, 'longitude': 2.3},
                                           format='json').status_code, 400)


class ChoixDuCitoyenTests(SenAlertTestCase):
    def setUp(self):
        super().setUp()
        self.awa = self.citoyen('awa')
        self.pompier = self.agent('pompier')
        self.collegue = self.agent('collegue')
        self.responsable = self.superviseur('responsable', structure=self.pompier.structure)
        autre_caserne = Structure.objects.filter(service__code='pompiers').exclude(pk=self.pompier.structure_id).first()
        self.autre_responsable = self.superviseur('autre', structure=autre_caserne)

    def signaler(self, **kw):
        self.en_tant_que(self.awa)
        with self.captureOnCommitCallbacks(execute=True):
            return self.client.post(URL, self.incident_payload(**kw), format='json')

    def test_flux_structure_superviseur_agent(self):
        """Flux de l'encadreur : citoyen → structure choisie → son superviseur affecte → l'agent est notifié."""
        r = self.signaler(structure=self.pompier.structure_id)
        self.assertEqual(r.status_code, 201, r.data)
        self.assertEqual(r.data['statut'], NOUVEAU, "le dossier n'est pas « affecté » tant que le superviseur n'a rien fait")
        self.assertEqual(r.data['structure_nom'], self.pompier.structure.nom)
        self.assertIsNone(r.data['intervention'])
        self.assertTrue(Notification.objects.filter(destinataire=self.responsable, type='nouvelle_alerte').exists())
        self.assertFalse(Notification.objects.filter(destinataire=self.autre_responsable).exists())
        pk = r.data['id']
        for user, attendu in ((self.responsable, 200), (self.pompier, 404), (self.autre_responsable, 404)):
            self.en_tant_que(user)
            self.assertEqual(self.client.get(f'{URL}{pk}/').status_code, attendu, user.username)

        self.en_tant_que(self.pompier)
        depuis = self.client.get('/api/tableau-de-bord/flux/').data['maintenant'].isoformat()
        self.en_tant_que(self.responsable)
        with self.captureOnCommitCallbacks(execute=True):
            r = self.client.post(f'{URL}{pk}/affecter/', {'agent': self.pompier.pk}, format='json')
        self.assertEqual(r.data['statut'], AFFECTE)
        self.assertEqual(Incident.objects.get(pk=pk).intervention.agent_id, self.pompier.pk)
        self.assertTrue(Notification.objects.filter(destinataire=self.pompier, type='affectation').exists())
        self.assertTrue(Notification.objects.filter(destinataire=self.awa, type='statut').exists())
        for user, attendu in ((self.pompier, 200), (self.collegue, 404), (self.autre_responsable, 404)):
            self.en_tant_que(user)
            self.assertEqual(self.client.get(f'{URL}{pk}/').status_code, attendu, user.username)
        # L'alerte en direct de l'agent remonte le dossier qui vient de lui être affecté (créé avant).
        self.en_tant_que(self.pompier)
        flux = self.client.get('/api/tableau-de-bord/flux/', {'depuis': depuis}).data
        self.assertEqual([d['id'] for d in flux['incidents']], [pk])
        self.en_tant_que(self.collegue)
        self.assertEqual(self.client.get('/api/tableau-de-bord/flux/', {'depuis': depuis}).data['incidents'], [])

    def test_le_citoyen_ne_choisit_pas_l_agent(self):
        r = self.signaler(structure=self.pompier.structure_id, agent=self.pompier.pk)
        self.assertEqual(r.status_code, 201, r.data)
        self.assertEqual(r.data['statut'], NOUVEAU)
        self.assertFalse(Notification.objects.filter(destinataire=self.pompier).exists())

    def test_structure_sans_agent_choisi_va_au_superviseur(self):
        r = self.signaler(structure=self.pompier.structure_id)
        self.assertEqual(r.data['statut'], NOUVEAU)
        self.en_tant_que(self.responsable)
        self.assertEqual(self.client.get(URL).data['count'], 1)
        self.en_tant_que(self.pompier)
        self.assertEqual(self.client.get(URL).data['count'], 0)

    def test_sans_choix_structure_competente_la_plus_proche(self):
        """Le citoyen ne choisit pas : structure compétente la plus proche dotée d'un superviseur."""
        r = self.signaler()
        self.assertIn(r.data['structure'], {self.pompier.structure_id, self.autre_responsable.structure_id})
        self.assertEqual(r.data['statut'], NOUVEAU)
        self.assertIsNone(r.data['intervention'])

    def test_sans_agent_disponible_le_dossier_attend_le_superviseur(self):
        for a in (self.pompier, self.collegue):
            a.profil_agent.disponible = False
            a.profil_agent.save()
        r = self.signaler(latitude=14.70, longitude=-17.45)
        self.assertEqual(r.data['statut'], NOUVEAU)
        self.assertEqual(r.data['service_nom'], 'Sapeurs-pompiers')


class SuperviseurDeStructureTests(SenAlertTestCase):
    def setUp(self):
        super().setUp()
        self.pompier = self.agent('pompier')
        self.responsable = self.superviseur('responsable', structure=self.pompier.structure)
        self.autre_caserne = Structure.objects.filter(service__code='pompiers').exclude(pk=self.pompier.structure_id).first()
        self.inc = Incident.objects.create(type_incident='incendie', region='dakar', structure=self.pompier.structure)
        self.ailleurs = Incident.objects.create(type_incident='incendie', region='dakar', structure=self.autre_caserne)

    def test_ne_voit_et_n_affecte_que_dans_sa_structure(self):
        self.en_tant_que(self.responsable)
        self.assertEqual([d['id'] for d in self.client.get(URL).data['results']], [self.inc.pk])
        etranger = self.agent('etranger', structure=self.autre_caserne)
        r = self.client.post(f'{URL}{self.inc.pk}/affecter/', {'agent': etranger.pk}, format='json')
        self.assertEqual(r.status_code, 400)
        r = self.client.post(f'{URL}{self.inc.pk}/affecter/', {'agent': self.pompier.pk}, format='json')
        self.assertEqual(r.data['statut'], AFFECTE)
        self.assertEqual(self.client.post(f'{URL}{self.ailleurs.pk}/rejeter/', {'motif': 'x'}, format='json').status_code, 404)

    def test_cree_ses_agents_dans_sa_structure(self):
        self.en_tant_que(self.responsable)
        r = self.client.post(GESTION + 'agents/', {
            'email': 'recrue@test.sn', 'first_name': 'Ndeye', 'last_name': 'Sy', 'mot_de_passe_initial': MDP,
            'fonction': 'Sapeur', 'structure': self.autre_caserne.pk,  # ignorée : sa propre structure s'impose
        }, format='json')
        self.assertEqual(r.status_code, 201, r.data)
        self.assertEqual(r.data['structure'], self.pompier.structure_id)
        self.assertTrue(JournalAudit.objects.filter(action='admin.creation_agent').exists())
        emails = {u['email'] for u in self.client.get(GESTION).data['results']}
        self.assertEqual(emails, {'pompier@test.sn', 'recrue@test.sn'}, 'uniquement les agents de sa structure')

    def test_ne_cree_pas_de_superviseur_ni_ne_change_de_role(self):
        self.en_tant_que(self.responsable)
        r = self.client.post(GESTION + 'superviseurs/', {
            'email': 'x@test.sn', 'first_name': 'X', 'last_name': 'Y', 'mot_de_passe_initial': MDP,
            'structure': self.pompier.structure_id}, format='json')
        self.assertEqual(r.status_code, 403)
        r = self.client.patch(f'{GESTION}{self.pompier.pk}/', {'role': 'citoyen'}, format='json')
        self.assertEqual(r.status_code, 403)
        r = self.client.patch(f'{GESTION}{self.pompier.pk}/', {'disponible': False}, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertFalse(r.data['profil_agent']['disponible'])

    def test_superadmin_cree_un_superviseur_qui_se_connecte_par_l_onglet_superviseur(self):
        self.en_tant_que(self.superadmin())
        r = self.client.post(GESTION + 'superviseurs/', {
            'email': 'chef.caserne@test.sn', 'first_name': 'Awa', 'last_name': 'Ka', 'mot_de_passe_initial': MDP,
            'structure': self.autre_caserne.pk}, format='json')
        self.assertEqual(r.status_code, 201, r.data)
        self.client.force_authenticate(None)
        r = self.client.post('/api/auth/connexion/', {'username': 'chef.caserne@test.sn', 'password': MDP,
                                                       'espace': 'superadmin'}, format='json')
        self.assertEqual(r.status_code, 200, r.data)
        self.assertEqual(r.data['utilisateur']['structure'], self.autre_caserne.pk)

    def test_statistiques_limitees_a_sa_structure(self):
        self.en_tant_que(self.responsable)
        r = self.client.get('/api/tableau-de-bord/statistiques/')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data['resume']['total_signalements'], 1)

    def test_demande_de_compte_agent_supprimee(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.client.post('/api/auth/demandes-agent/', {}, format='json').status_code, 404)


class DisponibiliteAgentTests(SenAlertTestCase):
    def test_agent_indisponible_n_est_plus_propose(self):
        pompier = self.en_tant_que(self.agent('pompier'))
        r = self.client.post('/api/auth/disponibilite/', {'disponible': False}, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertFalse(r.data['profil_agent']['disponible'])
        self.en_tant_que(self.citoyen())
        self.assertEqual(self.client.get(f'{STRUCTURES}{pompier.structure_id}/agents/').data, [])

    def test_reserve_aux_agents(self):
        self.en_tant_que(self.citoyen())
        self.assertEqual(self.client.post('/api/auth/disponibilite/', {'disponible': False}, format='json').status_code, 403)
        self.assertEqual(ROLE_AGENT, 'agent')
