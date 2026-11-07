"""Constat de l'équipe : SOS typé, compétence territoriale des structures, journal d'audit lisible et inaltérable."""
from core.constants import ACCEPTE, NOUVEAU
from core.models import JournalAudit, Structure
from core.tests_utils import MDP, SenAlertTestCase

SOS = '/api/alertes/sos/'
INCIDENTS = '/api/incidents/'
STRUCTURES = '/api/structures/'
AUDIT = '/api/audit/'


class SOSTypeTests(SenAlertTestCase):
    def setUp(self):
        super().setUp()
        self.medecin = self.agent('medecin', service='sante')
        self.pompier = self.agent('pompier', service='pompiers')
        self.awa = self.en_tant_que(self.citoyen('awa'))

    def test_type_d_urgence_oriente_vers_le_bon_service(self):
        r = self.client.post(SOS, {'type_urgence': 'medicale', 'latitude': 14.70, 'longitude': -17.45}, format='json')
        self.assertEqual(r.status_code, 201, r.data)
        self.assertEqual(r.data['type_urgence'], 'medicale')
        self.assertEqual(r.data['type_urgence_libelle'], 'Urgence médicale')
        self.assertEqual(r.data['structure'], self.medecin.structure_id)
        self.assertEqual(r.data['statut'], NOUVEAU, 'le superviseur de la structure affectera')
        # La confirmation affichée au citoyen repose sur ces champs enregistrés par le serveur.
        for champ in ('reference', 'structure_nom', 'date_creation', 'latitude', 'longitude'):
            self.assertTrue(r.data[champ], champ)

    def test_sans_type_urgence_non_precisee(self):
        r = self.client.post(SOS, {'latitude': 14.70, 'longitude': -17.45}, format='json')
        self.assertEqual(r.data['type_urgence'], 'non_precise')

    def test_type_inconnu_refuse(self):
        r = self.client.post(SOS, {'type_urgence': 'xyz'}, format='json')
        self.assertEqual(r.status_code, 400)

    def test_historique_et_detail_du_sos(self):
        r = self.client.post(SOS, {'type_urgence': 'incendie', 'latitude': 14.70, 'longitude': -17.45}, format='json')
        liste = self.client.get(SOS).data['results']
        self.assertEqual([s['id'] for s in liste], [r.data['id']])
        detail = self.client.get(f"{SOS}{r.data['id']}/").data
        self.assertEqual(detail['type_urgence_libelle'], 'Incendie')
        self.assertEqual(detail['structure'], self.pompier.structure_id)


class CompetenceTerritorialeTests(SenAlertTestCase):
    def setUp(self):
        super().setUp()
        self.en_tant_que(self.citoyen())

    def test_agence_regionale_uniquement_dans_la_region(self):
        # Mbour (région de Thiès) : l'agence SENELEC de Dakar n'est pas compétente, même si elle est proche.
        r = self.client.get(STRUCTURES, {'lat': 14.42, 'lng': -16.96, 'service': 'senelec'})
        self.assertEqual(r.status_code, 200)
        self.assertEqual({s['region'] for s in r.data}, {'thies'})
        self.assertTrue(all(s['dans_la_zone'] for s in r.data))

    def test_structures_de_la_region_d_abord(self):
        r = self.client.get(STRUCTURES, {'lat': 14.70, 'lng': -17.45, 'categorie': 'incendie', 'limite': 20})
        zones = [s['dans_la_zone'] for s in r.data]
        self.assertEqual(zones, sorted(zones, reverse=True), 'compétentes (région du lieu) avant les autres')
        self.assertTrue(zones[0])

    def test_structure_d_un_autre_service_refusee(self):
        police = Structure.objects.filter(service__code='police').first()
        r = self.client.post(INCIDENTS, self.incident_payload(structure=police.pk), format='json')
        self.assertEqual(r.status_code, 400)
        self.assertIn('structure', r.data.get('champs', r.data))


class JournalAuditTests(SenAlertTestCase):
    def setUp(self):
        super().setUp()
        self.pompier = self.agent('pompier')
        self.awa = self.citoyen('awa')

    def test_parcours_complet_trace(self):
        self.client.post('/api/auth/connexion/', {'username': 'awa@test.sn', 'password': MDP, 'espace': 'citoyen'},
                         format='json')
        self.en_tant_que(self.awa)
        r = self.client.post(INCIDENTS, self.incident_payload(structure=self.pompier.structure_id), format='json')
        self.client.post(SOS, {'type_urgence': 'incendie'}, format='json')
        self.client.patch('/api/auth/profil/', {'telephone': '771234567'}, format='json')
        pk = r.data['id']
        self.en_tant_que(self.superviseur(structure=self.pompier.structure))
        self.client.post(f'{INCIDENTS}{pk}/affecter/', {'agent': self.pompier.pk}, format='json')
        self.en_tant_que(self.pompier)
        self.assertEqual(self.client.post(f'{INCIDENTS}{pk}/accepter/').data['statut'], ACCEPTE)
        self.client.post(f'{INCIDENTS}{pk}/demarrer/')
        self.client.post(f'{INCIDENTS}{pk}/resoudre/', {'compte_rendu': 'Feu maîtrisé, aucun blessé.'}, format='json')
        actions = set(JournalAudit.objects.values_list('action', flat=True))
        for attendu in ('compte.connexion', 'incident.creation', 'sos.envoi', 'compte.modification_profil', 'dossier.affectation',
                        'dossier.acceptation', 'dossier.demarrage', 'dossier.cloture'):
            self.assertIn(attendu, actions)

        self.en_tant_que(self.superadmin())
        entree = self.client.get(AUDIT, {'action': 'dossier.cloture'}).data['results'][0]
        self.assertEqual(entree['acteur_nom'], self.pompier.nom_affiche)
        self.assertEqual(entree['acteur_role_libelle'], 'Agent de secours')
        self.assertEqual(entree['action_libelle'], 'Clôture (résolu)')
        self.assertEqual(entree['element'], f"Incident · {r.data['reference']}")
        rubrique = self.client.get(AUDIT, {'rubrique': 'signalements'}).data['results']
        self.assertEqual({e['action'] for e in rubrique}, {'incident.creation', 'sos.envoi'})

    def test_journal_reserve_et_inalterable(self):
        entree = JournalAudit.objects.create(action='test')
        for user in (self.awa, self.pompier, self.superviseur(structure=self.pompier.structure)):
            self.en_tant_que(user)
            self.assertEqual(self.client.get(AUDIT).status_code, 403)
        self.en_tant_que(self.superadmin())
        self.assertIn(self.client.delete(f'{AUDIT}{entree.pk}/').status_code, (404, 405), 'aucune route de suppression')
        self.assertTrue(JournalAudit.objects.filter(pk=entree.pk).exists())
        entree.action = 'falsifie'
        with self.assertRaises(PermissionError):
            entree.save()
        with self.assertRaises(PermissionError):
            entree.delete()
