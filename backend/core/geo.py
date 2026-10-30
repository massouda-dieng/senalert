import math

from .constants import BBOX_SENEGAL

RAYON_TERRE_M = 6_371_000


def distance_m(lat1, lng1, lat2, lng2):
    """Distance orthodromique (formule de haversine), en mètres."""
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = p2 - p1
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * RAYON_TERRE_M * math.asin(math.sqrt(a))


def boite_englobante(lat, lng, rayon_m):
    """Rectangle lat/lng contenant le cercle (pré-filtrage SQL avant haversine)."""
    dlat = rayon_m / 111_320
    dlng = rayon_m / (111_320 * max(math.cos(math.radians(lat)), 0.01))
    return lat - dlat, lat + dlat, lng - dlng, lng + dlng


def dans_senegal(lat, lng):
    b = BBOX_SENEGAL
    return b['lat_min'] <= lat <= b['lat_max'] and b['lng_min'] <= lng <= b['lng_max']


def region_la_plus_proche(lat, lng):
    from .constants import REGIONS
    return min(REGIONS, key=lambda c: distance_m(lat, lng, REGIONS[c]['lat'], REGIONS[c]['lng']))
