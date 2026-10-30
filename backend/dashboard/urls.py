from django.urls import path

from . import views

urlpatterns = [
    path('statistiques/', views.StatistiquesView.as_view(), name='statistiques'),
    path('activite-agent/', views.ActiviteAgentView.as_view(), name='activite-agent'),
    path('export/csv/', views.ExportCSVView.as_view(), name='export-csv'),
    path('export/pdf/', views.ExportPDFView.as_view(), name='export-pdf'),
]
