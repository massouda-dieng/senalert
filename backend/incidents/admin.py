from django.contrib import admin
from .models import Incident

@admin.register(Incident)
class IncidentAdmin(admin.ModelAdmin):
    list_display = ['type_incident', 'region', 'statut', 'citoyen', 'date_creation']
    list_filter = ['type_incident', 'statut', 'region']
    search_fields = ['description', 'region']
