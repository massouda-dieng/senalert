from rest_framework import serializers

from core.constants import REGIONS
from incidents.serializers import DossierLectureMixin, PositionMixin

from .models import AlerteSOS


class AlerteSOSSerializer(DossierLectureMixin, serializers.ModelSerializer):
    est_sos = True

    class Meta:
        model = AlerteSOS
        fields = [
            'id', 'uuid', 'reference', 'message', 'latitude', 'longitude', 'precision_gps', 'source_position',
            'region', 'region_libelle', 'adresse', 'statut', 'statut_libelle', 'gravite', 'service', 'service_nom',
            'date_creation', 'date_modification', 'date_prise_en_charge', 'date_cloture', 'motif_cloture',
            'en_retard', 'intervention', 'citoyen_contact', 'est_proprietaire',
        ]


class AlerteSOSCreationSerializer(PositionMixin, serializers.ModelSerializer):
    latitude = serializers.FloatField(required=False, allow_null=True)
    longitude = serializers.FloatField(required=False, allow_null=True)
    precision_gps = serializers.FloatField(required=False, allow_null=True, min_value=0)
    region = serializers.CharField(required=False, allow_blank=True)
    message = serializers.CharField(required=False, allow_blank=True, max_length=280)
    adresse = serializers.CharField(required=False, allow_blank=True, max_length=255)
    client_request_id = serializers.UUIDField(required=False, allow_null=True)

    class Meta:
        model = AlerteSOS
        fields = ['latitude', 'longitude', 'precision_gps', 'region', 'message', 'adresse', 'client_request_id']

    def validate_region(self, value):
        if value and value not in REGIONS:
            raise serializers.ValidationError('Région inconnue.')
        return value

    def validate(self, attrs):
        # Un SOS n'est jamais refusé pour cause de position : sans GPS, il est
        # enregistré sans coordonnées (et jamais avec une position inventée).
        attrs = self.valider_position(attrs, obligatoire=False)
        attrs.pop('hors_senegal', None)
        attrs['source_position'] = 'gps' if attrs.get('latitude') is not None else 'indisponible'
        return attrs
