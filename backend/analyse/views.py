from datetime import datetime, time

from django.utils import timezone
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import serializers, status
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from core.audit import journaliser
from core.constants import ANNULE, REFUSE, REGIONS
from core.models import Parametre
from core.permissions import EstAgentOuSuperAdmin, EstSuperAdmin
from core.throttles import ThrottleAssistantJour
from incidents.models import Incident

from . import assistant
from .analyzer import (
    FACTEUR_RECENT, MIN_INCIDENTS_FIABLE, METHODE, POIDS_GRAVITE, POIDS_PAR_DEFAUT, SEUIL_CRITIQUE, SEUIL_ELEVE,
    SEUIL_MOYEN, analyser_zones_risque,
)
from .models import ZoneRisque


def _date(valeur, nom):
    if not valeur:
        return None
    try:
        return datetime.strptime(valeur, '%Y-%m-%d').date()
    except ValueError:
        raise ValidationError({nom: 'Format attendu : AAAA-MM-JJ.'})


def incidents_retenus(debut=None, fin=None, types=None):
    """Incidents pris en compte : les signalements rejetés ou annulés sont exclus."""
    qs = Incident.objects.exclude(statut__in=[REFUSE, ANNULE]).exclude(region='').only(
        'type_incident', 'region', 'date_creation')
    if debut:
        qs = qs.filter(date_creation__date__gte=debut)
    if fin:
        qs = qs.filter(date_creation__date__lte=fin)
    if types:
        qs = qs.filter(type_incident__in=types)
    return qs


def calculer(debut=None, fin=None, types=None):
    reference = timezone.make_aware(datetime.combine(fin, time.max)) if fin else timezone.now()
    reference = min(reference, timezone.now())
    resultats = {r['region']: r for r in analyser_zones_risque(incidents_retenus(debut, fin, types), reference)}
    zones = []
    for code, info in REGIONS.items():
        r = resultats.get(code) or {
            'region': code, 'score': 0.0, 'niveau': 'faible', 'total_incidents': 0, 'types_predominants': [],
            'repartition_types': {}, 'incidents_recents': 0, 'donnees_insuffisantes': True,
        }
        zones.append({**r, 'region_libelle': info['libelle'], 'latitude': info['lat'], 'longitude': info['lng']})
    zones.sort(key=lambda z: z['score'], reverse=True)
    return zones, reference


class ZonesRisqueView(APIView):
    """Score de risque par région (méthode de référence du mémoire).

    Paramètres : date_debut, date_fin (période des incidents retenus ; la date de
    fin sert de référence pour le facteur temporel), type_incident (multiple),
    niveau, region, comparer=1 (ajoute la période précédente de même durée).
    """

    permission_classes = [EstAgentOuSuperAdmin]

    @extend_schema(responses=OpenApiTypes.OBJECT, parameters=[OpenApiParameter('date_debut', str), OpenApiParameter('date_fin', str),
                                                             OpenApiParameter('comparer', bool)])
    def get(self, request):
        debut = _date(request.query_params.get('date_debut'), 'date_debut')
        fin = _date(request.query_params.get('date_fin'), 'date_fin')
        if debut and fin and debut > fin:
            raise ValidationError({'date_debut': 'La date de début doit précéder la date de fin.'})
        types = request.query_params.getlist('type_incident') or None
        zones, reference = calculer(debut, fin, types)

        if request.query_params.get('comparer') in ('1', 'true') and debut and fin:
            duree = fin - debut
            p_fin = debut - timezone.timedelta(days=1)
            precedentes, _ = calculer(p_fin - duree, p_fin, types)
            prec = {z['region']: z for z in precedentes}
            for z in zones:
                z['score_precedent'] = prec[z['region']]['score']
                z['niveau_precedent'] = prec[z['region']]['niveau']
                z['evolution'] = round(z['score'] - prec[z['region']]['score'], 2)

        if request.query_params.get('niveau'):
            zones = [z for z in zones if z['niveau'] == request.query_params['niveau']]
        if request.query_params.get('region'):
            zones = [z for z in zones if z['region'] == request.query_params['region']]

        dernier = ZoneRisque.objects.order_by('-date_calcul').values_list('date_calcul', flat=True).first()
        return Response({
            'methode': METHODE,
            'date_calcul': timezone.now(),
            'date_reference': reference,
            'dernier_instantane': dernier,
            'periode': {'debut': debut, 'fin': fin},
            'nb_incidents_utilises': sum(z['total_incidents'] for z in zones),
            'total_zones_analysees': len(zones),
            'zones': zones,
            'formule': {
                'poids': POIDS_GRAVITE, 'poids_par_defaut': POIDS_PAR_DEFAUT,
                'facteur_recent': FACTEUR_RECENT, 'fenetre_recente_jours': 7,
                'seuils': {'critique': SEUIL_CRITIQUE, 'eleve': SEUIL_ELEVE, 'moyen': SEUIL_MOYEN},
                'min_incidents_fiable': MIN_INCIDENTS_FIABLE,
                'exclusions': 'Signalements rejetés ou annulés exclus.',
            },
            'avertissement': ("Indicateur descriptif fondé sur les signalements reçus, pas un modèle prédictif. "
                              "Peu de signalements ne signifie pas qu'une zone est sûre."),
        })


class InstantaneView(APIView):
    """GET : historique des scores ; POST (superadmin) : enregistre un instantané reproductible."""

    permission_classes = [EstAgentOuSuperAdmin]

    @extend_schema(responses=OpenApiTypes.OBJECT)
    def get(self, request):
        qs = ZoneRisque.objects.all()
        if request.query_params.get('region'):
            qs = qs.filter(region=request.query_params['region'])
        qs = qs[:500]
        return Response([{
            'region': z.region, 'score': z.score, 'niveau': z.niveau, 'total_incidents': z.total_incidents,
            'incidents_recents': z.incidents_recents, 'methode': z.methode, 'date_calcul': z.date_calcul,
        } for z in qs])

    @extend_schema(request=None, responses=OpenApiTypes.OBJECT)
    def post(self, request):
        if not EstSuperAdmin().has_permission(request, self):
            raise PermissionDenied('Action réservée au superadministrateur.')
        zones, reference = calculer()
        maintenant = timezone.now()
        ZoneRisque.objects.bulk_create([ZoneRisque(
            region=z['region'], score=z['score'], niveau=z['niveau'], total_incidents=z['total_incidents'],
            incidents_recents=z['incidents_recents'], types_predominants=z['types_predominants'],
            methode=METHODE, date_calcul=maintenant,
        ) for z in zones])
        journaliser(request, 'analyse.instantane_scores', details={'zones': len(zones)})
        return Response({'date_calcul': maintenant, 'zones': len(zones)}, status=status.HTTP_201_CREATED)


class AssistantSerializer(serializers.Serializer):
    message = serializers.CharField(max_length=assistant.LONGUEUR_MAX)
    historique = serializers.ListField(child=serializers.DictField(), required=False, max_length=20)


class AssistantView(APIView):
    """Assistant IA (Groq côté serveur) avec repli local. N'est jamais requis pour un SOS."""

    serializer_class = AssistantSerializer
    throttle_scope = 'assistant'

    def get_throttles(self):
        return [ScopedRateThrottle(), ThrottleAssistantJour()]

    @extend_schema(request=AssistantSerializer)
    def post(self, request):
        if not (Parametre.get('fonctionnalites') or {}).get('assistant_ia', True):
            raise PermissionDenied("L'assistant est désactivé par l'administrateur.")
        s = AssistantSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        return Response(assistant.repondre(s.validated_data['message'], s.validated_data.get('historique')))
