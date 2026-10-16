from rest_framework import serializers
from .models import AlerteSOS

class AlerteSOSSerializer(serializers.ModelResourceSerializer if hasattr(serializers, 'ModelResourceSerializer') else serializers.ModelSerializer):
    username = serializers.ReadOnlyField(source='user.username')

    class Meta:
        model = AlerteSOS
        fields = ['id', 'user', 'username', 'latitude', 'longitude', 'date_creation', 'statut']
        read_only_fields = ['id', 'user', 'username', 'date_creation', 'statut']
