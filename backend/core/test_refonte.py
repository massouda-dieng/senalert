"""Tests de la refonte : validation des entrées, sécurité des exports et des images, statistiques, cycle complet à trois rôles."""

import csv
import io
from datetime import timedelta

from django.core.files.uploadedfile import SimpleUploadedFile
from django.core.management import call_command
from django.core.management.base import CommandError
from django.test import override_settings
from django.utils import timezone
from PIL import Image

from alerts.models import AlerteSOS
from analyse import assistant
from core.tests_utils import SenAlertTestCase
from dashboard.stats import statistiques
from dashboard.views import cellule_sure
from incidents.models import Incident
from incidents.photos import nettoyer_image
from notifications.models import Notification
from rest_framework.exceptions import ValidationError


class ParametresInvalides(SenAlertTestCase):
    """Une valeur invalide donne une erreur 400, jamais une erreur 500."""

    def test_carte_et_communaute(self):
        self.en_tant_que(self.citoyen())
        self.assertEqual(self.client.get('/api/incidents/carte/?jours=abc').status_code, 400)
        self.assertEqual(self.client.get('/api/incidents/communaute/?jours=abc').status_code, 400)
        self.assertEqual(self.client.get('/api/incidents/communaute/?lat=nan&lng=1').status_code, 400)
        self.assertEqual(self.client.get('/api/incidents/communaute/?lat=14.7&lng=-17.4&rayon_km=x').status_code, 400)

    def test_services_proches(self):
        self.en_tant_que(self.citoyen())
        self.assertEqual(self.client.get('/api/services-proximite/?lat=14&lng=-17&rayon=abc').status_code, 400)
        self.assertEqual(self.client.get('/api/services-proximite/?lat=95&lng=-17').status_code, 400)

    def test_motif_non_textuel(self):
        citoyen = self.citoyen()
        self.en_tant_que(citoyen)
        incident = Incident.objects.create(citoyen=citoyen, type_incident='autre', latitude=14.7, longitude=-17.4, region='dakar')
        r = self.client.post(f'/api/incidents/{incident.pk}/annuler/', {'motif': 123}, format='json')
        self.assertEqual(r.status_code, 400)

    def test_flux_date_sans_fuseau(self):
        self.en_tant_que(self.superadmin())
        r = self.client.get('/api/tableau-de-bord/flux/', {'depuis': '2026-10-31T10:00:00'})
        self.assertEqual(r.status_code, 200)


class SecuriteExports(SenAlertTestCase):
    def test_formule_neutralisee(self):
        self.assertEqual(cellule_sure('=HYPERLINK("http://x")'), '\'=HYPERLINK("http://x")')
        self.assertEqual(cellule_sure('@SUM(A1)'), "'@SUM(A1)")
        self.assertEqual(cellule_sure('Dakar'), 'Dakar')
        self.assertEqual(cellule_sure(-17.4), -17.4)  # une longitude reste un nombre

    def test_export_csv_de_bout_en_bout(self):
        citoyen = self.citoyen()
        Incident.objects.create(citoyen=citoyen, type_incident='autre', adresse='=cmd|calc', latitude=14.7, longitude=-17.4, region='dakar')
        self.en_tant_que(self.superadmin())
        r = self.client.get('/api/tableau-de-bord/export/csv/')
        lignes = list(csv.reader(io.StringIO(r.content.decode('utf-8-sig')), delimiter=';'))
        adresse = lignes[0].index('adresse')
        self.assertEqual(lignes[1][adresse], "'=cmd|calc")


class ImagesPiegees(SenAlertTestCase):
    def test_jpeg_tronque_refuse_proprement(self):
        tampon = io.BytesIO()
        Image.new('RGB', (400, 400), 'red').save(tampon, 'JPEG')
        fichier = SimpleUploadedFile('photo.jpg', tampon.getvalue()[:200], content_type='image/jpeg')
        with self.assertRaises(ValidationError):
            nettoyer_image(fichier)


