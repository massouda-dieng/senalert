from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User

@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = ['username', 'email', 'role', 'telephone', 'region', 'is_active']
    list_filter = ['role', 'is_active', 'region']
    fieldsets = UserAdmin.fieldsets + (
        ('Infos SenAlert', {
            'fields': ('role', 'telephone', 'region')
        }),
    )
