from django.contrib.auth import authenticate
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from core.constants import REGIONS, ROLE_AGENT, ROLE_CITOYEN
from core.models import Service

from .models import PREFERENCES_DEFAUT, AgentProfil, User


def email_existe(email, exclure=None):
    qs = User.objects.filter(email__iexact=email)
    if exclure is not None:
        qs = qs.exclude(pk=exclure.pk)
    return qs.exists()


class AgentProfilSerializer(serializers.ModelSerializer):
    service_nom = serializers.CharField(source='service.nom', default=None, read_only=True)

    class Meta:
        model = AgentProfil
        fields = ['service', 'service_nom', 'zones', 'matricule', 'fonction']


class UtilisateurSerializer(serializers.ModelSerializer):
    """Profil de l'utilisateur connecté. Le rôle est en lecture seule."""

    profil_agent = AgentProfilSerializer(read_only=True)
    role_libelle = serializers.CharField(source='get_role_display', read_only=True)
    google_lie = serializers.SerializerMethodField()
    a_mot_de_passe = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'telephone', 'region', 'role',
                  'role_libelle', 'preferences', 'doit_changer_mot_de_passe', 'profil_agent', 'google_lie',
                  'a_mot_de_passe', 'date_joined']
        read_only_fields = ['id', 'username', 'role', 'doit_changer_mot_de_passe', 'date_joined']

    def get_google_lie(self, obj) -> bool:
        return obj.comptes_externes.filter(fournisseur='google').exists()

    def get_a_mot_de_passe(self, obj) -> bool:
        return obj.has_usable_password()

    def validate_email(self, value):
        value = value.strip().lower()
        if value and email_existe(value, exclure=self.instance):
            raise serializers.ValidationError('Cette adresse e-mail est déjà utilisée.')
        return value

    def validate_region(self, value):
        if value and value not in REGIONS:
            raise serializers.ValidationError('Région inconnue.')
        return value

    def validate_preferences(self, value):
        if not isinstance(value, dict):
            raise serializers.ValidationError('Format invalide.')
        inconnues = set(value) - set(PREFERENCES_DEFAUT)
        if inconnues:
            raise serializers.ValidationError(f"Préférences inconnues : {', '.join(sorted(inconnues))}.")
        return {**PREFERENCES_DEFAUT, **(self.instance.preferences if self.instance else {}), **value}


class InscriptionSerializer(serializers.ModelSerializer):
    """Inscription publique : le rôle est TOUJOURS « citoyen », quel que soit le contenu envoyé."""

    password = serializers.CharField(write_only=True, style={'input_type': 'password'})
    email = serializers.EmailField()
    username = serializers.CharField(required=False, allow_blank=True, max_length=150)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'password', 'first_name', 'last_name', 'telephone', 'region']

    def validate_email(self, value):
        value = value.strip().lower()
        if email_existe(value):
            raise serializers.ValidationError('Un compte existe déjà avec cette adresse e-mail.')
        return value

    def validate_region(self, value):
        if value and value not in REGIONS:
            raise serializers.ValidationError('Région inconnue.')
        return value

    def validate(self, attrs):
        attrs['username'] = (attrs.get('username') or attrs['email']).strip().lower()
        if User.objects.filter(username__iexact=attrs['username']).exists():
            raise serializers.ValidationError({'username': "Cet identifiant est déjà utilisé."})
        validate_password(attrs['password'], User(username=attrs['username'], email=attrs['email']))
        return attrs

    def create(self, validated_data):
        password = validated_data.pop('password')
        return User.objects.create_user(password=password, role=ROLE_CITOYEN, **validated_data)


class ConnexionSerializer(TokenObtainPairSerializer):
    """Connexion par identifiant OU adresse e-mail. Renvoie aussi le profil (dont le rôle serveur)."""

    default_error_messages = {'no_active_account': 'Identifiants incorrects ou compte désactivé.'}

    def validate(self, attrs):
        identifiant = (attrs.get('username') or '').strip()
        user = User.objects.filter(email__iexact=identifiant).first() if '@' in identifiant else None
        attrs['username'] = user.username if user else identifiant
        if user is None and '@' in identifiant:
            self._signaler_demande_en_cours(identifiant, attrs.get('password') or '')
        data = super().validate(attrs)
        data['utilisateur'] = UtilisateurSerializer(self.user).data
        return data

    @staticmethod
    def _signaler_demande_en_cours(email, mot_de_passe):
        """Demande d'accès agent pas encore validée : message explicite, seulement si le mot de passe correspond."""
        from django.contrib.auth.hashers import check_password
        from rest_framework.exceptions import AuthenticationFailed

        from .models import DemandeCompteAgent
        d = DemandeCompteAgent.objects.filter(email__iexact=email).exclude(statut='validee').first()
        if d is None:
            return
        if d.statut == 'en_attente' and check_password(mot_de_passe, d.mot_de_passe_hash):
            raise AuthenticationFailed('Votre demande de compte agent est en attente de validation par un superviseur. '
                                       'Vous pourrez vous connecter dès qu’elle sera acceptée.', code='demande_en_attente')
        if d.statut == 'refusee':
            raise AuthenticationFailed('Votre demande de compte agent a été refusée. Contactez votre superviseur.', code='demande_refusee')

    @classmethod
    def get_token(cls, user):
        token = super().get_token(user)
        token['role'] = user.role
        return token


