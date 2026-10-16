from django.urls import path
from .views import CreateSOSAlertView, ListSOSAlertView

urlpatterns = [
    path('sos/', CreateSOSAlertView.as_view(), name='sos-create'),
    path('sos/list/', ListSOSAlertView.as_view(), name='sos-list'),
]
