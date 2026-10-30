from django.contrib import admin

from .models import ZoneRisque


@admin.register(ZoneRisque)
class ZoneRisqueAdmin(admin.ModelAdmin):
    list_display = ['region', 'score', 'niveau', 'total_incidents', 'methode', 'date_calcul']
    list_filter = ['region', 'niveau', 'methode']
