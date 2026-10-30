from django.contrib import admin

from .models import AlerteSOS


@admin.register(AlerteSOS)
class AlerteSOSAdmin(admin.ModelAdmin):
    list_display = ['reference', 'citoyen', 'region', 'statut', 'date_creation']
    list_filter = ['statut', 'region']
    search_fields = ['reference']
    readonly_fields = ['uuid', 'reference', 'client_request_id']
