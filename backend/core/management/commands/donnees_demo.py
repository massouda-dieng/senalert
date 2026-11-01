import random
from datetime import timedelta

from django.conf import settings
from django.core.cache import cache
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils import timezone

from accounts.models import User
from alerts.models import AlerteSOS
from core.constants import ACCEPTE, AFFECTE, ANNULE, EN_COURS, NOUVEAU, REFUSE, REGIONS, RESOLU
from core.models import Categorie
from incidents.models import EvenementDossier, Incident, Intervention

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

ZONES_AGENTS = ('dakar', 'thies')  # zones couvertes par les agents de test
COMPTES_RENDUS = [
    'Situation sécurisée, retour à la normale. (démonstration)',
    'Intervention terminée, personnes prises en charge sur place. (démonstration)',
    'Zone balisée puis service concerné prévenu. (démonstration)',
]


class Command(BaseCommand):
    help = (f"Crée des dossiers de DÉMONSTRATION à toutes les étapes du cycle de vie (description préfixée « {ETIQUETTE} »). "
            "Ne supprime jamais de données réelles ; --supprimer retire uniquement les données de démonstration.")

    def add_arguments(self, parser):
        parser.add_argument('--nombre', type=int, default=60)
        parser.add_argument('--supprimer', action='store_true')

    def handle(self, nombre, supprimer, **opts):
        if not (settings.DEBUG or settings.TESTING):
            raise CommandError('Données de démonstration interdites en production (DEBUG=False).')
        incidents = Incident.objects.filter(description__startswith=ETIQUETTE)
        sos = AlerteSOS.objects.filter(message__startswith=ETIQUETTE)
        if supprimer:
            n, ns = incidents.count(), sos.count()
            incidents.delete()
            sos.delete()
            cache.delete('stats_publiques')
            self.stdout.write(self.style.SUCCESS(f'{n} incident(s) et {ns} SOS de démonstration supprimé(s).'))
            return
        citoyen = User.objects.filter(username='citoyen.test@senalert.local').first()
        superviseur = User.objects.filter(username='superadmin.test@senalert.local').first()
        if citoyen is None or superviseur is None:
            self.stderr.write('Lancez d’abord : python manage.py creer_comptes_test')
            return
        self.rng = random.Random(2026)
        self.superviseur = superviseur
        self.agents = {
            a.profil_agent.service_id: a
            for a in User.objects.filter(role='agent', username__endswith='@senalert.local', is_active=True).select_related('profil_agent')
            if getattr(a, 'profil_agent', None) and a.profil_agent.service_id
        }
        categories = {c.code: c for c in Categorie.objects.all()}
        regions = list(REGIONS)
        poids_regions = [8 if r == 'dakar' else 3 if r in ('thies', 'saint_louis', 'kaolack') else 1 for r in regions]
        rng = self.rng
        with transaction.atomic():
            for i in range(nombre):
                type_, texte = rng.choice(SCENARIOS)
                # Un dossier sur quatre est récent et couvert par les agents de test : les tableaux de bord ont du travail en cours.
                recent = i % 4 == 0
                region = rng.choice(ZONES_AGENTS) if recent else rng.choices(regions, poids_regions)[0]
                base = REGIONS[region]
                cat = categories[type_]
                creation = timezone.now() - timedelta(hours=rng.randint(1, 60) if recent else rng.randint(73, 24 * 58))
                inc = Incident.objects.create(
                    citoyen=citoyen, type_incident=type_, description=f'{ETIQUETTE} {texte}',
                    latitude=base['lat'] + rng.uniform(-0.03, 0.03), longitude=base['lng'] + rng.uniform(-0.03, 0.03),
                    precision_gps=rng.choice([8, 15, 30, 65]), region=region, service=cat.service_defaut,
                    gravite=cat.gravite_defaut, date_creation=creation,
                )
                self.derouler(inc, 'Signalement de démonstration.', cat.service_defaut_id)
            services_sos = list(self.agents)
            for _ in range(max(6, nombre // 6)):
                region = rng.choices(regions, poids_regions)[0]
                base = REGIONS[region]
                alerte = AlerteSOS.objects.create(
                    citoyen=citoyen, message=f'{ETIQUETTE} SOS de démonstration', gravite='critique', source_position='gps',
                    latitude=base['lat'] + rng.uniform(-0.03, 0.03), longitude=base['lng'] + rng.uniform(-0.03, 0.03),
                    precision_gps=rng.choice([8, 15, 30]), region=region,
                    date_creation=timezone.now() - timedelta(hours=rng.randint(1, 24 * 58)),
                )
                self.derouler(alerte, 'Alerte de démonstration.', rng.choice(services_sos) if services_sos else None)
        cache.delete('stats_publiques')
        self.stdout.write(self.style.SUCCESS(f'{nombre} incidents et SOS de démonstration créés (étiquetés {ETIQUETTE}).'))

    def statut_cible(self, dossier):
        """Les dossiers anciens sont clos ; les récents, couverts par un agent de test, sont en cours de traitement."""
        age_h = (timezone.now() - dossier.date_creation).total_seconds() / 3600
        if age_h > 72:
            return self.rng.choices([RESOLU, REFUSE, ANNULE, NOUVEAU], [78, 8, 6, 8])[0]
        if dossier.region not in ZONES_AGENTS:
            return NOUVEAU
        return self.rng.choice([NOUVEAU, AFFECTE, AFFECTE, ACCEPTE, EN_COURS])

    def evenement(self, dossier, type_, date, message='', avant='', apres='', acteur=None, visible=True):
        lien = {'incident': dossier} if isinstance(dossier, Incident) else {'alerte': dossier}
        EvenementDossier.objects.create(type=type_, acteur=acteur, message=message, statut_avant=avant, statut_apres=apres,
                                        visible_citoyen=visible, date=date, **lien)

    def derouler(self, dossier, message, service_id):
        """Reconstitue un parcours daté. Les dates sont écrites directement : le délai affiché reste plausible."""
        rng = self.rng
        cible = self.statut_cible(dossier)
        creation = dossier.date_creation
        self.evenement(dossier, 'creation', creation, message, apres=NOUVEAU, acteur=dossier.citoyen)
        agent = self.agents.get(service_id)
        if cible in (REFUSE, ANNULE):
            cloture = creation + timedelta(minutes=rng.randint(20, 180))
            motif = 'Motif de démonstration.'
            self.evenement(dossier, 'transition', cloture, motif, NOUVEAU, cible, self.superviseur)
            self.maj(dossier, statut=cible, date_cloture=cloture, motif_cloture=motif)
            return
        if cible == NOUVEAU or agent is None:
            return

        lien = {'incident': dossier} if isinstance(dossier, Incident) else {'alerte': dossier}
        # SOS plus rapides que les incidents, comme le prévoient les délais configurés.
        pas = (2, 9) if not isinstance(dossier, Incident) else (5, 45)
        affectation = creation + timedelta(minutes=rng.randint(*pas))
        inter = Intervention(service_id=service_id, agent=agent, affecte_par=self.superviseur, date_affectation=affectation, **lien)
        self.evenement(dossier, 'transition', affectation, 'Dossier transmis au service.', NOUVEAU, AFFECTE, self.superviseur)
        valeurs = {'statut': AFFECTE, 'service_id': service_id}
        if cible != AFFECTE:
            acceptation = affectation + timedelta(minutes=rng.randint(*pas))
            inter.date_acceptation = acceptation
            valeurs.update(statut=ACCEPTE, date_prise_en_charge=acceptation)
            self.evenement(dossier, 'transition', acceptation, 'Intervention acceptée par un agent.', AFFECTE, ACCEPTE, agent)
            if cible in (EN_COURS, RESOLU):
                debut = acceptation + timedelta(minutes=rng.randint(3, 20))
                inter.date_debut = debut
                valeurs['statut'] = EN_COURS
                self.evenement(dossier, 'transition', debut, 'Les secours sont en route ou sur place.', ACCEPTE, EN_COURS, agent)
                if cible == RESOLU:
                    fin = debut + timedelta(minutes=rng.randint(20, 150))
                    inter.date_fin = fin
                    inter.compte_rendu = f'{ETIQUETTE} {rng.choice(COMPTES_RENDUS)}'
                    if rng.random() < 0.6:
                        inter.note_satisfaction = rng.choice([3, 4, 4, 5, 5])
                        inter.date_evaluation = fin + timedelta(hours=2)
                    valeurs.update(statut=RESOLU, date_cloture=fin)
                    self.evenement(dossier, 'transition', fin, 'Intervention terminée.', EN_COURS, RESOLU, agent)
        inter.save()
        self.maj(dossier, **valeurs)

    @staticmethod
    def maj(dossier, **valeurs):
        type(dossier).objects.filter(pk=dossier.pk).update(**valeurs)
