from django.contrib import admin
from .models import AlerteSOS

@admin.register(AlerteSOS)
class AlerteSOSAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'latitude', 'longitude', 'statut', 'date_creation')
    list_filter = ('statut', 'date_creation')
    search_fields = ('user__username', 'user__email')
    ordering = ('-date_creation',)
