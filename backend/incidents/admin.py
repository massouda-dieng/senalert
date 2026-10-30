from django.contrib import admin

from .models import EvenementDossier, Incident, Intervention, PieceJointe


class PieceJointeInline(admin.TabularInline):
    model = PieceJointe
    extra = 0
    readonly_fields = ['fichier', 'taille', 'auteur', 'date_ajout']


class EvenementInline(admin.TabularInline):
    model = EvenementDossier
    extra = 0
    readonly_fields = ['type', 'statut_avant', 'statut_apres', 'acteur', 'message', 'visible_citoyen', 'date']


@admin.register(Incident)
class IncidentAdmin(admin.ModelAdmin):
    list_display = ['reference', 'type_incident', 'region', 'statut', 'gravite', 'citoyen', 'date_creation']
    list_filter = ['type_incident', 'statut', 'gravite', 'region']
    search_fields = ['reference', 'description', 'adresse']
    readonly_fields = ['uuid', 'reference', 'client_request_id']
    inlines = [PieceJointeInline, EvenementInline]


@admin.register(Intervention)
class InterventionAdmin(admin.ModelAdmin):
    list_display = ['__str__', 'service', 'agent', 'date_affectation', 'date_fin']
    list_filter = ['service']
