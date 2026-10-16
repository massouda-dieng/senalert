from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import RegisterView, ProfileView, MesIncidentsAutoriteView, DeviceTokenView

urlpatterns = [
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', TokenObtainPairView.as_view(), name='login'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token-refresh'),
    path('profile/', ProfileView.as_view(), name='profile'),
    path('mes-incidents/', MesIncidentsAutoriteView.as_view(), name='mes-incidents-autorite'),
    path('device-token/', DeviceTokenView.as_view(), name='device-token'),
]
