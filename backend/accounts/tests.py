import re
from unittest import mock

from django.core import mail
from django.test import override_settings
from django.utils import timezone

from core.constants import ROLE_AGENT, ROLE_CITOYEN, ROLE_SUPERADMIN
from core.models import JournalAudit, Service
from core.tests_utils import MDP, SenAlertTestCase

from . import google
from .models import CompteExterne, DeviceToken, User

INSCRIPTION = '/api/auth/inscription/'
CONNEXION = '/api/auth/connexion/'
RAFRAICHIR = '/api/auth/jeton/rafraichir/'
DECONNEXION = '/api/auth/deconnexion/'
PROFIL = '/api/auth/profil/'


class InscriptionConnexionTests(SenAlertTestCase):
    def test_inscription_cree_toujours_un_citoyen(self):
        """Envoyer role=superadmin ou agent ne change rien : le rôle est attribué par le serveur."""
        for i, role in enumerate(['superadmin', 'agent', 'admin']):
            r = self.client.post(INSCRIPTION, {'email': f'x{i}@test.sn', 'password': MDP, 'role': role}, format='json')
            self.assertEqual(r.status_code, 201, r.data)
            self.assertEqual(r.data['utilisateur']['role'], ROLE_CITOYEN)
            self.assertIn('access', r.data)
        self.assertFalse(User.objects.exclude(role=ROLE_CITOYEN).exists())

    def test_email_unique_insensible_a_la_casse(self):
        self.client.post(INSCRIPTION, {'email': 'awa@test.sn', 'password': MDP}, format='json')
        r = self.client.post(INSCRIPTION, {'email': 'AWA@Test.sn', 'password': MDP}, format='json')
        self.assertEqual(r.status_code, 400)

    def test_mot_de_passe_faible_refuse(self):
        r = self.client.post(INSCRIPTION, {'email': 'a@test.sn', 'password': '123456'}, format='json')
        self.assertEqual(r.status_code, 400)
        self.assertIn('champs', r.data)

    def test_connexion_par_email_ou_identifiant(self):
        self.citoyen('awa')
        for ident in ('awa', 'AWA@test.sn'):
            r = self.client.post(CONNEXION, {'username': ident, 'password': MDP}, format='json')
            self.assertEqual(r.status_code, 200, ident)
            self.assertEqual(r.data['utilisateur']['role'], ROLE_CITOYEN)

    def test_mauvais_mot_de_passe_journalise(self):
        self.citoyen('awa')
        r = self.client.post(CONNEXION, {'username': 'awa', 'password': 'faux'}, format='json')
        self.assertEqual(r.status_code, 401)
        self.assertTrue(JournalAudit.objects.filter(action='compte.echec_connexion').exists())
        self.assertNotIn('faux', str(JournalAudit.objects.values_list('details', flat=True)))

    def test_compte_desactive_refuse(self):
        u = self.citoyen('awa')
        u.is_active = False
        u.save()
        r = self.client.post(CONNEXION, {'username': 'awa', 'password': MDP}, format='json')
        self.assertEqual(r.status_code, 401)

    def test_limitation_tentatives_connexion(self):
        self.citoyen('awa')
        codes = [self.client.post(CONNEXION, {'username': 'awa', 'password': 'x'}, format='json').status_code
                 for _ in range(12)]
        self.assertIn(429, codes)


