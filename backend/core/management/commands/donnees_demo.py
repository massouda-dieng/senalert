import random
from datetime import timedelta

from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from accounts.models import User
from core.constants import REGIONS
from core.models import Categorie
from incidents import workflow
from incidents.models import Incident

ETIQUETTE = '[DÉMO]'

# Lieux génériques (chefs-lieux de région ± quelques centaines de mètres) : aucune
# adresse réelle ni victime réelle n'est évoquée.
SCENARIOS = [
    ('accident', 'Collision entre deux véhicules, circulation ralentie'),
    ('incendie', 'Fumée importante visible depuis la route'),
    ('inondation', 'Rue impraticable après de fortes pluies'),
    ('insecurite', 'Attroupement tendu signalé par un passant'),
    ('electricite', 'Câble électrique tombé au sol'),
    ('urgence_medicale', 'Personne ayant fait un malaise'),
    ('agression', 'Agression signalée, auteur en fuite'),
    ('autre', 'Arbre tombé sur la chaussée'),
]


class Command(BaseCommand):
    help = (f"Crée des incidents de DÉMONSTRATION (description préfixée « {ETIQUETTE} »). "
            "Ne supprime jamais de données réelles ; --supprimer retire uniquement les données de démonstration.")

    def add_arguments(self, parser):
        parser.add_argument('--nombre', type=int, default=40)
        parser.add_argument('--supprimer', action='store_true')

    def handle(self, nombre, supprimer, **opts):
        qs = Incident.objects.filter(description__startswith=ETIQUETTE)
        if supprimer:
            n = qs.count()
            qs.delete()
            self.stdout.write(self.style.SUCCESS(f'{n} incident(s) de démonstration supprimé(s).'))
            return
        citoyen = User.objects.filter(username='citoyen.test@senalert.local').first()
        if citoyen is None:
            self.stderr.write('Lancez d’abord : python manage.py creer_comptes_test')
            return
        rng = random.Random(2026)
        categories = {c.code: c for c in Categorie.objects.all()}
        regions = list(REGIONS)
        poids_regions = [8 if r == 'dakar' else 3 if r in ('thies', 'saint_louis', 'kaolack') else 1 for r in regions]
        with transaction.atomic():
            for i in range(nombre):
                type_, texte = rng.choice(SCENARIOS)
                region = rng.choices(regions, poids_regions)[0]
                base = REGIONS[region]
                cat = categories[type_]
                inc = Incident.objects.create(
                    citoyen=citoyen, type_incident=type_, description=f'{ETIQUETTE} {texte}',
                    latitude=base['lat'] + rng.uniform(-0.03, 0.03), longitude=base['lng'] + rng.uniform(-0.03, 0.03),
                    precision_gps=rng.choice([8, 15, 30, 65]), region=region, service=cat.service_defaut,
                    gravite=cat.gravite_defaut, date_creation=timezone.now() - timedelta(hours=rng.randint(1, 24 * 45)),
                )
                workflow.evenement(inc, 'creation', citoyen, 'Signalement de démonstration.', apres=inc.statut)
        self.stdout.write(self.style.SUCCESS(f'{nombre} incidents de démonstration créés (étiquetés {ETIQUETTE}).'))
