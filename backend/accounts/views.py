from django.conf import settings
from django.contrib.auth.password_validation import validate_password
from django.contrib.auth.tokens import default_token_generator
from django.core.mail import send_mail
from django.db import transaction
from django.db.models import Count, Q
from django.utils import timezone
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from django_filters import rest_framework as filters
from drf_spectacular.utils import extend_schema
from rest_framework import generics, mixins, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenObtainPairView

from core.audit import journaliser
from core.constants import ROLE_AGENT, ROLE_CITOYEN, ROLE_SUPERADMIN
from core.models import Parametre
from core.permissions import EstSuperAdmin

from . import google
from .models import AgentProfil, DeviceToken, User
from .serializers import (
    ChangementMotDePasseSerializer, ConfirmationReinitialisationSerializer, ConnexionSerializer,
    CreationAgentSerializer, DeconnexionSerializer, DemandeReinitialisationSerializer, DeviceTokenSerializer, GoogleSerializer,
    InscriptionSerializer, ModificationUtilisateurSerializer, SuppressionCompteSerializer,
    UtilisateurAdminSerializer, UtilisateurSerializer,
)


def jetons_pour(user):
    refresh = RefreshToken.for_user(user)
    refresh['role'] = user.role
    return {'refresh': str(refresh), 'access': str(refresh.access_token), 'utilisateur': UtilisateurSerializer(user).data}


def revoquer_toutes_les_sessions(user):
    for jeton in OutstandingToken.objects.filter(user=user):
        BlacklistedToken.objects.get_or_create(token=jeton)


class InscriptionView(generics.CreateAPIView):
    serializer_class = InscriptionSerializer
    permission_classes = [permissions.AllowAny]
    throttle_scope = 'inscription'

    def get_throttles(self):
        return [ScopedRateThrottle()]

    def create(self, request, *args, **kwargs):
        s = self.get_serializer(data=request.data)
        s.is_valid(raise_exception=True)
        user = s.save()
        journaliser(request, 'compte.inscription', user, acteur=user)
        return Response(jetons_pour(user), status=status.HTTP_201_CREATED)


class ConnexionView(TokenObtainPairView):
    serializer_class = ConnexionSerializer
    throttle_scope = 'connexion'

    def get_throttles(self):
        return [ScopedRateThrottle()]

    def post(self, request, *args, **kwargs):
        try:
            return super().post(request, *args, **kwargs)
        except Exception:
            journaliser(request, 'compte.echec_connexion', details={'identifiant': str(request.data.get('username', ''))[:150]})
            raise


class DeconnexionView(APIView):
    """Révoque le jeton de rafraîchissement fourni (ou toutes les sessions avec tout=true)."""

    serializer_class = DeconnexionSerializer

    def post(self, request):
        if request.data.get('tout'):
            revoquer_toutes_les_sessions(request.user)
            journaliser(request, 'compte.deconnexion_toutes_sessions', request.user)
            return Response({'detail': 'Toutes les sessions ont été fermées.'})
        try:
            RefreshToken(request.data.get('refresh', '')).blacklist()
        except TokenError:
            pass  # jeton déjà expiré ou révoqué : la session est de toute façon close
        return Response({'detail': 'Session fermée.'})


