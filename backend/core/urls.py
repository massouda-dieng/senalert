from django.urls import path
from rest_framework.routers import DefaultRouter

from . import views

router = DefaultRouter()
router.register('services', views.ServiceViewSet, basename='service')
router.register('categories', views.CategorieViewSet, basename='categorie')
router.register('parametres', views.ParametreViewSet, basename='parametre')
router.register('audit', views.JournalAuditViewSet, basename='audit')
router.register('fiches-secours', views.FicheSecoursViewSet, basename='fiche-secours')

urlpatterns = [
    path('configuration/', views.ConfigurationPubliqueView.as_view(), name='configuration'),
    path('services-proximite/', views.ServicesProximiteView.as_view(), name='services-proximite'),
    path('geocodage/', views.GeocodageView.as_view(), name='geocodage'),
    path('statistiques-publiques/', views.StatistiquesPubliquesView.as_view(), name='statistiques-publiques'),
] + router.urls
