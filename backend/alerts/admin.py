from django.contrib import admin

from .models import AlerteSOS, AlerteZone


@admin.register(AlerteSOS)
class AlerteSOSAdmin(admin.ModelAdmin):
    list_display = ['reference', 'citoyen', 'region', 'statut', 'date_creation']
    list_filter = ['statut', 'region']
    search_fields = ['reference']
    readonly_fields = ['uuid', 'reference', 'client_request_id']


@admin.register(AlerteZone)
class AlerteZoneAdmin(admin.ModelAdmin):
    list_display = ['titre', 'niveau', 'active', 'date_debut', 'date_fin']
    list_filter = ['niveau', 'active']
