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