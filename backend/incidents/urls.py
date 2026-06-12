from django.urls import path
from .views import IncidentListCreateView, IncidentDetailView

urlpatterns = [
    path('', IncidentListCreateView.as_view(), name='incident-list'),
    path('<int:pk>/', IncidentDetailView.as_view(), name='incident-detail'),
]
