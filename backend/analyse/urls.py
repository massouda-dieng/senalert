from django.urls import path
from .views import ZonesRisqueView

urlpatterns = [
    path('zones-risque/', ZonesRisqueView.as_view(), name='zones-risque'),
]