from django.urls import path
from .views import ZonesRisqueView, AIAssistantView

urlpatterns = [
    path('zones-risque/', ZonesRisqueView.as_view(), name='zones-risque'),
    path('ai-assistant/', AIAssistantView.as_view(), name='ai-assistant'),
]