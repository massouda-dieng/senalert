from collections import defaultdict
from datetime import timedelta
from django.utils import timezone

POIDS_GRAVITE = {
    'incendie':    5,
    'inondation':  4,
    'insecurite':  4,
    'accident':    3,
    'electricite': 2,
    'autre':       1,
}

SEUIL_CRITIQUE = 15
SEUIL_ELEVE    = 8
SEUIL_MOYEN    = 3


def calculer_score_risque(incidents_region):
    maintenant = timezone.now()
    seuil_recent = maintenant - timedelta(days=7)
    score = 0.0

    for inc in incidents_region:
        poids = POIDS_GRAVITE.get(inc.type_incident, 1)
        facteur = 2.0 if inc.date_creation >= seuil_recent else 1.0
        score += poids * facteur

    return round(score, 2)


def determiner_niveau(score):
    if score >= SEUIL_CRITIQUE:
        return 'critique'
    elif score >= SEUIL_ELEVE:
        return 'eleve'
    elif score >= SEUIL_MOYEN:
        return 'moyen'
    return 'faible'


def analyser_zones_risque(incidents_qs):
    par_region = defaultdict(list)
    for inc in incidents_qs:
        par_region[inc.region].append(inc)

    resultats = []
    maintenant = timezone.now()
    seuil_recent = maintenant - timedelta(days=7)

    for region, incidents in par_region.items():
        score = calculer_score_risque(incidents)

        compteur_types = defaultdict(int)
        recents = 0
        for inc in incidents:
            compteur_types[inc.type_incident] += 1
            if inc.date_creation >= seuil_recent:
                recents += 1

        types_predominants = sorted(
            compteur_types, key=compteur_types.get, reverse=True
        )[:3]

        resultats.append({
            'region': region,
            'score': score,
            'niveau': determiner_niveau(score),
            'total_incidents': len(incidents),
            'types_predominants': types_predominants,
            'incidents_recents': recents,
        })

    resultats.sort(key=lambda x: x['score'], reverse=True)
    return resultats