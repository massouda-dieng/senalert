from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User, Autorite

@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = ['username', 'email', 'role', 'telephone', 'region', 'is_active']
    list_filter = ['role', 'is_active', 'region']
    fieldsets = UserAdmin.fieldsets + (
        ('Infos SenAlert', {
            'fields': ('role', 'telephone', 'region')
        }),
    )

@admin.register(Autorite)
class AutoriteAdmin(admin.ModelAdmin):
    list_display = ['nom_service', 'type_autorite', 'region', 'user']
    list_filter = ['type_autorite', 'region']
