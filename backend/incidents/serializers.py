from django.utils import timezone
from rest_framework import serializers

from core.constants import AFFECTE, GRAVITE_CHOICES, NOUVEAU, REGIONS, ROLE_SUPERADMIN
from core.geo import dans_senegal, region_la_plus_proche
from core.models import Categorie, Parametre

from .models import EvenementDossier, Incident, Intervention, PieceJointe


def delai_retard_minutes(est_sos):
    delais = Parametre.get('delais_prise_en_charge_minutes') or {}
    return delais.get('sos' if est_sos else 'incident', 10 if est_sos else 60)


class InterventionSerializer(serializers.ModelSerializer):
    agent_nom = serializers.CharField(source='agent.nom_affiche', default=None, read_only=True)
    service_nom = serializers.CharField(source='service.nom', default=None, read_only=True)

    class Meta:
        model = Intervention
        fields = ['agent', 'agent_nom', 'service', 'service_nom', 'date_affectation', 'date_acceptation',
                  'date_debut', 'date_fin', 'compte_rendu', 'difficultes']


class EvenementSerializer(serializers.ModelSerializer):
    acteur_nom = serializers.SerializerMethodField()

    class Meta:
        model = EvenementDossier
        fields = ['id', 'type', 'statut_avant', 'statut_apres', 'acteur_nom', 'message', 'visible_citoyen', 'date']

    def get_acteur_nom(self, obj) -> str:
        if obj.acteur is None:
            return 'SenAlert'
        user = self.context['request'].user
        # Le citoyen voit le rôle de l'intervenant, pas son identité.
        if user.role not in ('agent', 'superadmin') and obj.acteur_id != user.pk:
            return obj.acteur.get_role_display()
        return obj.acteur.nom_affiche


class PieceJointeSerializer(serializers.ModelSerializer):
    url = serializers.SerializerMethodField()

    class Meta:
        model = PieceJointe
        fields = ['id', 'taille', 'largeur', 'hauteur', 'date_ajout', 'url']

    def get_url(self, obj) -> str:
        return f'/api/incidents/{obj.incident_id}/photos/{obj.pk}/'


class DossierLectureMixin(serializers.Serializer):
    """Champs calculés communs aux incidents et SOS."""

    region_libelle = serializers.CharField(source='get_region_display', read_only=True)
    statut_libelle = serializers.CharField(source='get_statut_display', read_only=True)
    service_nom = serializers.CharField(source='service.nom', default=None, read_only=True)
    en_retard = serializers.SerializerMethodField()
    intervention = serializers.SerializerMethodField()
    citoyen_contact = serializers.SerializerMethodField()
    est_proprietaire = serializers.SerializerMethodField()

    def get_en_retard(self, obj) -> bool:
        if obj.statut not in (NOUVEAU, AFFECTE):
            return False
        limite = delai_retard_minutes(self.est_sos)
        return (timezone.now() - obj.date_creation).total_seconds() > limite * 60

    def get_intervention(self, obj) -> dict | None:
        inter = getattr(obj, 'intervention', None)
        if inter is None:
            return None
        data = InterventionSerializer(inter).data
        user = self.context['request'].user
        if user.role not in ('agent', 'superadmin'):
            # Minimisation : le citoyen voit le service, pas l'identité de l'agent.
            data.pop('agent', None)
            data['agent_nom'] = 'Agent de secours' if inter.agent_id else None
            data.pop('difficultes', None)
        return data

    def get_citoyen_contact(self, obj) -> dict | None:
        """Coordonnées du déclarant, visibles seulement par l'agent affecté et le superadmin."""
        user = self.context['request'].user
        inter = getattr(obj, 'intervention', None)
        autorise = user.role == ROLE_SUPERADMIN or (inter is not None and inter.agent_id == user.pk)
        if not autorise or obj.citoyen is None:
            return None
        return {'nom': obj.citoyen.nom_affiche, 'telephone': obj.citoyen.telephone}

    def get_est_proprietaire(self, obj) -> bool:
        return obj.citoyen_id == self.context['request'].user.pk


class IncidentSerializer(DossierLectureMixin, serializers.ModelSerializer):
    est_sos = False
    categorie_libelle = serializers.SerializerMethodField()
    photos = PieceJointeSerializer(source='pieces_jointes', many=True, read_only=True)
    doublon_potentiel_reference = serializers.CharField(source='doublon_potentiel_de.reference', default=None, read_only=True)
    nb_confirmations = serializers.SerializerMethodField()

    class Meta:
        model = Incident
        fields = [
            'id', 'uuid', 'reference', 'type_incident', 'categorie_libelle', 'description', 'infos_complementaires',
            'latitude', 'longitude', 'precision_gps', 'region', 'region_libelle', 'adresse', 'date_incident',
            'statut', 'statut_libelle', 'gravite', 'service', 'service_nom', 'date_creation', 'date_modification',
            'date_prise_en_charge', 'date_cloture', 'motif_cloture', 'en_retard', 'intervention', 'photos',
            'citoyen_contact', 'est_proprietaire', 'doublon_potentiel_de', 'doublon_potentiel_reference',
            'nb_confirmations',
        ]

    def get_nb_confirmations(self, obj) -> int:
        return obj.confirmations.count()

    def get_categorie_libelle(self, obj) -> str:
        cats = self.context.setdefault('_categories', {c.code: c.libelle for c in Categorie.objects.all()})
        return cats.get(obj.type_incident, obj.type_incident)

    def to_representation(self, obj):
        data = super().to_representation(obj)
        if self.context['request'].user.role != ROLE_SUPERADMIN:
            data.pop('doublon_potentiel_de', None)
            data.pop('doublon_potentiel_reference', None)
        return data


