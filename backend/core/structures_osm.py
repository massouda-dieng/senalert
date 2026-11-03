"""Structures d'intervention tirées de l'extrait OpenStreetMap (sans dépendance aux modèles).

Utilisé par la migration qui crée les structures et par la commande `importer_structures`.
Seuls les établissements nommés et situés au Sénégal sont retenus : l'extrait Geofabrik
couvre aussi la Gambie, exclue ici par un contour approximatif.
"""
import json
from pathlib import Path

from .constants import REGIONS
from .geo import dans_senegal, distance_m

FICHIER = Path(__file__).resolve().parent / 'data' / 'services_osm.json'

# Amenity OpenStreetMap → code du core.Service qui intervient.
SERVICE_PAR_AMENITE = {'fire_station': 'pompiers', 'police': 'police', 'hospital': 'sante'}

# Services sans données OpenStreetMap : une agence par région, placée au chef-lieu
# et marquée « position approximative » jusqu'à correction par le superadministrateur.
SERVICES_PAR_REGION = {'senelec': 'Agence SENELEC', 'onas': 'Agence ONAS'}

# Contour approximatif de la Gambie (lat, lng), enclavée dans le Sénégal.
GAMBIE = [
    (13.60, -16.82), (13.59, -16.38), (13.70, -15.80), (13.80, -15.40), (13.83, -14.80), (13.80, -14.30),
    (13.65, -13.80), (13.40, -13.79), (13.30, -14.00), (13.25, -14.30), (13.20, -15.50), (13.07, -15.80),
    (13.10, -16.20), (13.06, -16.75),
]

MOTS_EXCLUS = ('checkpoint', 'check point', 'poste de contrôle')


def en_gambie(lat, lng):
    """Test point dans polygone (lancer de rayon)."""
    dedans = False
    j = len(GAMBIE) - 1
    for i, (yi, xi) in enumerate(GAMBIE):
        yj, xj = GAMBIE[j]
        if (yi > lat) != (yj > lat) and lng < (xj - xi) * (lat - yi) / (yj - yi) + xi:
            dedans = not dedans
        j = i
    return dedans


def region_de(lat, lng):
    return min(REGIONS, key=lambda c: distance_m(lat, lng, REGIONS[c]['lat'], REGIONS[c]['lng']))


def structures_osm():
    """Liste de dicts prêts à créer : nom, service (code), position, région, téléphone, adresse."""
    elements = json.loads(FICHIER.read_text(encoding='utf-8'))['elements']
    vues, resultat = set(), []
    for e in elements:
        tags = e.get('tags', {})
        service = SERVICE_PAR_AMENITE.get(tags.get('amenity'))
        nom = (tags.get('name:fr') or tags.get('name') or '').strip()
        lat, lng = e['lat'], e['lon']
        if not service or not nom or any(m in nom.lower() for m in MOTS_EXCLUS):
            continue
        if not dans_senegal(lat, lng) or en_gambie(lat, lng):
            continue
        cle = (service, nom.lower(), round(lat, 3), round(lng, 3))
        if cle in vues:
            continue
        vues.add(cle)
        adresse = ' '.join(tags[k] for k in ('addr:housenumber', 'addr:street', 'addr:city') if tags.get(k))
        resultat.append({
            'nom': nom[:150], 'service': service, 'latitude': lat, 'longitude': lng, 'region': region_de(lat, lng),
            'telephone': (tags.get('phone') or tags.get('contact:phone') or '')[:30], 'adresse': adresse[:255],
            'source': 'osm', 'reference_osm': f"{e['type']}/{e['id']}",
        })
    for service, libelle in SERVICES_PAR_REGION.items():
        for code, r in REGIONS.items():
            resultat.append({
                'nom': f"{libelle} de {r['libelle']}", 'service': service, 'latitude': r['lat'], 'longitude': r['lng'],
                'region': code, 'telephone': '', 'adresse': '', 'source': 'manuel', 'reference_osm': '',
                'position_approximative': True,
            })
    return resultat
