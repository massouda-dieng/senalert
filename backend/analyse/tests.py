from django.test import TestCase
from django.utils import timezone
from datetime import timedelta
from unittest.mock import MagicMock
from .analyzer import calculer_score_risque, determiner_niveau, analyser_zones_risque


def make_incident(type_incident, region='dakar', jours_passes=0):
    inc = MagicMock()
    inc.type_incident = type_incident
    inc.region = region
    inc.date_creation = timezone.now() - timedelta(days=jours_passes)
    return inc


class TestCalculerScoreRisque(TestCase):

    def test_incident_recent(self):
        inc = make_incident('incendie', jours_passes=1)
        score = calculer_score_risque([inc])
        self.assertEqual(score, 10.0)

    def test_incident_ancien(self):
        inc = make_incident('incendie', jours_passes=10)
        score = calculer_score_risque([inc])
        self.assertEqual(score, 5.0)

    def test_liste_vide(self):
        self.assertEqual(calculer_score_risque([]), 0.0)


class TestDeterminerNiveau(TestCase):

    def test_critique(self):
        self.assertEqual(determiner_niveau(20), 'critique')

    def test_eleve(self):
        self.assertEqual(determiner_niveau(10), 'eleve')

    def test_moyen(self):
        self.assertEqual(determiner_niveau(5), 'moyen')

    def test_faible(self):
        self.assertEqual(determiner_niveau(1), 'faible')


class TestAnalyserZonesRisque(TestCase):

    def test_liste_vide(self):
        self.assertEqual(analyser_zones_risque([]), [])

    def test_une_region(self):
        inc = make_incident('inondation', region='dakar', jours_passes=1)
        result = analyser_zones_risque([inc])
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0]['region'], 'dakar')

    def test_tri_par_score(self):
        incidents = [
            make_incident('autre',    region='louga', jours_passes=1),
            make_incident('incendie', region='dakar', jours_passes=1),
        ]
        result = analyser_zones_risque(incidents)
        self.assertEqual(result[0]['region'], 'dakar')

# --------------------------------------------------------------------------
# Tests ajoutés en v3 : bornes exactes de la méthode de référence
# --------------------------------------------------------------------------
from unittest import mock  # noqa: E402

from django.test import override_settings  # noqa: E402

from core.models import Parametre  # noqa: E402
from core.tests_utils import SenAlertTestCase  # noqa: E402
from incidents.models import Incident  # noqa: E402

from . import assistant  # noqa: E402
from .analyzer import POIDS_GRAVITE, poids  # noqa: E402


class TestFormuleReference(TestCase):
    def test_poids_du_memoire(self):
        self.assertEqual(POIDS_GRAVITE, {'incendie': 5, 'inondation': 4, 'insecurite': 4, 'accident': 3,
                                         'electricite': 2, 'autre': 1})

    def test_categorie_hors_tableau_vaut_1(self):
        self.assertEqual(poids('agression'), 1)
        self.assertEqual(poids('urgence_medicale'), 1)

    def test_seuils_exacts(self):
        for score, niveau in [(15, 'critique'), (14.99, 'eleve'), (8, 'eleve'), (7.99, 'moyen'),
                              (3, 'moyen'), (2.99, 'faible'), (0, 'faible')]:
            self.assertEqual(determiner_niveau(score), niveau, score)

    def test_borne_des_sept_jours(self):
        ref = timezone.now()
        inc = MagicMock(type_incident='accident', date_creation=ref - timedelta(days=7))
        self.assertEqual(calculer_score_risque([inc], ref), 6.0, 'exactement 7 jours : récent')
        inc.date_creation = ref - timedelta(days=7, seconds=1)
        self.assertEqual(calculer_score_risque([inc], ref), 3.0)

    def test_exemple_documente(self):
        """2 incendies récents + 1 inondation ancienne = 5×2×2 + 4×1 = 24 → critique."""
        ref = timezone.now()
        incs = [MagicMock(type_incident='incendie', date_creation=ref), MagicMock(type_incident='incendie', date_creation=ref),
                MagicMock(type_incident='inondation', date_creation=ref - timedelta(days=30))]
        self.assertEqual(calculer_score_risque(incs, ref), 24.0)
        self.assertEqual(determiner_niveau(24.0), 'critique')

    def test_reproductible_avec_date_de_reference(self):
        ref = timezone.now() - timedelta(days=100)
        inc = MagicMock(type_incident='incendie', date_creation=ref - timedelta(days=1))
        self.assertEqual(calculer_score_risque([inc], ref), 10.0)

    def test_donnees_insuffisantes(self):
        self.assertTrue(analyser_zones_risque([make_incident('incendie')])[0]['donnees_insuffisantes'])


