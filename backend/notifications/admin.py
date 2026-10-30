from django.contrib import admin

from .models import Notification


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['destinataire', 'type', 'titre', 'statut_push', 'lue', 'date_creation']
    list_filter = ['type', 'statut_push', 'lue']
