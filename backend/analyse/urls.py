from django.urls import path
from .views import ZonesRisqueView, StatistiquesView

urlpatterns = [
    path('zones-risque/', ZonesRisqueView.as_view(), name='zones-risque'),
    path('statistiques/', StatistiquesView.as_view(), name='statistiques'),
]