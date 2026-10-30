from django.urls import path

from . import views
from .demo import DemoView

urlpatterns = [
    path('statistiques/', views.StatistiquesView.as_view(), name='statistiques'),
    path('demo/', DemoView.as_view(), name='demo'),
    path('flux/', views.FluxView.as_view(), name='flux'),
    path('activite-agent/', views.ActiviteAgentView.as_view(), name='activite-agent'),
    path('export/csv/', views.ExportCSVView.as_view(), name='export-csv'),
    path('export/pdf/', views.ExportPDFView.as_view(), name='export-pdf'),
]
