import logging

from django.core.exceptions import PermissionDenied, ValidationError as DjangoValidationError
from django.http import Http404
from rest_framework import status
from rest_framework.exceptions import APIException
from rest_framework.response import Response
from rest_framework.views import exception_handler

logger = logging.getLogger('senalert')


class Conflit(APIException):
    """Le dossier a changé entre-temps (action concurrente) ou l'action n'est plus possible."""

    status_code = status.HTTP_409_CONFLICT
    default_detail = "Ce dossier a été modifié entre-temps. Actualisez puis réessayez."
    default_code = 'conflit'


class ServiceIndisponible(APIException):
    status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    default_detail = 'Service externe momentanément indisponible.'
    default_code = 'service_indisponible'


def gestionnaire_exceptions(exc, context):
    """Format d'erreur homogène : {"detail": "...", "code": "...", "champs": {...}}.

    Les erreurs inattendues sont journalisées côté serveur et renvoyées sous
    une forme générique, sans trace ni détail interne.
    """
    if isinstance(exc, DjangoValidationError):
        exc_resp = Response({'detail': ' '.join(exc.messages), 'code': 'invalide'}, status=400)
        return exc_resp

    response = exception_handler(exc, context)
    if response is None:
        if isinstance(exc, (Http404, PermissionDenied)):
            return response
        logger.exception('Erreur interne non gérée sur %s', context.get('view').__class__.__name__)
        return Response(
            {'detail': 'Une erreur interne est survenue. Réessayez plus tard.', 'code': 'erreur_interne'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR,
        )

    data = response.data
    if isinstance(data, dict) and 'detail' in data:
        code = getattr(exc, 'default_code', 'erreur')
        if hasattr(exc, 'get_codes'):
            codes = exc.get_codes()
            if isinstance(codes, str):
                code = codes
        response.data = {'detail': str(data['detail']), 'code': code}
    elif isinstance(data, (dict, list)):
        champs = data if isinstance(data, dict) else {'non_field_errors': data}
        premier = next(iter(champs.values()), '')
        if isinstance(premier, list) and premier:
            premier = premier[0]
        response.data = {'detail': str(premier), 'code': 'invalide', 'champs': champs}
    if response.status_code == 429:
        response.data['detail'] = "Trop de requêtes. Patientez un instant avant de réessayer."
    return response
