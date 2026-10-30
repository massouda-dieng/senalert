import io

from django.conf import settings
from django.core.files.base import ContentFile
from PIL import Image, ImageOps, UnidentifiedImageError
from rest_framework.exceptions import ValidationError

from .models import PieceJointe

FORMATS_ACCEPTES = {'JPEG', 'PNG', 'WEBP'}
COTE_MAX = 2048
PIXELS_MAX = 40_000_000


def nettoyer_image(fichier):
    """Valide une image et la ré-encode en JPEG sans métadonnées.

    Le ré-encodage supprime les données EXIF (dont la position GPS du
    téléphone) et neutralise les fichiers piégés déguisés en image.
    """
    if fichier.size > settings.PIECE_JOINTE_TAILLE_MAX:
        raise ValidationError({'photos': f'« {fichier.name} » dépasse 5 Mo.'})
    try:
        image = Image.open(fichier)
        if image.format not in FORMATS_ACCEPTES:
            raise ValidationError({'photos': 'Formats acceptés : JPEG, PNG ou WEBP.'})
        if image.width * image.height > PIXELS_MAX:
            raise ValidationError({'photos': 'Image trop grande.'})
        image.verify()
        fichier.seek(0)
        image = ImageOps.exif_transpose(Image.open(fichier))
    except ValidationError:
        raise
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise ValidationError({'photos': f'« {fichier.name} » n’est pas une image valide.'})

    image = image.convert('RGB')
    image.thumbnail((COTE_MAX, COTE_MAX))
    sortie = io.BytesIO()
    image.save(sortie, format='JPEG', quality=85, optimize=True)
    return ContentFile(sortie.getvalue(), name='photo.jpg'), image.width, image.height


def valider_photos(fichiers, deja=0):
    if deja + len(fichiers) > settings.PIECES_JOINTES_MAX_PAR_DOSSIER:
        raise ValidationError({'photos': f'{settings.PIECES_JOINTES_MAX_PAR_DOSSIER} photos maximum par dossier.'})
    return [nettoyer_image(f) for f in fichiers]


def enregistrer_photos(incident, photos_nettoyees, auteur):
    pieces = []
    for contenu, largeur, hauteur in photos_nettoyees:
        pj = PieceJointe(incident=incident, auteur=auteur, taille=contenu.size, largeur=largeur, hauteur=hauteur)
        pj.fichier.save(contenu.name, contenu, save=True)
        pieces.append(pj)
    return pieces