class PositionMixin(serializers.Serializer):
    def valider_position(self, attrs, obligatoire):
        lat, lng = attrs.get('latitude'), attrs.get('longitude')
        if (lat is None) != (lng is None):
            raise serializers.ValidationError({'latitude': 'Latitude et longitude vont ensemble.'})
        if lat is None:
            if obligatoire:
                raise serializers.ValidationError({'latitude': 'Indiquez la position (GPS ou sur la carte).'})
            return attrs
        if not (-90 <= lat <= 90 and -180 <= lng <= 180):
            raise serializers.ValidationError({'latitude': 'Coordonnées invalides.'})
        attrs['hors_senegal'] = not dans_senegal(lat, lng)
        if not attrs.get('region') and not attrs['hors_senegal']:
            attrs['region'] = region_la_plus_proche(lat, lng)
        return attrs


class IncidentCreationSerializer(PositionMixin, serializers.ModelSerializer):
    latitude = serializers.FloatField(required=False, allow_null=True)
    longitude = serializers.FloatField(required=False, allow_null=True)
    precision_gps = serializers.FloatField(required=False, allow_null=True, min_value=0)
    description = serializers.CharField(required=False, allow_blank=True, max_length=2000)
    adresse = serializers.CharField(required=False, allow_blank=True, max_length=255)
    infos_complementaires = serializers.CharField(required=False, allow_blank=True, max_length=1000)
    client_request_id = serializers.UUIDField(required=False, allow_null=True)

    class Meta:
        model = Incident
        fields = ['type_incident', 'description', 'latitude', 'longitude', 'precision_gps', 'region', 'adresse',
                  'date_incident', 'infos_complementaires', 'client_request_id']

    def validate_type_incident(self, value):
        if not Categorie.objects.filter(code=value, actif=True).exists():
            raise serializers.ValidationError('Catégorie inconnue ou désactivée.')
        return value

    def validate_region(self, value):
        if value and value not in REGIONS:
            raise serializers.ValidationError('Région inconnue.')
        return value

    def validate_date_incident(self, value):
        if value and value > timezone.now() + timezone.timedelta(minutes=5):
            raise serializers.ValidationError("La date de l'incident ne peut pas être dans le futur.")
        if value and value < timezone.now() - timezone.timedelta(days=30):
            raise serializers.ValidationError('Signalez uniquement des incidents des 30 derniers jours.')
        return value

    def validate(self, attrs):
        attrs = self.valider_position(attrs, obligatoire=True)
        if attrs.pop('hors_senegal', False):
            raise serializers.ValidationError({'latitude': 'La position indiquée est hors du Sénégal.'})
        if attrs['type_incident'] == 'autre' and len((attrs.get('description') or '').strip()) < 10:
            raise serializers.ValidationError({'description': 'Décrivez l’incident (10 caractères minimum).'})
        return attrs


class CarteIncidentSerializer(serializers.ModelSerializer):
    """Vue publique minimale : pas de description, pas de photo, position arrondie (~100 m)."""

    latitude = serializers.SerializerMethodField()
    longitude = serializers.SerializerMethodField()

    class Meta:
        model = Incident
        fields = ['id', 'type_incident', 'latitude', 'longitude', 'region', 'statut', 'gravite', 'date_creation']

    def get_latitude(self, obj) -> float:
        return round(obj.latitude, 3)

    def get_longitude(self, obj) -> float:
        return round(obj.longitude, 3)


class AffectationSerializer(serializers.Serializer):
    agent = serializers.IntegerField(required=False, allow_null=True)
    service = serializers.IntegerField(required=False, allow_null=True)
    message = serializers.CharField(required=False, allow_blank=True, max_length=500)


class MotifSerializer(serializers.Serializer):
    motif = serializers.CharField(max_length=255)


class ClotureSerializer(serializers.Serializer):
    compte_rendu = serializers.CharField(max_length=4000)
    difficultes = serializers.CharField(required=False, allow_blank=True, max_length=2000)


class GraviteSerializer(serializers.Serializer):
    gravite = serializers.ChoiceField(choices=GRAVITE_CHOICES)


class NoteSerializer(serializers.Serializer):
    message = serializers.CharField(max_length=2000)
    visible_citoyen = serializers.BooleanField(default=False)
