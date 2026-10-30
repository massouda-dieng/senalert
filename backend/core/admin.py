from django.contrib import admin

from .models import Categorie, FicheSecours, JournalAudit, Parametre, Service


@admin.register(Service)
class ServiceAdmin(admin.ModelAdmin):
    list_display = ['nom', 'code', 'actif']


@admin.register(Categorie)
class CategorieAdmin(admin.ModelAdmin):
    list_display = ['libelle', 'code', 'service_defaut', 'gravite_defaut', 'actif', 'ordre']
    list_editable = ['ordre', 'actif']


@admin.register(Parametre)
class ParametreAdmin(admin.ModelAdmin):
    list_display = ['cle', 'description', 'modifie_par', 'date_modification']


@admin.register(FicheSecours)
class FicheSecoursAdmin(admin.ModelAdmin):
    list_display = ['titre', 'categorie', 'valide_par', 'date_mise_a_jour', 'publie']


@admin.register(JournalAudit)
class JournalAuditAdmin(admin.ModelAdmin):
    list_display = ['date', 'acteur', 'action', 'cible_type', 'cible_id', 'adresse_ip']
    list_filter = ['action']

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
