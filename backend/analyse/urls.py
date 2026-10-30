from django.urls import path

from .views import AssistantView, InstantaneView, ZonesRisqueView

urlpatterns = [
    path('zones-risque/', ZonesRisqueView.as_view(), name='zones-risque'),
    path('zones-risque/historique/', InstantaneView.as_view(), name='zones-risque-historique'),
    path('assistant/', AssistantView.as_view(), name='assistant'),
]
