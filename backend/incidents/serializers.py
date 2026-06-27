from rest_framework import serializers
from .models import Incident

class IncidentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Incident
        fields = [
            'id', 'type_incident', 'description', 'photo',
            'latitude', 'longitude', 'region', 'statut',
            'citoyen', 'date_creation',
        ]
        read_only_fields = ['id', 'date_creation', 'citoyen']
