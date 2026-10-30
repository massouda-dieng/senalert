from django.contrib import admin
from django.urls import include, path, re_path
from django.views.generic import RedirectView
from drf_spectacular.views import SpectacularAPIView, SpectacularSwaggerView

from accounts.views import UtilisateurAdminViewSet
from dashboard.views import application_mobile, application_web
from rest_framework.routers import DefaultRouter

admin.site.site_header = 'SenAlert — administration technique'

router_admin = DefaultRouter()
router_admin.register('utilisateurs', UtilisateurAdminViewSet, basename='admin-utilisateur')

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/auth/', include('accounts.urls')),
    path('api/incidents/', include('incidents.urls')),
    path('api/alertes/', include('alerts.urls')),
    path('api/notifications/', include('notifications.urls')),
    path('api/analyse/', include('analyse.urls')),
    path('api/tableau-de-bord/', include('dashboard.urls')),
    path('api/gestion/', include(router_admin.urls)),
    path('api/', include('core.urls')),
    path('api/schema/', SpectacularAPIView.as_view(), name='schema'),
    path('api/docs/', SpectacularSwaggerView.as_view(url_name='schema'), name='docs'),
    path('', RedirectView.as_view(url='/app/', permanent=False)),
    re_path(r'^app(?:/(?P<chemin>.*))?$', application_web, name='application-web'),
    re_path(r'^mobile/(?P<chemin>.*)$', application_mobile, name='application-mobile'),
]
