from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import AgentProfil, CompteExterne, DemandeCompteAgent, DeviceToken, User


class AgentProfilInline(admin.StackedInline):
    model = AgentProfil
    can_delete = False
    extra = 0


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = ['username', 'email', 'role', 'region', 'is_active', 'last_login']
    list_filter = ['role', 'is_active', 'region']
    search_fields = ['username', 'email', 'first_name', 'last_name', 'telephone']
    inlines = [AgentProfilInline]
    fieldsets = UserAdmin.fieldsets + (
        ('SenAlert', {'fields': ('role', 'telephone', 'region', 'preferences', 'doit_changer_mot_de_passe')}),
    )


@admin.register(CompteExterne)
class CompteExterneAdmin(admin.ModelAdmin):
    list_display = ['user', 'fournisseur', 'email', 'date_liaison', 'derniere_connexion']
    readonly_fields = ['identifiant']


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
    list_display = ['user', 'plateforme', 'actif', 'derniere_utilisation']
    list_filter = ['plateforme', 'actif']


@admin.register(DemandeCompteAgent)
class DemandeCompteAgentAdmin(admin.ModelAdmin):
    list_display = ['prenom', 'nom', 'service', 'structure', 'statut', 'date_demande']
    list_filter = ['statut', 'service']
    exclude = ['mot_de_passe_hash']