class TestEndpointZonesRisque(SenAlertTestCase):
    URL = '/api/analyse/zones-risque/'

    def creer(self, type_, region, statut='nouveau', jours=0):
        inc = Incident.objects.create(type_incident=type_, region=region, latitude=14.7, longitude=-17.4, statut=statut)
        Incident.objects.filter(pk=inc.pk).update(date_creation=timezone.now() - timedelta(days=jours))

    def test_reserve_agents_et_superadmin(self):
        self.en_tant_que(self.citoyen())
        self.assertEqual(self.client.get(self.URL).status_code, 403)

    def test_quatorze_regions_et_exclusions(self):
        self.en_tant_que(self.superadmin())
        self.creer('incendie', 'dakar')
        self.creer('incendie', 'dakar', statut='refuse')
        r = self.client.get(self.URL)
        self.assertEqual(len(r.data['zones']), 14)
        dakar = next(z for z in r.data['zones'] if z['region'] == 'dakar')
        self.assertEqual(dakar['score'], 10.0, 'le signalement rejeté est exclu')
        self.assertEqual(r.data['methode'], 'reference-memoire-v1')
        matam = next(z for z in r.data['zones'] if z['region'] == 'matam')
        self.assertTrue(matam['donnees_insuffisantes'])

    def test_comparaison_periodes(self):
        self.en_tant_que(self.superadmin())
        self.creer('accident', 'thies', jours=3)
        self.creer('accident', 'thies', jours=12)
        debut = (timezone.localdate() - timedelta(days=6)).isoformat()
        fin = timezone.localdate().isoformat()
        r = self.client.get(self.URL, {'date_debut': debut, 'date_fin': fin, 'comparer': 1, 'region': 'thies'})
        z = r.data['zones'][0]
        self.assertEqual(z['score'], 6.0)
        self.assertEqual(z['score_precedent'], 6.0)  # récent par rapport à la fin de la période précédente
        self.assertEqual(z['evolution'], 0.0)

    def test_instantane(self):
        self.en_tant_que(self.superadmin())
        self.creer('incendie', 'dakar')
        self.assertEqual(self.client.post(self.URL + 'historique/').status_code, 201)
        self.assertEqual(len(self.client.get(self.URL + 'historique/', {'region': 'dakar'}).data), 1)


class TestAssistant(SenAlertTestCase):
    URL = '/api/analyse/assistant/'

    def setUp(self):
        super().setUp()
        self.en_tant_que(self.citoyen())

    def test_mode_secours_sans_cle(self):
        """Scénario 8 : sans fournisseur IA, l'assistant répond quand même à partir des fiches."""
        r = self.client.post(self.URL, {'message': 'Mon voisin saigne beaucoup'}, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data['source'], 'secours_local')
        self.assertIn('hemorragie', [f['slug'] for f in r.data['fiches']])
        self.assertIn('SOS', r.data['alerte_urgence'])

    @override_settings(GROQ_API_KEY='cle-test')
    def test_panne_groq_bascule_en_secours(self):
        with mock.patch('analyse.assistant.requests.post', side_effect=TimeoutError):
            r = self.client.post(self.URL, {'message': 'brûlure à la main'}, format='json')
        self.assertEqual(r.data['source'], 'secours_local')

    @override_settings(GROQ_API_KEY='cle-test')
    def test_donnees_personnelles_masquees_et_numeros_filtres(self):
        reponse = mock.Mock(status_code=200)
        reponse.json.return_value = {'choices': [{'message': {'content': 'Appelez le 112 ou le numéro 18.'}}]}
        with mock.patch('analyse.assistant.requests.post', return_value=reponse) as post:
            r = self.client.post(self.URL, {'message': 'Je suis au 77 123 45 67, écrivez à awa@mail.sn'}, format='json')
        envoye = str(post.call_args.kwargs['json'])
        self.assertNotIn('77 123 45 67', envoye)
        self.assertNotIn('awa@mail.sn', envoye)
        self.assertNotIn('cle-test', str(r.data))
        self.assertEqual(r.data['source'], 'groq')
        self.assertNotIn('112', r.data['reponse'])
        self.assertIn('18', r.data['reponse'])

    @override_settings(GROQ_API_KEY='cle-test')
    def test_mise_en_forme_markdown_retiree(self):
        reponse = mock.Mock(status_code=200)
        reponse.json.return_value = {'choices': [{'message': {'content': (
            '## Brûlure\n1. **Refroidissez la zone** : eau froide 10 à 20 min.\n* Ne percez pas les cloques.\n'
            '- Consultez la fiche **Brûlure** dans *SenAlert*.')}}]}
        with mock.patch('analyse.assistant.requests.post', return_value=reponse):
            texte = self.client.post(self.URL, {'message': 'brûlure à la main'}, format='json').data['reponse']
        self.assertNotIn('*', texte)
        self.assertNotIn('#', texte)
        self.assertIn('1. Refroidissez la zone : eau froide', texte)
        self.assertIn('• Ne percez pas les cloques.', texte)
        self.assertIn('• Consultez la fiche Brûlure dans SenAlert.', texte)

    def test_numeros_non_verifies_absents_du_prompt(self):
        self.assertNotIn('1515', assistant.prompt_systeme())
        self.assertIn('17', assistant.prompt_systeme())

    def test_validation_entree(self):
        self.assertEqual(self.client.post(self.URL, {'message': 'x' * 1001}, format='json').status_code, 400)

    def test_desactivable(self):
        Parametre.objects.filter(cle='fonctionnalites').update(valeur={'assistant_ia': False, 'connexion_google': True, 'carte_publique': True})
        self.assertEqual(self.client.post(self.URL, {'message': 'bonjour'}, format='json').status_code, 403)