class Statistiques(SenAlertTestCase):
    def test_comparaison_et_delai(self):
        citoyen = self.citoyen()
        maintenant = timezone.now()
        Incident.objects.create(citoyen=citoyen, type_incident='autre', latitude=14.7, longitude=-17.4, region='dakar',
                                date_creation=maintenant - timedelta(days=2), date_prise_en_charge=maintenant - timedelta(days=2) + timedelta(minutes=30))
        Incident.objects.create(citoyen=citoyen, type_incident='autre', latitude=14.7, longitude=-17.4, region='dakar',
                                date_creation=maintenant - timedelta(days=40))
        AlerteSOS.objects.create(citoyen=citoyen, region='dakar', date_creation=maintenant - timedelta(days=1),
                                 date_prise_en_charge=maintenant - timedelta(days=1) + timedelta(minutes=10))
        s = statistiques({})
        self.assertEqual(s['resume']['total_signalements'], 2)
        self.assertEqual(s['comparaison']['total_signalements'], 1)
        self.assertEqual(s['resume']['delai_moyen_prise_en_charge_min'], 20.0)  # (30 + 10) / 2
        self.assertEqual(len(s['comparaison']['evolution']), len(s['evolution']['incidents']))
        self.assertEqual(sum(s['interventions']['prises_en_charge'].values()), 2)


class Notifications(SenAlertTestCase):
    def test_signalement_sans_agent_previent_le_superviseur(self):
        superadmin = self.superadmin()
        citoyen = self.citoyen()
        self.en_tant_que(citoyen)
        with self.captureOnCommitCallbacks(execute=True):
            r = self.client.post('/api/incidents/', {'type_incident': 'accident', 'latitude': 12.56, 'longitude': -16.27}, format='json')
        self.assertEqual(r.status_code, 201)
        self.assertTrue(Notification.objects.filter(destinataire=superadmin, type='nouvelle_alerte').exists())


class Assistant(SenAlertTestCase):
    def test_oriente_vers_le_bon_ecran_sans_ia(self):
        r = assistant.repondre('Où trouver une pharmacie proche ?')
        self.assertEqual(r['source'], 'secours_local')
        self.assertEqual(r['actions'][0]['cible'], '/citoyen/services')

    def test_conseil_de_prevention_local(self):
        self.assertIn('hivernage', assistant.repondre('Comment me préparer à la pluie ?')['reponse'].lower())

    def test_avertissement_professionnels(self):
        self.assertIn('professionnel de santé', assistant.repondre('bonjour')['avertissement'])


class Commandes(SenAlertTestCase):
    @override_settings(DEBUG=False, TESTING=False)
    def test_comptes_et_demo_interdits_en_production(self):
        with self.assertRaises(CommandError):
            call_command('creer_comptes_test')
        with self.assertRaises(CommandError):
            call_command('donnees_demo')

    def test_demo_couvre_le_cycle_et_se_supprime(self):
        call_command('creer_comptes_test', stdout=io.StringIO())
        reel = Incident.objects.create(citoyen=self.citoyen(), type_incident='autre', description='Vrai', latitude=14.7, longitude=-17.4, region='dakar')
        call_command('donnees_demo', nombre=60, stdout=io.StringIO())
        statuts = set(Incident.objects.values_list('statut', flat=True))
        self.assertLessEqual({'nouveau', 'resolu'}, statuts)
        self.assertTrue(statuts & {'affecte', 'accepte', 'en_cours'})
        pris = Incident.objects.filter(date_prise_en_charge__isnull=False, description__startswith='[DÉMO]').first()
        self.assertLess(pris.date_prise_en_charge - pris.date_creation, timedelta(hours=3))
        call_command('donnees_demo', supprimer=True, stdout=io.StringIO())
        self.assertEqual(list(Incident.objects.all()), [reel])
        self.assertFalse(AlerteSOS.objects.filter(message__startswith='[DÉMO]').exists())


