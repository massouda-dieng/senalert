import csv
import io
from datetime import timedelta

from django.utils import timezone

from alerts.models import AlerteSOS
from core.models import JournalAudit
from core.tests_utils import SenAlertTestCase
from incidents.models import Incident

URL = '/api/tableau-de-bord/statistiques/'


class StatistiquesTests(SenAlertTestCase):
    def setUp(self):
        super().setUp()
        self.awa = self.citoyen()
        maintenant = timezone.now()
        Incident.objects.create(citoyen=self.awa, type_incident='incendie', region='dakar', latitude=14.7, longitude=-17.4,
                                statut='resolu', date_prise_en_charge=maintenant + timedelta(minutes=20),
                                date_cloture=maintenant + timedelta(minutes=80), date_creation=maintenant,
                                description='Description suffisamment longue')
        Incident.objects.create(citoyen=self.awa, type_incident='accident', region='thies', statut='nouveau')
        Incident.objects.create(citoyen=self.awa, type_incident='accident', region='thies', statut='refuse')
        AlerteSOS.objects.create(citoyen=self.awa, region='dakar')
        old = Incident.objects.create(citoyen=self.awa, type_incident='accident', region='dakar')
        Incident.objects.filter(pk=old.pk).update(date_creation=timezone.now() - timedelta(days=90))

    def test_reserve_au_superadmin(self):
        for u in (self.awa, self.agent()):
            self.en_tant_que(u)
            self.assertEqual(self.client.get(URL).status_code, 403)

    def test_indicateurs_coherents_avec_la_base(self):
        """Scénario 5 : les indicateurs reflètent les données réelles (30 derniers jours par défaut)."""
        self.en_tant_que(self.superadmin())
        r = self.client.get(URL).data
        self.assertEqual(r['resume']['total_incidents'], 3)
        self.assertEqual(r['resume']['total_sos'], 1)
        self.assertEqual(r['resume']['resolus'], 1)
        self.assertEqual(r['resume']['taux_resolution'], round(100 * 1 / 3, 1))  # 4 dossiers − 1 rejeté
        self.assertEqual(r['incidents']['delai_moyen_prise_en_charge_min'], 20.0)
        self.assertIn('taux_resolution', r['definitions'])
        self.assertEqual(len(r['evolution']['incidents']), 30, 'une valeur par jour, y compris les jours sans signalement')
        self.assertEqual(sum(r['evolution']['incidents'].values()), 3)
        self.assertEqual(r['qualite']['avec_position_pct'], round(100 / 3, 1))
        # Un nouvel incident fait évoluer l'indicateur
        Incident.objects.create(citoyen=self.awa, type_incident='inondation', region='dakar')
        self.assertEqual(self.client.get(URL).data['resume']['total_incidents'], 4)

    def test_filtres_appliques(self):
        self.en_tant_que(self.superadmin())
        r = self.client.get(URL, {'region': 'thies'}).data
        self.assertEqual(r['resume']['total_incidents'], 2)
        self.assertEqual(r['resume']['total_sos'], 0)
        debut = (timezone.localdate() - timedelta(days=120)).isoformat()
        self.assertEqual(self.client.get(URL, {'date_debut': debut}).data['resume']['total_incidents'], 4)
        self.assertEqual(self.client.get(URL, {'date_debut': '2026-13-01'}).status_code, 400)

    def test_export_csv_sans_donnees_personnelles(self):
        self.awa.telephone = '770000001'
        self.awa.save()
        self.en_tant_que(self.superadmin())
        r = self.client.get('/api/tableau-de-bord/export/csv/', {'region': 'thies'})
        self.assertEqual(r.status_code, 200)
        contenu = r.content.decode('utf-8-sig')
        lignes = list(csv.reader(io.StringIO(contenu), delimiter=';'))
        self.assertEqual(len(lignes), 3)  # en-tête + 2 incidents de Thiès
        self.assertNotIn('770000001', contenu)
        self.assertNotIn('awa@test.sn', contenu)
        self.assertTrue(JournalAudit.objects.filter(action='export.csv').exists())

    def test_export_pdf(self):
        self.en_tant_que(self.superadmin())
        r = self.client.get('/api/tableau-de-bord/export/pdf/')
        self.assertEqual(r.status_code, 200)
        self.assertTrue(b''.join(r.streaming_content).startswith(b'%PDF'))

    def test_activite_agent(self):
        agent = self.en_tant_que(self.agent())
        r = self.client.get('/api/tableau-de-bord/activite-agent/')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data['incidents']['total'], 0)
        self.assertIsNotNone(agent)
