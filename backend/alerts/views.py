from django.db import IntegrityError, transaction
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle

from core.audit import journaliser
from core.constants import STATUTS_ACTIFS, TYPES_URGENCE
from core.structures import structure_competente
from incidents import workflow
from incidents.photos import enregistrer_photos, valider_photos
from incidents.dossier_views import ActionsDossierMixin, FiltreDossier

from .models import AlerteSOS
from .serializers import AlerteSOSCreationSerializer, AlerteSOSSerializer

FENETRE_ANTI_REPETITION = timezone.timedelta(minutes=2)


class FiltreSOS(FiltreDossier):
    class Meta:
        model = AlerteSOS
        fields = []


class AlerteSOSViewSet(ActionsDossierMixin, mixins.ListModelMixin, mixins.RetrieveModelMixin,
                       mixins.CreateModelMixin, viewsets.GenericViewSet):
    """
    Alertes SOS.

    La création répond 201 avec la référence du dossier, ou 200 si la même
    alerte a déjà été reçue (même clé d'idempotence ou SOS actif de moins de
    2 minutes) : le client affiche alors le dossier existant.
    """

    est_sos = True
    filterset_class = FiltreSOS
    ordering_fields = ['date_creation', 'statut', 'region']
    throttle_scope = 'sos'

    def get_throttles(self):
        return [ScopedRateThrottle()] if self.action == 'create' else super().get_throttles()

    def get_queryset(self):
        base = AlerteSOS.objects.select_related(
            'citoyen', 'service', 'structure', 'intervention__agent', 'intervention__service',
        ).prefetch_related('pieces_jointes')
        return self.queryset_visible(base)

    def get_serializer_class(self):
        return AlerteSOSCreationSerializer if self.action == 'create' else AlerteSOSSerializer

    def _existant(self, alerte, request):
        data = AlerteSOSSerializer(alerte, context={'request': request}).data
        return Response({**data, 'deja_enregistree': True}, status=status.HTTP_200_OK)

    @extend_schema(request=AlerteSOSCreationSerializer, responses=AlerteSOSSerializer)
    def create(self, request, *args, **kwargs):
        user = request.user
        s = AlerteSOSCreationSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        cle = s.validated_data.get('client_request_id')
        if cle:
            existant = AlerteSOS.objects.filter(citoyen=user, client_request_id=cle).first()
            if existant:
                return self._existant(existant, request)
        recent = AlerteSOS.objects.filter(
            citoyen=user, statut__in=STATUTS_ACTIFS, date_creation__gte=timezone.now() - FENETRE_ANTI_REPETITION,
        ).first()
        if recent:
            return self._existant(recent, request)

        donnees = s.validated_data
        if not donnees.get('region') and user.region:
            donnees['region'] = user.region
        photos = valider_photos(request.FILES.getlist('photos'))
        # Structure choisie par le citoyen, sinon la plus proche pour le type d'urgence (tous les services de
        # secours si non précisé). Le SOS part à son superviseur, prévenu immédiatement, qui affecte un agent.
        structure = donnees.pop('structure', None)
        if structure is None:
            services = TYPES_URGENCE[donnees.get('type_urgence') or 'non_precise']['services']
            structure = structure_competente(donnees.get('latitude'), donnees.get('longitude'),
                                             donnees.get('region'), services)
        try:
            with transaction.atomic():
                alerte = AlerteSOS.objects.create(citoyen=user, gravite='critique', structure=structure,
                                                  service=structure.service if structure else None, **donnees)
                enregistrer_photos(alerte, photos, user)
                workflow.apres_creation(alerte, user)
                journaliser(request, 'sos.envoi', alerte, {
                    'reference': alerte.reference, 'type_urgence': alerte.type_urgence,
                    'structure': structure.nom if structure else None, 'position': alerte.a_position,
                    'photos': len(photos)})
        except IntegrityError:
            existant = AlerteSOS.objects.filter(citoyen=user, client_request_id=cle).first()
            if existant is None:
                raise
            return self._existant(existant, request)
        alerte.refresh_from_db()
        data = AlerteSOSSerializer(alerte, context={'request': request}).data
        return Response({**data, 'deja_enregistree': False}, status=status.HTTP_201_CREATED)
