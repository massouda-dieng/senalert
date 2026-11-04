"""Choix des structures et des agents : structures les plus proches, agents disponibles, choix automatique (SOS)."""
from django.db.models import Count, Q

from .constants import REGIONS, ROLE_AGENT, STATUTS_ACTIFS, TYPES_URGENCE
from .geo import distance_m, region_la_plus_proche
from .models import Structure
from .structures_osm import SERVICES_PAR_REGION

# SOS sans type d'urgence précisé : structure de secours la plus proche, tous services confondus.
SERVICES_SOS = TYPES_URGENCE['non_precise']['services']


def structures_proches(lat, lng, services=None, limite=8, region=None):
    """Structures actives compétentes pour le lieu : liste de (structure, distance en mètres).

    La proximité ne remplace pas la compétence territoriale : les structures de la région du lieu
    passent d'abord (par distance), puis, seulement s'il en manque, celles des régions voisines.
    Les services organisés en agences régionales (SENELEC, ONAS) ne sont proposés que dans la région.
    """
    region = region or region_la_plus_proche(lat, lng)
    qs = Structure.objects.filter(actif=True).select_related('service')
    if services:
        qs = qs.filter(service__code__in=services)
    avec_distance = [(s, distance_m(lat, lng, s.latitude, s.longitude)) for s in qs
                     if s.region == region or s.service.code not in SERVICES_PAR_REGION]
    avec_distance.sort(key=lambda x: (x[0].region != region, x[1]))
    return avec_distance[:limite]


def agents_disponibles(structure):
    """Agents actifs et disponibles de la structure, les moins chargés d'abord."""
    from accounts.models import User
    actives = Q(interventions__incident__statut__in=STATUTS_ACTIFS) | Q(interventions__alerte__statut__in=STATUTS_ACTIFS)
    return (User.objects.filter(role=ROLE_AGENT, is_active=True, structure=structure, profil_agent__disponible=True)
            .select_related('profil_agent')
            .annotate(missions_actives=Count('interventions', filter=actives, distinct=True))
            .order_by('missions_actives', 'first_name', 'pk'))


def choix_automatique(lat, lng, region, services):
    """Structure la plus proche ayant un agent disponible, et cet agent (SOS, signalement sans choix).

    Sans agent disponible à proximité, le dossier va à la structure la plus proche sans agent :
    son superviseur l'affectera. Sans position, on se replie sur le chef-lieu de la région.
    """
    if lat is None or lng is None:
        r = REGIONS.get(region)
        if not r:
            return None, None
        lat, lng = r['lat'], r['lng']
    proches = structures_proches(lat, lng, services, limite=10, region=region)
    for structure, _ in proches:
        agent = agents_disponibles(structure).first()
        if agent:
            return structure, agent
    return (proches[0][0], None) if proches else (None, None)
