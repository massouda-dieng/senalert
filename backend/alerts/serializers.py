from rest_framework import serializers

from core.constants import REGIONS, TYPES_URGENCE
from core.models import Structure
from incidents.serializers import DossierLectureMixin, PieceJointeSerializer, PositionMixin

from .models import AlerteSOS


class AlerteSOSSerializer(DossierLectureMixin, serializers.ModelSerializer):
    est_sos = True
    type_urgence_libelle = serializers.CharField(source='get_type_urgence_display', read_only=True)
    photos = PieceJointeSerializer(source='pieces_jointes', many=True, read_only=True)

    class Meta:
        model = AlerteSOS
        fields = [
            'id', 'uuid', 'reference', 'type_urgence', 'type_urgence_libelle', 'message', 'latitude', 'longitude', 'precision_gps', 'source_position',
            'region', 'region_libelle', 'adresse', 'statut', 'statut_libelle', 'gravite', 'service', 'service_nom',
            'structure', 'structure_nom', 'date_creation', 'date_modification', 'date_prise_en_charge', 'date_cloture', 'motif_cloture',
            'en_retard', 'intervention', 'citoyen_contact', 'est_proprietaire', 'photos',
        ]


class AlerteSOSCreationSerializer(PositionMixin, serializers.ModelSerializer):
    latitude = serializers.FloatField(required=False, allow_null=True)
    longitude = serializers.FloatField(required=False, allow_null=True)
    precision_gps = serializers.FloatField(required=False, allow_null=True, min_value=0)
    region = serializers.CharField(required=False, allow_blank=True)
    message = serializers.CharField(required=False, allow_blank=True, max_length=280)
    adresse = serializers.CharField(required=False, allow_blank=True, max_length=255)
    client_request_id = serializers.UUIDField(required=False, allow_null=True)
    type_urgence = serializers.ChoiceField(choices=list(TYPES_URGENCE), required=False, default='non_precise')
    # Structure de secours choisie (facultatif) : sinon la plus proche pour le type d'urgence.
    structure = serializers.PrimaryKeyRelatedField(queryset=Structure.objects.filter(actif=True).select_related('service'),
                                                   required=False, allow_null=True)

    class Meta:
        model = AlerteSOS
        fields = ['type_urgence', 'latitude', 'longitude', 'precision_gps', 'region', 'message', 'adresse',
                  'client_request_id', 'structure']

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
        structure = attrs.get('structure')
        services = TYPES_URGENCE[attrs.get('type_urgence') or 'non_precise']['services']
        if structure is not None and structure.service.code not in services:
            raise serializers.ValidationError({'structure': "Cette structure ne traite pas ce type d'urgence."})
        return attrs
