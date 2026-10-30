"""Score de risque par région — méthode de référence du mémoire (v1).

    score_région = Σ poids(type de l'incident) × facteur_temporel(incident)

    poids : incendie 5, inondation 4, insécurité 4, accident 3,
            électricité 2, autre 1 (toute catégorie absente du tableau → 1)
    facteur_temporel : 2 si l'incident date de moins de 7 jours (7 × 24 h,
            borne incluse) par rapport à la date de référence, sinon 1
    niveaux : ≥ 15 critique, ≥ 8 élevé, ≥ 3 moyen, < 3 faible

Ce score est un INDICATEUR DESCRIPTIF de l'activité signalée, pas un modèle
prédictif validé : un faible nombre de signalements ne prouve pas qu'une
zone est sûre (sous-déclaration, faible usage de l'application…).
"""

from collections import defaultdict
from datetime import timedelta

from django.utils import timezone

METHODE = 'reference-memoire-v1'

POIDS_GRAVITE = {
    'incendie':    5,
    'inondation':  4,
    'insecurite':  4,
    'accident':    3,
    'electricite': 2,
    'autre':       1,
}
POIDS_PAR_DEFAUT = 1

FACTEUR_RECENT = 2.0
FACTEUR_ANCIEN = 1.0
FENETRE_RECENTE = timedelta(days=7)

SEUIL_CRITIQUE = 15
SEUIL_ELEVE    = 8
SEUIL_MOYEN    = 3

# En dessous de ce nombre d'incidents, le niveau est signalé comme peu fiable.
MIN_INCIDENTS_FIABLE = 3


def poids(type_incident):
    return POIDS_GRAVITE.get(type_incident, POIDS_PAR_DEFAUT)


def facteur_temporel(date_incident, date_reference):
    return FACTEUR_RECENT if date_incident >= date_reference - FENETRE_RECENTE else FACTEUR_ANCIEN


def calculer_score_risque(incidents_region, date_reference=None):
    reference = date_reference or timezone.now()
    score = sum(poids(inc.type_incident) * facteur_temporel(inc.date_creation, reference) for inc in incidents_region)
    return round(float(score), 2)


def determiner_niveau(score):
    if score >= SEUIL_CRITIQUE:
        return 'critique'
    elif score >= SEUIL_ELEVE:
        return 'eleve'
    elif score >= SEUIL_MOYEN:
        return 'moyen'
    return 'faible'


def analyser_zones_risque(incidents_qs, date_reference=None):
    """Score, niveau et indicateurs de contexte pour chaque région ayant au moins un incident."""
    reference = date_reference or timezone.now()
    par_region = defaultdict(list)
    for inc in incidents_qs:
        par_region[inc.region].append(inc)

    resultats = []
    for region, incidents in par_region.items():
        score = calculer_score_risque(incidents, reference)
        compteur_types = defaultdict(int)
        recents = 0
        for inc in incidents:
            compteur_types[inc.type_incident] += 1
            if facteur_temporel(inc.date_creation, reference) == FACTEUR_RECENT:
                recents += 1
        resultats.append({
            'region': region,
            'score': score,
            'niveau': determiner_niveau(score),
            'total_incidents': len(incidents),
            'types_predominants': sorted(compteur_types, key=compteur_types.get, reverse=True)[:3],
            'repartition_types': dict(compteur_types),
            'incidents_recents': recents,
            'donnees_insuffisantes': len(incidents) < MIN_INCIDENTS_FIABLE,
        })

    resultats.sort(key=lambda x: x['score'], reverse=True)
    return resultats
