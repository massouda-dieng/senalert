from django.urls import path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView

from . import views
from .demandes import DemandePubliqueView

urlpatterns = [
    path('inscription/', views.InscriptionView.as_view(), name='inscription'),
    path('connexion/', views.ConnexionView.as_view(), name='connexion'),
    path('jeton/rafraichir/', TokenRefreshView.as_view(), name='jeton-rafraichir'),
    path('deconnexion/', views.DeconnexionView.as_view(), name='deconnexion'),
    path('profil/', views.ProfilView.as_view(), name='profil'),
    path('mot-de-passe/', views.ChangementMotDePasseView.as_view(), name='mot-de-passe'),
    path('mot-de-passe/oubli/', views.DemandeReinitialisationView.as_view(), name='mot-de-passe-oubli'),
    path('mot-de-passe/reinitialiser/', views.ConfirmationReinitialisationView.as_view(), name='mot-de-passe-reinitialiser'),
    path('google/', views.GoogleConnexionView.as_view(), name='google'),
    path('google/lier/', views.GoogleLiaisonView.as_view(), name='google-lier'),
    path('appareils/', views.DeviceTokenView.as_view(), name='appareils'),
]

routeur = DefaultRouter()
routeur.register('demandes-agent', DemandePubliqueView, basename='demande-agent')
urlpatterns += routeur.urls
