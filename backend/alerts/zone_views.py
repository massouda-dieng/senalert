from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework import permissions, serializers, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from core.audit import journaliser
from core.constants import REGIONS
from core.permissions import est_superadmin
from notifications import service as notif

from .models import AlerteZone


class AlerteZoneSerializer(serializers.ModelSerializer):
    en_cours = serializers.BooleanField(read_only=True)
    regions_libelles = serializers.SerializerMethodField()

    class Meta:
        model = AlerteZone
        fields = ['id', 'titre', 'message', 'consignes', 'niveau', 'categorie', 'regions', 'regions_libelles',
                  'date_debut', 'date_fin', 'active', 'en_cours', 'date_creation']
        read_only_fields = ['id', 'date_creation']

    def get_regions_libelles(self, obj) -> list:
        return [REGIONS[r]['libelle'] for r in obj.regions if r in REGIONS] or ['Tout le Sénégal']

    def validate_regions(self, valeur):
        inconnues = [r for r in valeur if r not in REGIONS]
        if inconnues:
            raise serializers.ValidationError(f"Régions inconnues : {', '.join(inconnues)}.")
        return valeur

    def validate(self, attrs):
        debut = attrs.get('date_debut', getattr(self.instance, 'date_debut', None) or timezone.now())
        fin = attrs.get('date_fin', getattr(self.instance, 'date_fin', None))
        if fin and fin <= debut:
            raise serializers.ValidationError({'date_fin': 'La fin doit être postérieure au début.'})
        return attrs


class LecturePubliqueEcritureSuperAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.method in permissions.SAFE_METHODS or est_superadmin(request.user)


class AlerteZoneViewSet(viewsets.ModelViewSet):
    """
    Alertes de zone. Lecture publique des alertes en cours (information de sécurité),
    filtrable par `region` ; le superadministrateur voit tout et publie.
    """

    serializer_class = AlerteZoneSerializer
    permission_classes = [LecturePubliqueEcritureSuperAdmin]
    http_method_names = ['get', 'post', 'patch', 'head', 'options']

    def get_queryset(self):
        qs = AlerteZone.objects.all()
        if not est_superadmin(self.request.user) or self.request.query_params.get('en_cours') in ('1', 'true'):
            maintenant = timezone.now()
            qs = qs.filter(active=True, date_debut__lte=maintenant).filter(Q(date_fin__isnull=True) | Q(date_fin__gt=maintenant))
        region = self.request.query_params.get('region')
        if region:
            # JSONField « contains » n'existe pas sous SQLite : filtrage en Python.
            ids = [a.pk for a in qs if not a.regions or region in a.regions]
            qs = qs.filter(pk__in=ids)
        return qs

    def perform_create(self, serializer):
        with transaction.atomic():
            alerte = serializer.save(publie_par=self.request.user)
            journaliser(self.request, 'alerte_zone.publication', alerte, {'regions': alerte.regions, 'niveau': alerte.niveau})
            if alerte.en_cours:
                transaction.on_commit(lambda: notif.notifier_alerte_zone(alerte))

    def perform_update(self, serializer):
        alerte = serializer.save()
        journaliser(self.request, 'alerte_zone.modification', alerte, dict(self.request.data))

    @action(detail=True, methods=['post'])
    def terminer(self, request, pk=None):
        alerte = self.get_object()
        alerte.active = False
        alerte.date_fin = alerte.date_fin or timezone.now()
        alerte.save(update_fields=['active', 'date_fin'])
        journaliser(request, 'alerte_zone.fin', alerte)
        return Response(self.get_serializer(alerte).data)