class ProfilView(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = UtilisateurSerializer

    def get_object(self):
        return self.request.user

    @extend_schema(request=SuppressionCompteSerializer)
    def destroy(self, request, *args, **kwargs):
        """Suppression du compte : anonymisation (les dossiers restent pour les statistiques)."""
        user = request.user
        if user.role == ROLE_SUPERADMIN:
            raise PermissionDenied('Un superadministrateur ne peut pas supprimer son compte depuis l’application.')
        s = SuppressionCompteSerializer(data=request.data, context={'request': request})
        s.is_valid(raise_exception=True)
        with transaction.atomic():
            revoquer_toutes_les_sessions(user)
            journaliser(request, 'compte.suppression', user)
            user.username = f'supprime_{user.pk}'
            user.email = ''
            user.first_name = user.last_name = user.telephone = ''
            user.is_active = False
            user.set_unusable_password()
            user.date_anonymisation = timezone.now()
            user.save()
            user.device_tokens.all().delete()
            user.comptes_externes.all().delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ChangementMotDePasseView(APIView):
    serializer_class = ChangementMotDePasseSerializer
    @extend_schema(request=ChangementMotDePasseSerializer)
    def post(self, request):
        s = ChangementMotDePasseSerializer(data=request.data, context={'request': request})
        s.is_valid(raise_exception=True)
        user = request.user
        user.set_password(s.validated_data['nouveau'])
        user.doit_changer_mot_de_passe = False
        user.save()
        revoquer_toutes_les_sessions(user)
        journaliser(request, 'compte.changement_mot_de_passe', user)
        return Response(jetons_pour(user))


class DemandeReinitialisationView(APIView):
    """Envoie un lien de réinitialisation. Répond toujours pareil (pas de divulgation d'existence de compte)."""

    serializer_class = DemandeReinitialisationSerializer
    permission_classes = [permissions.AllowAny]
    throttle_scope = 'mot_de_passe'

    def get_throttles(self):
        return [ScopedRateThrottle()]

    @extend_schema(request=DemandeReinitialisationSerializer)
    def post(self, request):
        s = DemandeReinitialisationSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        user = User.objects.filter(email__iexact=s.validated_data['email'], is_active=True).first()
        if user is not None:
            uid = urlsafe_base64_encode(force_bytes(user.pk))
            token = default_token_generator.make_token(user)
            lien = f'{settings.FRONTEND_URL}/reinitialiser?uid={uid}&token={token}'
            send_mail(
                'SenAlert — réinitialisation du mot de passe',
                f"Bonjour,\n\nPour choisir un nouveau mot de passe, ouvrez ce lien (valable 1 heure) :\n{lien}\n\n"
                "Si vous n'êtes pas à l'origine de cette demande, ignorez ce message.",
                settings.DEFAULT_FROM_EMAIL, [user.email], fail_silently=True,
            )
            journaliser(request, 'compte.demande_reinitialisation', user, acteur=user)
        return Response({'detail': "Si un compte correspond à cette adresse, un e-mail de réinitialisation a été envoyé."})


class ConfirmationReinitialisationView(APIView):
    serializer_class = ConfirmationReinitialisationSerializer
    permission_classes = [permissions.AllowAny]
    throttle_scope = 'mot_de_passe'

    def get_throttles(self):
        return [ScopedRateThrottle()]

    @extend_schema(request=ConfirmationReinitialisationSerializer)
    def post(self, request):
        s = ConfirmationReinitialisationSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        try:
            user = User.objects.get(pk=force_str(urlsafe_base64_decode(s.validated_data['uid'])), is_active=True)
        except (User.DoesNotExist, ValueError, TypeError, OverflowError):
            user = None
        if user is None or not default_token_generator.check_token(user, s.validated_data['token']):
            raise ValidationError({'token': 'Lien invalide ou expiré. Refaites une demande.'})
        validate_password(s.validated_data['nouveau'], user)
        user.set_password(s.validated_data['nouveau'])
        user.doit_changer_mot_de_passe = False
        user.save()
        revoquer_toutes_les_sessions(user)
        journaliser(request, 'compte.reinitialisation_mot_de_passe', user, acteur=user)
        return Response({'detail': 'Mot de passe modifié. Vous pouvez vous connecter.'})


class GoogleConnexionView(APIView):
    """Connexion / inscription avec un ID token Google vérifié côté serveur."""

    serializer_class = GoogleSerializer
    permission_classes = [permissions.AllowAny]
    throttle_scope = 'connexion'

    def get_throttles(self):
        return [ScopedRateThrottle()]

    @extend_schema(request=GoogleSerializer)
    def post(self, request):
        if not (Parametre.get('fonctionnalites') or {}).get('connexion_google', True):
            raise PermissionDenied('La connexion Google est désactivée.')
        s = GoogleSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        claims = google.verifier_id_token(s.validated_data['id_token'])
        user, cree = google.utilisateur_depuis_google(claims)
        journaliser(request, 'compte.connexion_google' if not cree else 'compte.inscription_google', user, acteur=user)
        return Response({**jetons_pour(user), 'nouveau_compte': cree},
                        status=status.HTTP_201_CREATED if cree else status.HTTP_200_OK)


class GoogleLiaisonView(APIView):
    """Lie (POST) ou délie (DELETE) un compte Google au compte connecté."""

    serializer_class = GoogleSerializer
    @extend_schema(request=GoogleSerializer)
    def post(self, request):
        s = GoogleSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        claims = google.verifier_id_token(s.validated_data['id_token'])
        google.lier_compte(request.user, claims)
        journaliser(request, 'compte.liaison_google', request.user)
        return Response(UtilisateurSerializer(request.user).data)

    def delete(self, request):
        if not request.user.has_usable_password():
            raise ValidationError({'detail': "Définissez d'abord un mot de passe pour ne pas perdre l'accès au compte."})
        request.user.comptes_externes.filter(fournisseur='google').delete()
        journaliser(request, 'compte.deliaison_google', request.user)
        return Response(UtilisateurSerializer(request.user).data)


class DeviceTokenView(APIView):
    serializer_class = DeviceTokenSerializer
    @extend_schema(request=DeviceTokenSerializer)
    def post(self, request):
        s = DeviceTokenSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        _, cree = DeviceToken.objects.update_or_create(
            token=s.validated_data['token'],
            defaults={'user': request.user, 'plateforme': s.validated_data['plateforme'], 'actif': True},
        )
        return Response({'detail': 'Appareil enregistré.'}, status=status.HTTP_201_CREATED if cree else status.HTTP_200_OK)

    @extend_schema(request=DeviceTokenSerializer)
    def delete(self, request):
        DeviceToken.objects.filter(user=request.user, token=request.data.get('token', '')).delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


# --- Administration des comptes ---------------------------------------------

class FiltreUtilisateur(filters.FilterSet):
    role = filters.CharFilter()
    is_active = filters.BooleanFilter()
    service = filters.NumberFilter(field_name='profil_agent__service_id')
    q = filters.CharFilter(method='recherche')
    zone = filters.CharFilter(method='filtre_zone')

    class Meta:
        model = User
        fields = []

    def recherche(self, qs, name, value):
        return qs.filter(Q(username__icontains=value) | Q(email__icontains=value) | Q(first_name__icontains=value)
                         | Q(last_name__icontains=value) | Q(telephone__icontains=value))

    def filtre_zone(self, qs, name, value):
        # Filtrage en Python : JSONField « contains » n'est pas pris en charge par SQLite.
        ids = [p.user_id for p in AgentProfil.objects.all() if value in (p.zones or [])]
        return qs.filter(pk__in=ids)


class UtilisateurAdminViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """Gestion des comptes par le superadministrateur (toutes les opérations sont journalisées)."""

    permission_classes = [EstSuperAdmin]
    serializer_class = UtilisateurAdminSerializer
    filterset_class = FiltreUtilisateur
    ordering_fields = ['date_joined', 'last_login', 'username']

    def get_queryset(self):
        return (User.objects.filter(date_anonymisation__isnull=True)
                .select_related('profil_agent__service')
                .annotate(nb_interventions=Count('interventions'))
                .order_by('-date_joined'))

    @extend_schema(request=CreationAgentSerializer, responses=UtilisateurAdminSerializer)
    @action(detail=False, methods=['post'], url_path='agents')
    def creer_agent(self, request):
        s = CreationAgentSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        with transaction.atomic():
            user = User.objects.create_user(
                username=d['email'], email=d['email'], password=d['mot_de_passe_initial'], role=ROLE_AGENT,
                first_name=d['first_name'], last_name=d['last_name'], telephone=d.get('telephone', ''),
                doit_changer_mot_de_passe=True,
            )
            AgentProfil.objects.create(user=user, service=d['service'], zones=d['zones'],
                                       matricule=d.get('matricule', ''), fonction=d.get('fonction', ''))
            journaliser(request, 'admin.creation_agent', user, {'service': d['service'].pk, 'zones': d['zones']})
        return Response(UtilisateurAdminSerializer(self.get_queryset().get(pk=user.pk)).data, status=status.HTTP_201_CREATED)

    @extend_schema(request=ModificationUtilisateurSerializer, responses=UtilisateurAdminSerializer)
    def partial_update(self, request, pk=None):
        cible = self.get_object()
        s = ModificationUtilisateurSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        if cible.pk == request.user.pk:
            raise PermissionDenied('Vous ne pouvez pas modifier votre propre rôle ou statut.')
        if cible.role == ROLE_SUPERADMIN:
            raise PermissionDenied("Un superadministrateur ne se modifie qu'en ligne de commande sur le serveur.")
        avant = {'role': cible.role, 'is_active': cible.is_active}
        with transaction.atomic():
            if 'role' in d:
                cible.role = d['role']
            if 'is_active' in d:
                cible.is_active = d['is_active']
            cible.save()
            if cible.role == ROLE_AGENT:
                profil, _ = AgentProfil.objects.get_or_create(user=cible)
                for champ in ('service', 'zones', 'matricule', 'fonction'):
                    if champ in d:
                        setattr(profil, champ, d[champ])
                profil.save()
            if avant['is_active'] and not cible.is_active:
                revoquer_toutes_les_sessions(cible)
            if avant['role'] != cible.role:
                revoquer_toutes_les_sessions(cible)  # le rôle est porté par le jeton : reconnexion obligatoire
            journaliser(request, 'admin.modification_utilisateur', cible,
                        {'avant': avant, 'apres': {k: (v.pk if hasattr(v, 'pk') else v) for k, v in d.items()}})
        return Response(UtilisateurAdminSerializer(self.get_queryset().get(pk=cible.pk)).data)

    @action(detail=False, methods=['get'])
    def statistiques(self, request):
        qs = User.objects.filter(date_anonymisation__isnull=True)
        return Response({
            'citoyens': qs.filter(role=ROLE_CITOYEN).count(),
            'agents': qs.filter(role=ROLE_AGENT).count(),
            'agents_actifs': qs.filter(role=ROLE_AGENT, is_active=True).count(),
            'superadmins': qs.filter(role=ROLE_SUPERADMIN).count(),
            'inactifs': qs.filter(is_active=False).count(),
        })
