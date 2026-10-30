"""Fil communautaire : les citoyens voient les incidents récents autour d'eux,
confirment ceux qu'ils constatent et échangent des informations utiles.

Confidentialité : ni description, ni photo, ni identité du déclarant ; positions
arrondies (~100 m) ; les commentaires sont publics (l'utilisateur en est averti)
et modérables par le superadministrateur.
"""

from django.db import IntegrityError
from django.db.models import Count, Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import mixins, serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle

from core.audit import journaliser
from core.constants import ANNULE, REFUSE, REGIONS
from core.geo import boite_englobante, distance_m
from core.models import Categorie
from core.permissions import EstSuperAdmin, est_citoyen, est_superadmin

from .models import Commentaire, Confirmation, Incident


class CommentaireSerializer(serializers.ModelSerializer):
    auteur_nom = serializers.SerializerMethodField()
    est_mien = serializers.SerializerMethodField()

    class Meta:
        model = Commentaire
        fields = ['id', 'texte', 'auteur_nom', 'est_mien', 'masque', 'date']

    def get_auteur_nom(self, obj) -> str:
        a = obj.auteur
        if a is None:
            return 'Compte supprimé'
        if a.role != 'citoyen':
            return f'{a.get_role_display()} SenAlert'
        # Prénom + initiale seulement : jamais l'identité complète.
        return f"{a.first_name or 'Citoyen'} {a.last_name[:1] + '.' if a.last_name else ''}".strip()

    def get_est_mien(self, obj) -> bool:
        return obj.auteur_id == self.context['request'].user.pk


class FilSerializer(serializers.ModelSerializer):
    categorie_libelle = serializers.SerializerMethodField()
    region_libelle = serializers.CharField(source='get_region_display')
    latitude = serializers.SerializerMethodField()
    longitude = serializers.SerializerMethodField()
    nb_confirmations = serializers.IntegerField()
    nb_commentaires = serializers.IntegerField()
    je_confirme = serializers.BooleanField()
    est_mien = serializers.SerializerMethodField()
    distance_m = serializers.SerializerMethodField()

    class Meta:
        model = Incident
        fields = ['id', 'type_incident', 'categorie_libelle', 'region', 'region_libelle', 'statut', 'gravite',
                  'date_creation', 'latitude', 'longitude', 'distance_m', 'nb_confirmations', 'nb_commentaires',
                  'je_confirme', 'est_mien']

    def get_categorie_libelle(self, obj) -> str:
        cats = self.context.setdefault('_cats', {c.code: c.libelle for c in Categorie.objects.all()})
        return cats.get(obj.type_incident, obj.type_incident)

    def get_latitude(self, obj) -> float:
        return round(obj.latitude, 3)

    def get_longitude(self, obj) -> float:
        return round(obj.longitude, 3)

    def get_est_mien(self, obj) -> bool:
        return obj.citoyen_id == self.context['request'].user.pk

    def get_distance_m(self, obj) -> int | None:
        return getattr(obj, '_distance', None)


class CommunauteViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """GET ?lat=&lng=&rayon_km=&jours=&type_incident= : incidents récents (tri par distance si position fournie)."""

    serializer_class = FilSerializer

    def get_throttles(self):
        if self.action == 'commentaires' and self.request.method == 'POST':
            self.throttle_scope = 'signalement'
            return [ScopedRateThrottle()]
        return super().get_throttles()

    def base(self):
        jours = min(int(self.request.query_params.get('jours', 7) or 7), 30)
        return (Incident.objects
                .filter(latitude__isnull=False, date_creation__gte=timezone.now() - timezone.timedelta(days=jours))
                .exclude(statut__in=[REFUSE, ANNULE]))

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return Incident.objects.none()
        user = self.request.user
        qs = self.base().annotate(
            nb_confirmations=Count('confirmations', distinct=True),
            nb_commentaires=Count('commentaires', filter=Q(commentaires__masque=False), distinct=True),
            je_confirme=Count('confirmations', filter=Q(confirmations__citoyen=user), distinct=True),
        )
        p = self.request.query_params
        if p.get('type_incident'):
            qs = qs.filter(type_incident=p['type_incident'])
        if p.get('region') in REGIONS:
            qs = qs.filter(region=p['region'])
        return qs.order_by('-date_creation')

    def list(self, request, *args, **kwargs):
        qs = self.get_queryset()
        p = request.query_params
        try:
            lat, lng = float(p['lat']), float(p['lng'])
        except (KeyError, ValueError):
            lat = lng = None
        if lat is not None:
            rayon = max(1, min(float(p.get('rayon_km', 10) or 10), 100)) * 1000
            a, b, c, d = boite_englobante(lat, lng, rayon)
            elements = []
            for inc in qs.filter(latitude__range=(a, b), longitude__range=(c, d)):
                inc._distance = round(distance_m(lat, lng, inc.latitude, inc.longitude))
                if inc._distance <= rayon:
                    elements.append(inc)
            elements.sort(key=lambda i: i._distance)
        else:
            elements = list(qs[:200])
        page = self.paginate_queryset(elements)
        return self.get_paginated_response(self.get_serializer(page, many=True).data)

    def _incident(self, pk):
        return get_object_or_404(self.base(), pk=pk)

    @action(detail=True, methods=['post', 'delete'])
    def confirmer(self, request, pk=None):
        """« Je le vois aussi ». Réservé aux citoyens, pas sur son propre signalement."""
        if not est_citoyen(request.user):
            raise PermissionDenied('Seuls les citoyens confirment un incident.')
        incident = self._incident(pk)
        if incident.citoyen_id == request.user.pk:
            raise ValidationError({'detail': 'Vous ne pouvez pas confirmer votre propre signalement.'})
        if request.method == 'DELETE':
            Confirmation.objects.filter(incident=incident, citoyen=request.user).delete()
        else:
            try:
                Confirmation.objects.get_or_create(incident=incident, citoyen=request.user)
            except IntegrityError:
                pass
        return Response({'nb_confirmations': incident.confirmations.count(),
                         'je_confirme': request.method != 'DELETE'})

    @action(detail=True, methods=['get', 'post'])
    def commentaires(self, request, pk=None):
        incident = self._incident(pk)
        if request.method == 'POST':
            texte = (request.data.get('texte') or '').strip()
            if len(texte) < 3:
                raise ValidationError({'texte': 'Message trop court.'})
            if len(texte) > 500:
                raise ValidationError({'texte': '500 caractères maximum.'})
            c = Commentaire.objects.create(incident=incident, auteur=request.user, texte=texte)
            return Response(CommentaireSerializer(c, context={'request': request}).data, status=status.HTTP_201_CREATED)
        qs = incident.commentaires.select_related('auteur')
        if not est_superadmin(request.user):
            qs = qs.filter(masque=False)
        return Response(CommentaireSerializer(qs, many=True, context={'request': request}).data)

    @action(detail=False, methods=['post'], url_path=r'commentaires/(?P<commentaire_id>\d+)/masquer',
            permission_classes=[EstSuperAdmin])
    def masquer(self, request, commentaire_id=None):
        c = get_object_or_404(Commentaire, pk=commentaire_id)
        c.masque = request.data.get('masque', True) not in (False, 'false', '0')
        c.masque_par = request.user
        c.save(update_fields=['masque', 'masque_par'])
        journaliser(request, 'communaute.moderation', c, {'masque': c.masque, 'incident': c.incident_id})
        return Response(CommentaireSerializer(c, context={'request': request}).data)
