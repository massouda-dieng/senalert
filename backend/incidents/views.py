import django_filters
from django.db import IntegrityError, transaction
from django.db.models import Q
from django.http import FileResponse, Http404
from django.utils import timezone
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle

from core.constants import RESOLU, ROLE_AGENT, STATUTS_ACTIFS
from core.models import Categorie, Parametre
from core.permissions import est_citoyen, est_superadmin

from . import workflow
from .dossier_views import ActionsDossierMixin, FiltreDossier
from .models import Incident, PieceJointe
from .photos import enregistrer_photos, valider_photos
from .serializers import CarteIncidentSerializer, IncidentCreationSerializer, IncidentSerializer


class FiltreIncident(FiltreDossier):
    type_incident = django_filters.MultipleChoiceFilter(
        choices=lambda: [(c.code, c.libelle) for c in Categorie.objects.all()])
    doublons = django_filters.BooleanFilter(field_name='doublon_potentiel_de', lookup_expr='isnull', exclude=True)

    class Meta:
        model = Incident
        fields = []

    def recherche_texte(self, value):
        return Q(description__icontains=value)


class IncidentViewSet(ActionsDossierMixin, mixins.ListModelMixin, mixins.RetrieveModelMixin,
                      mixins.CreateModelMixin, viewsets.GenericViewSet):
    """
    Incidents signalés.

    * Citoyen : crée et consulte uniquement ses propres signalements.
    * Agent : voit les dossiers qui lui sont affectés et les nouveaux dossiers de son service dans ses zones.
    * Superadministrateur : voit et gère tout.
    """

    filterset_class = FiltreIncident
    ordering_fields = ['date_creation', 'gravite', 'statut', 'region']
    throttle_scope = 'signalement'

    def get_throttles(self):
        if self.action == 'create':
            return [ScopedRateThrottle()]
        return super().get_throttles()

    def get_queryset(self):
        base = Incident.objects.select_related(
            'service', 'citoyen', 'intervention__agent', 'intervention__service', 'doublon_potentiel_de',
        ).prefetch_related('pieces_jointes')
        return self.queryset_visible(base)

    def get_serializer_class(self):
        return IncidentCreationSerializer if self.action == 'create' else IncidentSerializer

    @extend_schema(request={'multipart/form-data': IncidentCreationSerializer, 'application/json': IncidentCreationSerializer},
                   responses=IncidentSerializer)
    def create(self, request, *args, **kwargs):
        user = request.user
        if not (est_citoyen(user) or est_superadmin(user)):
            raise PermissionDenied('Seuls les citoyens (et le superadministrateur) créent des signalements.')
        s = IncidentCreationSerializer(data=request.data, context={'request': request})
        s.is_valid(raise_exception=True)
        cle = s.validated_data.get('client_request_id')

        # Idempotence : un renvoi du même formulaire (double clic, reprise réseau) ne crée rien de plus.
        if cle:
            existant = Incident.objects.filter(citoyen=user, client_request_id=cle).first()
            if existant:
                return Response(IncidentSerializer(existant, context={'request': request}).data, status=status.HTTP_200_OK)

        photos = valider_photos(request.FILES.getlist('photos'))
        categorie = Categorie.objects.get(code=s.validated_data['type_incident'])
        try:
            with transaction.atomic():
                incident = s.save(citoyen=user, service=categorie.service_defaut, gravite=categorie.gravite_defaut)
                enregistrer_photos(incident, photos, user)
                workflow.apres_creation(incident, user)
        except IntegrityError:
            existant = Incident.objects.filter(citoyen=user, client_request_id=cle).first()
            if existant is None:
                raise
            return Response(IncidentSerializer(existant, context={'request': request}).data, status=status.HTTP_200_OK)
        incident = self.get_queryset().model.objects.get(pk=incident.pk)
        return Response(IncidentSerializer(incident, context={'request': request}).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'], url_path='completer')
    def completer(self, request, pk=None):
        """Le citoyen ajoute une information ou des photos à son dossier ouvert."""
        incident = self.get_object()
        message = (request.data.get('message') or '').strip()
        fichiers = request.FILES.getlist('photos')
        if fichiers:
            if incident.citoyen_id != request.user.pk:
                raise PermissionDenied('Ce dossier ne vous appartient pas.')
            photos = valider_photos(fichiers, deja=incident.pieces_jointes.count())
        with transaction.atomic():
            workflow.completer(incident, request.user, message or f'{len(fichiers)} photo(s) ajoutée(s).')
            if fichiers:
                enregistrer_photos(incident, photos, request.user)
        return self._repondre(incident)

    @action(detail=True, methods=['get'], url_path=r'photos/(?P<photo_id>\d+)')
    def photo(self, request, pk=None, photo_id=None):
        """Sert une photo après contrôle d'accès (les fichiers ne sont jamais publics)."""
        incident = self.get_object()
        pj = PieceJointe.objects.filter(incident=incident, pk=photo_id).first()
        if pj is None or not pj.fichier:
            raise Http404
        try:
            reponse = FileResponse(pj.fichier.open('rb'), content_type='image/jpeg')
        except FileNotFoundError:
            raise Http404
        reponse['Cache-Control'] = 'private, max-age=3600'
        return reponse

    @action(detail=False, methods=['get'])
    def carte(self, request):
        """Incidents récents pour la carte citoyenne : données minimales, position arrondie."""
        if not (Parametre.get('fonctionnalites') or {}).get('carte_publique', True) and not est_superadmin(request.user):
            return Response({'resultats': [], 'desactivee': True})
        jours = min(int(request.query_params.get('jours', 30) or 30), 90)
        qs = Incident.objects.filter(
            latitude__isnull=False,
            date_creation__gte=timezone.now() - timezone.timedelta(days=jours),
            statut__in=STATUTS_ACTIFS | {RESOLU},
        )
        types = request.query_params.getlist('type_incident')
        if types:
            qs = qs.filter(type_incident__in=types)
        if request.query_params.get('region'):
            qs = qs.filter(region=request.query_params['region'])
        qs = qs.order_by('-date_creation')[:500]
        return Response({
            'resultats': CarteIncidentSerializer(qs, many=True).data,
            'periode_jours': jours,
            'genere_le': timezone.now(),
            'note': 'Positions arrondies à environ 100 m pour protéger la vie privée.',
        })

    @action(detail=False, methods=['get'])
    def resume(self, request):
        """Compteurs pour l'accueil de l'utilisateur courant (selon sa visibilité)."""
        qs = self.get_queryset()
        data = {s: qs.filter(statut=s).count() for s in ('nouveau', 'affecte', 'accepte', 'en_cours', 'resolu')}
        if request.user.role == ROLE_AGENT:
            data['mes_actifs'] = qs.filter(intervention__agent=request.user, statut__in=STATUTS_ACTIFS).count()
        data['total'] = qs.count()
        return Response(data)
