"""Vérification des jetons d'identité Google (OpenID Connect).

Le client (web ou mobile) obtient un ID token auprès de Google et l'envoie au
backend. Le backend vérifie la signature (clés publiques Google), l'émetteur,
l'audience (nos identifiants client) et l'expiration, puis exige un e-mail
vérifié. L'adresse e-mail transmise par le client n'est jamais utilisée seule.
"""

from django.conf import settings
from django.db import transaction
from django.utils import timezone
from rest_framework.exceptions import AuthenticationFailed, PermissionDenied

from core.constants import ROLE_CITOYEN
from core.exceptions import ServiceIndisponible

from .models import CompteExterne, User

EMETTEURS = {'accounts.google.com', 'https://accounts.google.com'}


class GoogleNonConfigure(ServiceIndisponible):
    default_detail = "La connexion Google n'est pas encore configurée sur ce serveur."
    default_code = 'google_non_configure'


def verifier_id_token(jeton):
    """Retourne les claims vérifiés ou lève AuthenticationFailed."""
    if not settings.GOOGLE_CLIENT_IDS:
        raise GoogleNonConfigure()
    from google.auth.transport import requests as google_requests
    from google.oauth2 import id_token

    try:
        claims = id_token.verify_oauth2_token(jeton, google_requests.Request(), audience=None, clock_skew_in_seconds=10)
    except ValueError:
        raise AuthenticationFailed('Jeton Google invalide ou expiré.')
    except Exception:
        raise ServiceIndisponible('Vérification Google momentanément impossible.')
    return controler_claims(claims)


def controler_claims(claims):
    if claims.get('iss') not in EMETTEURS:
        raise AuthenticationFailed('Émetteur du jeton non reconnu.')
    if claims.get('aud') not in settings.GOOGLE_CLIENT_IDS:
        raise AuthenticationFailed("Ce jeton n'est pas destiné à SenAlert.")
    if claims.get('exp', 0) < timezone.now().timestamp():
        raise AuthenticationFailed('Jeton Google expiré.')
    if not claims.get('sub'):
        raise AuthenticationFailed('Jeton Google incomplet.')
    if not claims.get('email') or claims.get('email_verified') not in (True, 'true'):
        raise AuthenticationFailed("L'adresse e-mail Google n'est pas vérifiée.")
    return claims


@transaction.atomic
def utilisateur_depuis_google(claims):
    """Retrouve ou crée le compte associé à l'identité Google.

    Règles :
      * identité déjà liée → ce compte ;
      * sinon, compte citoyen existant avec le même e-mail vérifié → liaison ;
      * compte agent/superadmin avec cet e-mail → refus : la liaison doit être
        faite depuis une session déjà authentifiée (POST /api/auth/google/lier/) ;
      * sinon → nouveau compte, TOUJOURS citoyen.
    Retourne (user, cree).
    """
    sub, email = claims['sub'], claims['email'].strip().lower()
    lien = CompteExterne.objects.select_related('user').filter(fournisseur='google', identifiant=sub).first()
    if lien:
        lien.derniere_connexion = timezone.now()
        lien.save(update_fields=['derniere_connexion'])
        return lien.user, False

    user = User.objects.filter(email__iexact=email).first()
    cree = False
    if user is not None:
        if user.role != ROLE_CITOYEN:
            raise PermissionDenied(
                "Ce compte professionnel doit d'abord se connecter avec son mot de passe, "
                "puis lier Google depuis son profil."
            )
    else:
        username = email
        if User.objects.filter(username__iexact=username).exists():
            username = f'google_{sub}'
        user = User(username=username, email=email, role=ROLE_CITOYEN,
                    first_name=claims.get('given_name', '')[:150], last_name=claims.get('family_name', '')[:150])
        user.set_unusable_password()
        user.save()
        cree = True
    if not user.is_active:
        raise AuthenticationFailed('Compte désactivé.')
    CompteExterne.objects.create(user=user, fournisseur='google', identifiant=sub, email=email,
                                 derniere_connexion=timezone.now())
    return user, cree


def lier_compte(user, claims):
    if CompteExterne.objects.filter(fournisseur='google', identifiant=claims['sub']).exclude(user=user).exists():
        raise PermissionDenied('Ce compte Google est déjà lié à un autre compte SenAlert.')
    lien, _ = CompteExterne.objects.update_or_create(
        user=user, fournisseur='google',
        defaults={'identifiant': claims['sub'], 'email': claims['email'].lower(), 'derniere_connexion': timezone.now()},
    )
    return lien