class ChangementMotDePasseSerializer(serializers.Serializer):
    ancien = serializers.CharField(required=False, allow_blank=True)
    nouveau = serializers.CharField()

    def validate(self, attrs):
        user = self.context['request'].user
        if user.has_usable_password() and not user.check_password(attrs.get('ancien') or ''):
            raise serializers.ValidationError({'ancien': 'Mot de passe actuel incorrect.'})
        validate_password(attrs['nouveau'], user)
        return attrs


class DemandeReinitialisationSerializer(serializers.Serializer):
    email = serializers.EmailField()


class ConfirmationReinitialisationSerializer(serializers.Serializer):
    uid = serializers.CharField()
    token = serializers.CharField()
    nouveau = serializers.CharField()


class SuppressionCompteSerializer(serializers.Serializer):
    mot_de_passe = serializers.CharField(required=False, allow_blank=True)
    confirmation = serializers.CharField()

    def validate(self, attrs):
        user = self.context['request'].user
        if attrs['confirmation'] != 'SUPPRIMER':
            raise serializers.ValidationError({'confirmation': 'Tapez SUPPRIMER pour confirmer.'})
        if user.has_usable_password() and not authenticate(username=user.username, password=attrs.get('mot_de_passe') or ''):
            raise serializers.ValidationError({'mot_de_passe': 'Mot de passe incorrect.'})
        return attrs


class DeconnexionSerializer(serializers.Serializer):
    refresh = serializers.CharField(required=False)
    tout = serializers.BooleanField(required=False, default=False)


class GoogleSerializer(serializers.Serializer):
    id_token = serializers.CharField(max_length=4096)


class DeviceTokenSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=255)
    plateforme = serializers.ChoiceField(choices=['android', 'ios', 'web', 'inconnu'], default='inconnu')


# --- Administration des comptes (superadministrateur) -----------------------

class UtilisateurAdminSerializer(serializers.ModelSerializer):
    profil_agent = AgentProfilSerializer(read_only=True)
    role_libelle = serializers.CharField(source='get_role_display', read_only=True)
    nb_interventions = serializers.IntegerField(read_only=True, default=None)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name', 'telephone', 'region', 'role', 'role_libelle',
                  'is_active', 'last_login', 'date_joined', 'profil_agent', 'nb_interventions']
        read_only_fields = fields


class CreationAgentSerializer(serializers.Serializer):
    email = serializers.EmailField()
    first_name = serializers.CharField(max_length=150)
    last_name = serializers.CharField(max_length=150)
    telephone = serializers.CharField(max_length=20, required=False, allow_blank=True)
    mot_de_passe_initial = serializers.CharField(write_only=True)
    service = serializers.PrimaryKeyRelatedField(queryset=Service.objects.filter(actif=True))
    zones = serializers.ListField(child=serializers.ChoiceField(choices=list(REGIONS)), allow_empty=False)
    matricule = serializers.CharField(max_length=40, required=False, allow_blank=True)
    fonction = serializers.CharField(max_length=80, required=False, allow_blank=True)

    def validate_email(self, value):
        value = value.strip().lower()
        if email_existe(value) or User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError('Un compte existe déjà avec cette adresse e-mail.')
        return value

    def validate(self, attrs):
        validate_password(attrs['mot_de_passe_initial'], User(username=attrs['email'], email=attrs['email']))
        return attrs


class ModificationUtilisateurSerializer(serializers.Serializer):
    """Seuls les rôles citoyen ↔ agent sont attribuables par l'API.

    Le rôle superadministrateur se provisionne exclusivement en ligne de
    commande sur le serveur (python manage.py creer_superadmin).
    """

    role = serializers.ChoiceField(choices=[ROLE_CITOYEN, ROLE_AGENT], required=False)
    is_active = serializers.BooleanField(required=False)
    service = serializers.PrimaryKeyRelatedField(queryset=Service.objects.all(), required=False, allow_null=True)
    zones = serializers.ListField(child=serializers.ChoiceField(choices=list(REGIONS)), required=False)
    matricule = serializers.CharField(max_length=40, required=False, allow_blank=True)
    fonction = serializers.CharField(max_length=80, required=False, allow_blank=True)