class SessionsTests(SenAlertTestCase):
    def connecter(self):
        self.citoyen('awa')
        return self.client.post(CONNEXION, {'username': 'awa', 'password': MDP}, format='json').data

    def test_rafraichissement_avec_rotation_et_revocation(self):
        jetons = self.connecter()
        r = self.client.post(RAFRAICHIR, {'refresh': jetons['refresh']}, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertIn('refresh', r.data)
        # L'ancien jeton de rafraîchissement est révoqué après rotation.
        r2 = self.client.post(RAFRAICHIR, {'refresh': jetons['refresh']}, format='json')
        self.assertEqual(r2.status_code, 401)

    def test_deconnexion_revoque_le_jeton(self):
        jetons = self.connecter()
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {jetons['access']}")
        self.assertEqual(self.client.post(DECONNEXION, {'refresh': jetons['refresh']}, format='json').status_code, 200)
        self.client.credentials()
        self.assertEqual(self.client.post(RAFRAICHIR, {'refresh': jetons['refresh']}, format='json').status_code, 401)

    def test_deconnexion_de_toutes_les_sessions(self):
        j1 = self.connecter()
        j2 = self.client.post(CONNEXION, {'username': 'awa', 'password': MDP}, format='json').data
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {j1['access']}")
        self.client.post(DECONNEXION, {'tout': True}, format='json')
        self.client.credentials()
        for j in (j1, j2):
            self.assertEqual(self.client.post(RAFRAICHIR, {'refresh': j['refresh']}, format='json').status_code, 401)

    def test_jeton_invalide_401(self):
        self.client.credentials(HTTP_AUTHORIZATION='Bearer pas-un-jeton')
        self.assertEqual(self.client.get(PROFIL).status_code, 401)


class ProfilTests(SenAlertTestCase):
    def test_citoyen_ne_peut_pas_changer_son_role(self):
        u = self.en_tant_que(self.citoyen())
        r = self.client.patch(PROFIL, {'role': ROLE_SUPERADMIN, 'telephone': '770000000'}, format='json')
        self.assertEqual(r.status_code, 200)
        u.refresh_from_db()
        self.assertEqual(u.role, ROLE_CITOYEN)
        self.assertEqual(u.telephone, '770000000')

    def test_preferences_validees(self):
        self.en_tant_que(self.citoyen())
        r = self.client.patch(PROFIL, {'preferences': {'notifications_push': False}}, format='json')
        self.assertFalse(r.data['preferences']['notifications_push'])
        self.assertTrue(r.data['preferences']['notifications_statut'])
        r = self.client.patch(PROFIL, {'preferences': {'pirate': 1}}, format='json')
        self.assertEqual(r.status_code, 400)

    def test_changement_mot_de_passe(self):
        self.en_tant_que(self.citoyen())
        r = self.client.post('/api/auth/mot-de-passe/', {'ancien': 'faux', 'nouveau': 'Autre-Solide-2027'}, format='json')
        self.assertEqual(r.status_code, 400)
        r = self.client.post('/api/auth/mot-de-passe/', {'ancien': MDP, 'nouveau': 'Autre-Solide-2027'}, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertIn('access', r.data)

    def test_suppression_anonymise_le_compte(self):
        u = self.en_tant_que(self.citoyen())
        r = self.client.delete(PROFIL, {'mot_de_passe': MDP, 'confirmation': 'SUPPRIMER'}, format='json')
        self.assertEqual(r.status_code, 204)
        u.refresh_from_db()
        self.assertFalse(u.is_active)
        self.assertEqual(u.email, '')
        self.assertIsNotNone(u.date_anonymisation)

    def test_enregistrement_appareil(self):
        self.en_tant_que(self.citoyen())
        r = self.client.post('/api/auth/appareils/', {'token': 'fcm-abc', 'plateforme': 'android'}, format='json')
        self.assertEqual(r.status_code, 201)
        self.assertEqual(DeviceToken.objects.get().plateforme, 'android')


class ReinitialisationTests(SenAlertTestCase):
    def test_parcours_complet(self):
        self.citoyen('awa')
        r = self.client.post('/api/auth/mot-de-passe/oubli/', {'email': 'awa@test.sn'}, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(mail.outbox), 1)
        uid, token = re.search(r'uid=([^&]+)&token=(\S+)', mail.outbox[0].body).groups()
        r = self.client.post('/api/auth/mot-de-passe/reinitialiser/', {'uid': uid, 'token': token, 'nouveau': 'Nouveau-Solide-2027'}, format='json')
        self.assertEqual(r.status_code, 200)
        r = self.client.post('/api/auth/mot-de-passe/reinitialiser/', {'uid': uid, 'token': token, 'nouveau': 'Encore-Solide-2028'}, format='json')
        self.assertEqual(r.status_code, 400, 'un lien ne sert qu’une fois')
        self.assertEqual(self.client.post(CONNEXION, {'username': 'awa', 'password': 'Nouveau-Solide-2027'}, format='json').status_code, 200)

    def test_email_inconnu_meme_reponse(self):
        r = self.client.post('/api/auth/mot-de-passe/oubli/', {'email': 'inconnu@test.sn'}, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(len(mail.outbox), 0)


def claims(**kw):
    base = {'iss': 'https://accounts.google.com', 'aud': 'web-client-id', 'sub': 'g-123', 'email': 'awa@gmail.com',
            'email_verified': True, 'exp': timezone.now().timestamp() + 600, 'given_name': 'Awa'}
    base.update(kw)
    return base


@override_settings(GOOGLE_CLIENT_IDS=['web-client-id'], GOOGLE_CLIENT_ID_WEB='web-client-id')
class GoogleTests(SenAlertTestCase):
    URL = '/api/auth/google/'

    def connecter(self, c):
        with mock.patch('google.oauth2.id_token.verify_oauth2_token', return_value=c):
            return self.client.post(self.URL, {'id_token': 'jeton'}, format='json')

    def test_nouveau_compte_google_est_citoyen(self):
        r = self.connecter(claims())
        self.assertEqual(r.status_code, 201)
        self.assertEqual(r.data['utilisateur']['role'], ROLE_CITOYEN)
        self.assertTrue(r.data['nouveau_compte'])
        self.assertFalse(User.objects.get(email='awa@gmail.com').has_usable_password())

    def test_reconnexion_retrouve_le_meme_compte(self):
        self.connecter(claims())
        r = self.connecter(claims(email='autre@gmail.com'))  # même « sub » : même compte
        self.assertEqual(r.status_code, 200)
        self.assertEqual(User.objects.count(), 1)

    def test_liaison_compte_citoyen_existant(self):
        self.citoyen('awa').__class__.objects.filter(username='awa').update(email='awa@gmail.com')
        r = self.connecter(claims())
        self.assertEqual(r.status_code, 200)
        self.assertEqual(User.objects.count(), 1)
        self.assertTrue(CompteExterne.objects.filter(user__username='awa').exists())

    def test_compte_privilegie_jamais_lie_automatiquement(self):
        a = self.agent('moussa')
        a.email = 'awa@gmail.com'
        a.save()
        r = self.connecter(claims())
        self.assertEqual(r.status_code, 403)
        self.assertFalse(CompteExterne.objects.exists())

    def test_email_non_verifie_refuse(self):
        self.assertEqual(self.connecter(claims(email_verified=False)).status_code, 401)

    def test_audience_etrangere_refusee(self):
        self.assertEqual(self.connecter(claims(aud='autre-application')).status_code, 401)

    def test_emetteur_invalide_refuse(self):
        self.assertEqual(self.connecter(claims(iss='https://pirate.example')).status_code, 401)

    def test_jeton_rejete_par_google(self):
        with mock.patch('google.oauth2.id_token.verify_oauth2_token', side_effect=ValueError('signature')):
            r = self.client.post(self.URL, {'id_token': 'jeton'}, format='json')
        self.assertEqual(r.status_code, 401)

    def test_liaison_depuis_session_authentifiee(self):
        agent = self.en_tant_que(self.agent('moussa'))
        with mock.patch('google.oauth2.id_token.verify_oauth2_token', return_value=claims(email='m@gmail.com')):
            r = self.client.post('/api/auth/google/lier/', {'id_token': 'jeton'}, format='json')
        self.assertEqual(r.status_code, 200)
        agent.refresh_from_db()
        self.assertEqual(agent.role, ROLE_AGENT, 'la liaison ne change jamais le rôle')


class GoogleNonConfigureTests(SenAlertTestCase):
    def test_google_non_configure_503(self):
        r = self.client.post('/api/auth/google/', {'id_token': 'x'}, format='json')
        self.assertEqual(r.status_code, 503)
        self.assertEqual(r.data['code'], 'google_non_configure')

    def test_controle_claims_sans_reseau(self):
        with override_settings(GOOGLE_CLIENT_IDS=['web-client-id']):
            self.assertEqual(google.controler_claims(claims())['sub'], 'g-123')


class GestionUtilisateursTests(SenAlertTestCase):
    URL = '/api/gestion/utilisateurs/'

    def test_reserve_au_superadmin(self):
        for u in (self.citoyen(), self.agent()):
            self.en_tant_que(u)
            self.assertEqual(self.client.get(self.URL).status_code, 403)

    def test_creation_agent(self):
        self.en_tant_que(self.superadmin())
        service = Service.objects.get(code='police')
        r = self.client.post(self.URL + 'agents/', {
            'email': 'Nouvel.Agent@test.sn', 'first_name': 'Ibou', 'last_name': 'Fall', 'mot_de_passe_initial': 'Initial-Solide-2026',
            'service': service.pk, 'zones': ['dakar', 'thies'],
        }, format='json')
        self.assertEqual(r.status_code, 201, r.data)
        u = User.objects.get(email='nouvel.agent@test.sn')
        self.assertEqual(u.role, ROLE_AGENT)
        self.assertTrue(u.doit_changer_mot_de_passe)
        self.assertEqual(u.profil_agent.zones, ['dakar', 'thies'])
        self.assertTrue(JournalAudit.objects.filter(action='admin.creation_agent').exists())

    def test_role_superadmin_non_attribuable_par_api(self):
        self.en_tant_que(self.superadmin())
        c = self.citoyen()
        r = self.client.patch(f'{self.URL}{c.pk}/', {'role': ROLE_SUPERADMIN}, format='json')
        self.assertEqual(r.status_code, 400)
        c.refresh_from_db()
        self.assertEqual(c.role, ROLE_CITOYEN)

    def test_superadmin_ne_se_modifie_pas_lui_meme(self):
        s = self.en_tant_que(self.superadmin())
        self.assertEqual(self.client.patch(f'{self.URL}{s.pk}/', {'is_active': False}, format='json').status_code, 403)

    def test_desactivation_journalisee(self):
        self.en_tant_que(self.superadmin())
        a = self.agent()
        r = self.client.patch(f'{self.URL}{a.pk}/', {'is_active': False}, format='json')
        self.assertEqual(r.status_code, 200)
        a.refresh_from_db()
        self.assertFalse(a.is_active)
        self.assertTrue(JournalAudit.objects.filter(action='admin.modification_utilisateur').exists())

    def test_filtre_par_zone(self):
        self.en_tant_que(self.superadmin())
        self.agent('a1', zones=['dakar'])
        self.agent('a2', zones=['matam'])
        r = self.client.get(self.URL, {'role': 'agent', 'zone': 'matam'})
        self.assertEqual([u['username'] for u in r.data['results']], ['a2'])


class OngletsConnexionTests(SenAlertTestCase):
    def test_onglet_doit_correspondre_au_role(self):
        from core.tests_utils import MDP
        self.citoyen('awa')
        self.agent('moussa')
        self.superadmin('chef')
        for nom, bon, mauvais in [('awa', 'citoyen', 'agent'), ('moussa', 'agent', 'superadmin'), ('chef', 'superadmin', 'citoyen')]:
            r = self.client.post(CONNEXION, {'username': nom, 'password': MDP, 'espace': bon}, format='json')
            self.assertEqual(r.status_code, 200, (nom, r.data))
            r = self.client.post(CONNEXION, {'username': nom, 'password': MDP, 'espace': mauvais}, format='json')
            self.assertEqual(r.status_code, 401)
            self.assertIn('onglet', r.data['detail'])
            self.assertNotIn('access', r.data)
        # Mauvais mot de passe : message générique, le rôle n'est pas révélé
        r = self.client.post(CONNEXION, {'username': 'chef', 'password': 'faux-mot-de-passe', 'espace': 'citoyen'}, format='json')
        self.assertNotIn('onglet', r.data['detail'])
        # Sans onglet (anciens clients) : inchangé
        self.assertEqual(self.client.post(CONNEXION, {'username': 'awa', 'password': MDP}, format='json').status_code, 200)