# --------------------------------------------------------------------------
# Dictée vocale de l'assistant (Whisper chez Groq)
# --------------------------------------------------------------------------
from django.core.files.uploadedfile import SimpleUploadedFile  # noqa: E402


def wav(octets=3200):
    """Court WAV PCM 16 bits mono 16 kHz (silence) : suffisant pour les validations."""
    import struct
    entete = b'RIFF' + struct.pack('<I', 36 + octets) + b'WAVEfmt ' + struct.pack('<IHHIIHH', 16, 1, 1, 16000, 32000, 2, 16)
    return SimpleUploadedFile('message.wav', entete + b'data' + struct.pack('<I', octets) + b'\x00' * octets, content_type='audio/wav')


def traduction(langue, francais):
    """Réponse simulée du modèle qui rend le message dicté en français."""
    import json
    r = mock.Mock(status_code=200)
    r.json.return_value = {'choices': [{'message': {'content': json.dumps({'langue': langue, 'francais': francais})}}]}
    return r


class TestDicteeVocale(SenAlertTestCase):
    URL = '/api/analyse/assistant/transcrire/'

    def setUp(self):
        super().setUp()
        self.en_tant_que(self.citoyen())

    def envoyer(self, fichier):
        return self.client.post(self.URL, {'audio': fichier}, format='multipart')

    def test_sans_cle_indisponible_et_masque(self):
        r = self.envoyer(wav())
        self.assertEqual(r.status_code, 503)
        self.assertEqual(r.data['code'], 'dictee_indisponible')
        self.assertFalse(self.client.get('/api/configuration/').data['assistant_vocal'])

    @override_settings(GROQ_API_KEY='cle-test')
    def test_transcription_envoyee_a_whisper(self):
        reponse = mock.Mock(status_code=200)
        reponse.json.return_value = {'text': '  Que faire   en cas de brûlure ?  '}
        with mock.patch('analyse.assistant.requests.post', side_effect=[reponse, traduction('francais', 'Que faire en cas de brûlure ?')]) as post:
            r = self.envoyer(wav())
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data, {'texte': 'Que faire en cas de brûlure ?', 'langue': 'francais', 'traduit': False})
        appel = post.call_args_list[0]
        self.assertIn('/audio/transcriptions', appel.args[0])
        self.assertNotIn('language', appel.kwargs['data'])  # langue libre : le wolof ne doit pas être forcé en français
        self.assertIn('wolof', appel.kwargs['data']['prompt'])
        self.assertEqual(appel.kwargs['data']['model'], 'whisper-large-v3-turbo')
        self.assertEqual(appel.kwargs['files']['file'][0], 'message.wav')
        self.assertNotIn('cle-test', str(r.data))
        self.assertTrue(self.client.get('/api/configuration/').data['assistant_vocal'])

    @override_settings(GROQ_API_KEY='cle-test')
    def test_wolof_traduit_en_francais(self):
        whisper = mock.Mock(status_code=200)
        whisper.json.return_value = {'text': 'Am na fi safara, kër gi dafay lakk. Appelez le 77 123 45 67'}
        with mock.patch('analyse.assistant.requests.post',
                        side_effect=[whisper, traduction('wolof', "Il y a un feu ici, la maison brûle.")]) as post:
            r = self.envoyer(wav())
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data, {'texte': 'Il y a un feu ici, la maison brûle.', 'langue': 'wolof', 'traduit': True})
        appel = post.call_args_list[1]
        self.assertIn('/chat/completions', appel.args[0])
        self.assertEqual(appel.kwargs['json']['model'], 'openai/gpt-oss-120b')
        envoye = appel.kwargs['json']['messages'][1]['content']
        self.assertIn('<transcription>Am na fi safara', envoye)
        self.assertNotIn('77 123 45 67', envoye)  # téléphone masqué avant envoi au modèle

    @override_settings(GROQ_API_KEY='cle-test')
    def test_traduction_en_panne_texte_brut(self):
        whisper = mock.Mock(status_code=200)
        whisper.json.return_value = {'text': 'Am na fi safara'}
        illisible = mock.Mock(status_code=200)
        illisible.json.return_value = {'choices': [{'message': {'content': 'pas du JSON'}}]}
        for seconde in (TimeoutError(), illisible, traduction('wolof', '   ')):
            with mock.patch('analyse.assistant.requests.post', side_effect=[whisper, seconde]):
                r = self.envoyer(wav())
            self.assertEqual(r.status_code, 200)
            self.assertEqual(r.data, {'texte': 'Am na fi safara', 'langue': None, 'traduit': False})

    @override_settings(GROQ_API_KEY='cle-test')
    def test_panne_groq(self):
        with mock.patch('analyse.assistant.requests.post', side_effect=TimeoutError):
            r = self.envoyer(wav())
        self.assertEqual(r.status_code, 503)

    @override_settings(GROQ_API_KEY='cle-test')
    def test_silence_aucune_parole(self):
        reponse = mock.Mock(status_code=200)
        reponse.json.return_value = {'text': '   '}
        with mock.patch('analyse.assistant.requests.post', return_value=reponse):
            r = self.envoyer(wav())
        self.assertEqual(r.status_code, 422)
        self.assertEqual(r.data['code'], 'aucune_parole')

    @override_settings(GROQ_API_KEY='cle-test')
    def test_texte_tronque(self):
        reponse = mock.Mock(status_code=200)
        reponse.json.return_value = {'text': 'mot ' * 600}
        with mock.patch('analyse.assistant.requests.post', return_value=reponse):
            r = self.envoyer(wav())
        self.assertLessEqual(len(r.data['texte']), assistant.LONGUEUR_MAX)

    @override_settings(GROQ_API_KEY='cle-test', ASSISTANT_AUDIO_MAX_OCTETS=1000)
    def test_validations(self):
        with mock.patch('analyse.assistant.requests.post') as post:
            self.assertEqual(self.envoyer(SimpleUploadedFile('virus.exe', b'MZ', content_type='audio/wav')).status_code, 400)
            self.assertEqual(self.envoyer(SimpleUploadedFile('vide.wav', b'', content_type='audio/wav')).status_code, 400)
            self.assertEqual(self.envoyer(wav(4000)).status_code, 400)
            self.assertEqual(self.client.post(self.URL, {}, format='multipart').status_code, 400)
        post.assert_not_called()

    def test_connexion_obligatoire(self):
        self.client.force_authenticate(user=None)
        self.assertEqual(self.envoyer(wav()).status_code, 401)

    @override_settings(GROQ_API_KEY='cle-test')
    def test_desactivable(self):
        Parametre.objects.filter(cle='fonctionnalites').update(valeur={'assistant_ia': False, 'connexion_google': True, 'carte_publique': True})
        with mock.patch('analyse.assistant.requests.post') as post:
            self.assertEqual(self.envoyer(wav()).status_code, 403)
        post.assert_not_called()
        self.assertFalse(self.client.get('/api/configuration/').data['assistant_vocal'])

    @override_settings(GROQ_API_KEY='cle-test')
    def test_audio_jamais_conserve(self):
        import os
        from django.conf import settings as reglages
        avant = sum(len(f) for _, _, f in os.walk(reglages.MEDIA_ROOT)) if os.path.isdir(reglages.MEDIA_ROOT) else 0
        reponse = mock.Mock(status_code=200)
        reponse.json.return_value = {'text': 'bonjour'}
        with mock.patch('analyse.assistant.requests.post', return_value=reponse):
            self.envoyer(wav())
        apres = sum(len(f) for _, _, f in os.walk(reglages.MEDIA_ROOT)) if os.path.isdir(reglages.MEDIA_ROOT) else 0
        self.assertEqual(avant, apres)
