"""Lecture sûre des paramètres de requête : une valeur invalide donne une erreur 400 claire, jamais une erreur 500."""

import math

from rest_framework.exceptions import ValidationError


def entier(valeur, defaut, mini, maxi, nom):
    """Entier borné ; `defaut` si la valeur est absente."""
    if valeur in (None, ''):
        return defaut
    try:
        return max(mini, min(int(valeur), maxi))
    except (TypeError, ValueError):
        raise ValidationError({nom: 'Nombre entier attendu.'})


def decimal(valeur, defaut, mini, maxi, nom):
    """Nombre borné ; refuse NaN et l'infini, que float() accepte."""
    if valeur in (None, ''):
        return defaut
    try:
        nombre = float(valeur)
    except (TypeError, ValueError):
        raise ValidationError({nom: 'Nombre attendu.'})
    if not math.isfinite(nombre):
        raise ValidationError({nom: 'Nombre attendu.'})
    return max(mini, min(nombre, maxi))


def coordonnees(lat, lng):
    """Paire latitude / longitude valide, ou ValidationError."""
    try:
        lat, lng = float(lat), float(lng)
    except (TypeError, ValueError):
        raise ValidationError({'lat': 'Paramètres lat et lng requis.'})
    if not (math.isfinite(lat) and math.isfinite(lng) and -90 <= lat <= 90 and -180 <= lng <= 180):
        raise ValidationError({'lat': 'Coordonnées invalides.'})
    return lat, lng


def motif(donnees):
    """Texte du motif : une valeur non textuelle (nombre, liste) compte comme vide."""
    valeur = donnees.get('motif', '')
    return valeur.strip() if isinstance(valeur, str) else ''