class CycleTroisRoles(SenAlertTestCase):
    """Citoyen → signalement → superadministrateur → affectation → agent → intervention → clôture, par l'API."""

    def test_parcours_complet_et_cloisonnement(self):
        citoyen, superadmin = self.citoyen(), self.superadmin()
        agent = self.agent()
        autre_citoyen = self.citoyen(nom='autre')

        self.en_tant_que(citoyen)
        with self.captureOnCommitCallbacks(execute=True):
            r = self.client.post('/api/alertes/sos/', {'latitude': 14.69, 'longitude': -17.44, 'precision_gps': 12}, format='json')
        self.assertEqual(r.status_code, 201)
        self.assertEqual((AlerteSOS.objects.get(pk=r.data['id']).latitude, r.data['deja_enregistree']), (14.69, False))
        self.assertTrue(Notification.objects.filter(destinataire=superadmin, alerte_id=r.data['id']).exists())

        with self.captureOnCommitCallbacks(execute=True):
            r = self.client.post('/api/incidents/', {'type_incident': 'incendie', 'latitude': 14.68, 'longitude': -17.43, 'description': 'Feu dans un entrepôt'}, format='json')
        self.assertEqual(r.status_code, 201)
        url = f"/api/incidents/{r.data['id']}/"
        self.assertEqual(self.client.post(f'{url}affecter/', {'agent': agent.pk}, format='json').status_code, 403)
        self.assertEqual(self.client.get('/api/tableau-de-bord/statistiques/').status_code, 403)
        self.assertEqual(self.client.get('/api/gestion/utilisateurs/').status_code, 403)

        self.en_tant_que(autre_citoyen)
        self.assertEqual(self.client.get(url).status_code, 404)  # dossier d'un autre citoyen invisible

        self.en_tant_que(superadmin)
        with self.captureOnCommitCallbacks(execute=True):
            r = self.client.post(f'{url}affecter/', {'agent': agent.pk}, format='json')
        self.assertEqual((r.status_code, r.data['statut']), (200, 'affecte'))
        self.assertTrue(Notification.objects.filter(destinataire=agent, type='affectation').exists())

        self.en_tant_que(agent)
        self.assertEqual(self.client.get('/api/gestion/utilisateurs/').status_code, 403)
        for action, attendu in (('accepter', 'accepte'), ('demarrer', 'en_cours')):
            with self.captureOnCommitCallbacks(execute=True):
                r = self.client.post(f'{url}{action}/')
            self.assertEqual((r.status_code, r.data['statut']), (200, attendu))
        self.assertEqual(self.client.post(f'{url}position-agent/', {'latitude': 14.7, 'longitude': -17.45}, format='json').status_code, 200)
        self.assertEqual(self.client.post(f'{url}resoudre/', {'compte_rendu': 'court'}, format='json').status_code, 400)
        with self.captureOnCommitCallbacks(execute=True):
            r = self.client.post(f'{url}resoudre/', {'compte_rendu': 'Feu maîtrisé, zone sécurisée.'}, format='json')
        self.assertEqual((r.status_code, r.data['statut']), (200, 'resolu'))
        self.assertIsNone(r.data['intervention']['position_agent'])  # position effacée à la clôture

        self.en_tant_que(citoyen)
        r = self.client.get(url)
        self.assertEqual(r.data['statut'], 'resolu')
        self.assertEqual(r.data['intervention']['agent_nom'], 'Agent de secours')  # identité de l'agent masquée
        self.assertTrue(Notification.objects.filter(destinataire=citoyen, type='resolution').exists())
        self.assertGreaterEqual(len(self.client.get(f'{url}evenements/').data), 4)
        self.assertEqual(self.client.post(f'{url}evaluer/', {'note': 5}, format='json').status_code, 200)

        self.en_tant_que(superadmin)
        s = self.client.get('/api/tableau-de-bord/statistiques/').data
        self.assertEqual(s['resume']['resolus'], 1)
        self.assertEqual(s['satisfaction']['nombre'], 1)
