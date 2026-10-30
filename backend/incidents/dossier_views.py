"""Actions communes aux dossiers (incidents et SOS), exposées en sous-routes POST."""

import django_filters
from django.db.models import Q
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response

from accounts.models import User
from core.audit import journaliser
from core.constants import GRAVITE_CHOICES, REGION_CHOICES, ROLE_AGENT, STATUT_CHOICES
from core.models import Service
from core.permissions import est_agent, est_superadmin

from . import workflow
from .serializers import (
    AffectationSerializer, ClotureSerializer, EvenementSerializer, GraviteSerializer, MotifSerializer,
    NoteSerializer,
)


class FiltreDossier(django_filters.FilterSet):
    statut = django_filters.MultipleChoiceFilter(choices=STATUT_CHOICES)
    region = django_filters.MultipleChoiceFilter(choices=REGION_CHOICES)
    gravite = django_filters.MultipleChoiceFilter(choices=GRAVITE_CHOICES)
    service = django_filters.NumberFilter(field_name='service_id')
    agent = django_filters.NumberFilter(field_name='intervention__agent_id')
    date_debut = django_filters.DateFilter(field_name='date_creation', lookup_expr='date__gte')
    date_fin = django_filters.DateFilter(field_name='date_creation', lookup_expr='date__lte')
    q = django_filters.CharFilter(method='recherche')
    affecte_a_moi = django_filters.BooleanFilter(method='filtre_moi')
    actifs = django_filters.BooleanFilter(method='filtre_actifs')

    def recherche(self, qs, name, value):
        return qs.filter(Q(reference__icontains=value) | Q(adresse__icontains=value) | self.recherche_texte(value))

    def recherche_texte(self, value):
        return Q()

    def filtre_moi(self, qs, name, value):
        return qs.filter(intervention__agent=self.request.user) if value else qs

    def filtre_actifs(self, qs, name, value):
        from core.constants import STATUTS_ACTIFS
        return qs.filter(statut__in=STATUTS_ACTIFS) if value else qs


class ActionsDossierMixin:
    """À combiner avec un GenericViewSet dont get_queryset applique la visibilité."""

    est_sos = False

    def queryset_visible(self, base):
        if getattr(self, 'swagger_fake_view', False):
            return base.none()
        return base.filter(workflow.filtre_visibilite(self.request.user, self.est_sos)).distinct()

    def _repondre(self, dossier):
        dossier = self.get_queryset().model.objects.get(pk=dossier.pk)
        return Response(self.get_serializer(dossier).data)

    def _exiger(self, condition, message):
        if not condition:
            raise PermissionDenied(message)

    @extend_schema(request=AffectationSerializer)
    @action(detail=True, methods=['post'])
    def affecter(self, request, pk=None):
        self._exiger(est_superadmin(request.user), "Seul le superadministrateur affecte les dossiers.")
        dossier = self.get_object()
        s = AffectationSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        agent = service = None
        if s.validated_data.get('agent'):
            agent = get_object_or_404(User.objects.select_related('profil_agent__service'),
                                      pk=s.validated_data['agent'], role=ROLE_AGENT)
        if s.validated_data.get('service'):
            service = get_object_or_404(Service, pk=s.validated_data['service'], actif=True)
        dossier = workflow.affecter(dossier, request.user, agent=agent, service=service,
                                    message=s.validated_data.get('message', ''))
        journaliser(request, 'dossier.affectation', dossier,
                    {'agent': agent.pk if agent else None, 'service': service.pk if service else None})
        return self._repondre(dossier)

    @action(detail=True, methods=['post'], url_path='prendre-en-charge')
    def prendre_en_charge(self, request, pk=None):
        self._exiger(est_agent(request.user), 'Action réservée aux agents.')
        return self._repondre(workflow.prendre_en_charge(self.get_object(), request.user))

    @action(detail=True, methods=['post'])
    def accepter(self, request, pk=None):
        self._exiger(est_agent(request.user), 'Action réservée aux agents.')
        return self._repondre(workflow.accepter(self.get_object(), request.user))

    @extend_schema(request=MotifSerializer)
    @action(detail=True, methods=['post'])
    def decliner(self, request, pk=None):
        self._exiger(est_agent(request.user), 'Action réservée aux agents.')
        return self._repondre(workflow.decliner(self.get_object(), request.user, request.data.get('motif', '').strip()))

    @action(detail=True, methods=['post'])
    def demarrer(self, request, pk=None):
        self._exiger(est_agent(request.user), 'Action réservée aux agents.')
        return self._repondre(workflow.demarrer(self.get_object(), request.user))

    @extend_schema(request=ClotureSerializer)
    @action(detail=True, methods=['post'])
    def resoudre(self, request, pk=None):
        self._exiger(est_agent(request.user), 'Action réservée aux agents.')
        s = ClotureSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        return self._repondre(workflow.resoudre(self.get_object(), request.user, **s.validated_data))

    @extend_schema(request=MotifSerializer)
    @action(detail=True, methods=['post'])
    def annuler(self, request, pk=None):
        dossier = workflow.annuler(self.get_object(), request.user, request.data.get('motif', '').strip())
        journaliser(request, 'dossier.annulation', dossier, {'motif': dossier.motif_cloture})
        return self._repondre(dossier)

    @extend_schema(request=MotifSerializer)
    @action(detail=True, methods=['post'])
    def rejeter(self, request, pk=None):
        self._exiger(est_superadmin(request.user), 'Action réservée au superadministrateur.')
        dossier = workflow.rejeter(self.get_object(), request.user, request.data.get('motif', '').strip())
        journaliser(request, 'dossier.rejet', dossier, {'motif': dossier.motif_cloture})
        return self._repondre(dossier)

    @extend_schema(request=GraviteSerializer)
    @action(detail=True, methods=['post'])
    def gravite(self, request, pk=None):
        dossier = self.get_object()
        inter = getattr(dossier, 'intervention', None)
        self._exiger(est_superadmin(request.user) or (inter and inter.agent_id == request.user.pk),
                     'Seuls le superadministrateur et l’agent affecté modifient la gravité.')
        s = GraviteSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        return self._repondre(workflow.changer_gravite(dossier, request.user, s.validated_data['gravite']))

    @extend_schema(request=NoteSerializer)
    @action(detail=True, methods=['post'])
    def note(self, request, pk=None):
        self._exiger(est_agent(request.user) or est_superadmin(request.user), 'Action réservée aux agents.')
        s = NoteSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        ev = workflow.ajouter_note(self.get_object(), request.user, **s.validated_data)
        return Response(EvenementSerializer(ev, context={'request': request}).data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['get'])
    def evenements(self, request, pk=None):
        dossier = self.get_object()
        evs = dossier.evenements.select_related('acteur')
        if not (est_agent(request.user) or est_superadmin(request.user)):
            evs = evs.filter(visible_citoyen=True)
        return Response(EvenementSerializer(evs, many=True, context={'request': request}).data)
