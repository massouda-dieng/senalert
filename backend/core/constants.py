"""Référentiels stables partagés par toutes les apps (codes = valeurs en base)."""

# Les 14 régions administratives du Sénégal. Les coordonnées sont celles du
# chef-lieu de région : elles servent uniquement à centrer la carte et à
# placer les scores de risque, jamais à localiser un incident.
REGIONS = {
    'dakar':       {'libelle': 'Dakar',       'lat': 14.6928, 'lng': -17.4467},
    'thies':       {'libelle': 'Thiès',       'lat': 14.7910, 'lng': -16.9260},
    'saint_louis': {'libelle': 'Saint-Louis', 'lat': 16.0326, 'lng': -16.4818},
    'diourbel':    {'libelle': 'Diourbel',    'lat': 14.6550, 'lng': -16.2314},
    'louga':       {'libelle': 'Louga',       'lat': 15.6142, 'lng': -16.2287},
    'fatick':      {'libelle': 'Fatick',      'lat': 14.3390, 'lng': -16.4110},
    'kaolack':     {'libelle': 'Kaolack',     'lat': 14.1652, 'lng': -16.0726},
    'kaffrine':    {'libelle': 'Kaffrine',    'lat': 14.1059, 'lng': -15.5508},
    'matam':       {'libelle': 'Matam',       'lat': 15.6559, 'lng': -13.2554},
    'tambacounda': {'libelle': 'Tambacounda', 'lat': 13.7707, 'lng': -13.6673},
    'kedougou':    {'libelle': 'Kédougou',    'lat': 12.5556, 'lng': -12.1743},
    'kolda':       {'libelle': 'Kolda',       'lat': 12.8939, 'lng': -14.9407},
    'sedhiou':     {'libelle': 'Sédhiou',     'lat': 12.7081, 'lng': -15.5569},
    'ziguinchor':  {'libelle': 'Ziguinchor',  'lat': 12.5833, 'lng': -16.2719},
}
REGION_CHOICES = [(code, r['libelle']) for code, r in REGIONS.items()]

# Emprise approximative du Sénégal (contrôle de cohérence des coordonnées).
BBOX_SENEGAL = {'lat_min': 12.0, 'lat_max': 16.8, 'lng_min': -17.8, 'lng_max': -11.3}

ROLE_CITOYEN = 'citoyen'
ROLE_AGENT = 'agent'
ROLE_SUPERADMIN = 'superadmin'
ROLE_CHOICES = [
    (ROLE_CITOYEN, 'Citoyen'),
    (ROLE_AGENT, 'Agent de secours'),
    (ROLE_SUPERADMIN, 'Superadministrateur'),
]

# Cycle de vie d'un dossier (incident ou alerte SOS).
#   nouveau → affecte → accepte → en_cours → resolu
#   + refuse (signalement non fondé), annule (annulation motivée)
NOUVEAU, AFFECTE, ACCEPTE, EN_COURS, RESOLU, REFUSE, ANNULE = (
    'nouveau', 'affecte', 'accepte', 'en_cours', 'resolu', 'refuse', 'annule'
)
STATUT_CHOICES = [
    (NOUVEAU, 'Nouveau'),
    (AFFECTE, 'Affecté'),
    (ACCEPTE, 'Accepté'),
    (EN_COURS, 'En cours'),
    (RESOLU, 'Résolu'),
    (REFUSE, 'Rejeté'),
    (ANNULE, 'Annulé'),
]
STATUTS_FINAUX = {RESOLU, REFUSE, ANNULE}
STATUTS_ACTIFS = {NOUVEAU, AFFECTE, ACCEPTE, EN_COURS}

GRAVITE_CHOICES = [
    ('faible', 'Faible'),
    ('moyenne', 'Moyenne'),
    ('elevee', 'Élevée'),
    ('critique', 'Critique'),
]
GRAVITE_ORDRE = {'faible': 0, 'moyenne': 1, 'elevee': 2, 'critique': 3}
