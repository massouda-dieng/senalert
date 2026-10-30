"""Demandes de compte agent : le demandeur s'inscrit, le superadministrateur valide ou refuse."""

from django.conf import settings
from django.contrib.auth.hashers import make_password
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.mail import send_mail
from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import mixins, permissions, serializers, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle

from core.audit import journaliser
from core.constants import REGIONS, ROLE_AGENT
from core.exceptions import Conflit
from core.models import Service
from core.permissions import EstSuperAdmin
from notifications import service as notif

from .models import AgentProfil, DemandeCompteAgent, User
from .serializers import email_existe


class DemandeCreationSerializer(serializers.ModelSerializer):
    mot_de_passe = serializers.CharField(write_only=True)
    service = serializers.PrimaryKeyRelatedField(queryset=Service.objects.filter(actif=True))
    zones = serializers.ListField(child=serializers.ChoiceField(choices=list(REGIONS)), allow_empty=False)

    class Meta:
        model = DemandeCompteAgent
        fields = ['prenom', 'nom', 'email', 'telephone', 'matricule', 'service', 'structure', 'fonction', 'zones',
                  'message', 'mot_de_passe']

    def validate_email(self, value):
        value = value.strip().lower()
        if email_existe(value) or User.objects.filter(username__iexact=value).exists():
            raise serializers.ValidationError('Un compte existe déjà avec cette adresse : connectez-vous ou contactez votre superviseur.')
        if DemandeCompteAgent.objects.filter(email__iexact=value, statut='en_attente').exists():
            raise serializers.ValidationError('Une demande est déjà en cours d’examen pour cette adresse.')
        return value

    def validate(self, attrs):
        try:
            validate_password(attrs['mot_de_passe'], User(username=attrs['email'], email=attrs['email'],
                                                          first_name=attrs['prenom'], last_name=attrs['nom']))
        except DjangoValidationError as e:
            raise serializers.ValidationError({'mot_de_passe': list(e.messages)})
        attrs['mot_de_passe_hash'] = make_password(attrs.pop('mot_de_passe'))
        return attrs


class DemandeSerializer(serializers.ModelSerializer):
    service_nom = serializers.CharField(source='service.nom', read_only=True)
    zones_libelles = serializers.SerializerMethodField()
    traite_par_nom = serializers.CharField(source='traite_par.username', default=None, read_only=True)

    class Meta:
        model = DemandeCompteAgent
        fields = ['id', 'prenom', 'nom', 'email', 'telephone', 'matricule', 'service', 'service_nom', 'structure',
                  'fonction', 'zones', 'zones_libelles', 'message', 'statut', 'motif_refus', 'traite_par_nom',
                  'date_traitement', 'date_demande', 'utilisateur']

    def get_zones_libelles(self, obj) -> list:
        return [REGIONS[z]['libelle'] for z in obj.zones if z in REGIONS]


class DemandePubliqueView(mixins.CreateModelMixin, viewsets.GenericViewSet):
    """POST /api/auth/demandes-agent/ : demande d'accès agent (publique, limitée à 10 par heure)."""

    permission_classes = [permissions.AllowAny]
    serializer_class = DemandeCreationSerializer
    throttle_scope = 'inscription'

    def get_throttles(self):
        return [ScopedRateThrottle()]

    def create(self, request, *args, **kwargs):
        s = self.get_serializer(data=request.data)
        s.is_valid(raise_exception=True)
        demande = s.save()
        journaliser(request, 'compte.demande_agent', demande, {'service': demande.service_id, 'email': demande.email})
        transaction.on_commit(lambda: notif.notifier(
            notif.superadmins(), 'systeme', "Nouvelle demande de compte agent",
            f'{demande.prenom} {demande.nom} — {demande.service.nom} ({demande.structure})', None, f'demande_agent:{demande.pk}'))
        return Response({'detail': "Demande envoyée. Vous pourrez vous connecter dès qu'un superviseur l'aura validée.",
                         'id': demande.pk}, status=status.HTTP_201_CREATED)


class DemandeGestionViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """Demandes d'accès agent, pour le superadministrateur (filtre ?statut=)."""

    permission_classes = [EstSuperAdmin]
    serializer_class = DemandeSerializer

    def get_queryset(self):
        qs = DemandeCompteAgent.objects.select_related('service', 'traite_par')
        if self.request.query_params.get('statut'):
            qs = qs.filter(statut=self.request.query_params['statut'])
        return qs

    def _a_traiter(self, pk):
        demande = get_object_or_404(DemandeCompteAgent.objects.select_for_update(), pk=pk)
        if demande.statut != 'en_attente':
            raise Conflit('Cette demande a déjà été traitée.')
        return demande

    @action(detail=True, methods=['post'])
    def valider(self, request, pk=None):
        with transaction.atomic():
            d = self._a_traiter(pk)
            if email_existe(d.email) or User.objects.filter(username__iexact=d.email).exists():
                raise Conflit('Un compte existe déjà avec cette adresse e-mail.')
            user = User(username=d.email, email=d.email, first_name=d.prenom, last_name=d.nom, telephone=d.telephone,
                        role=ROLE_AGENT, region=d.zones[0] if d.zones else '')
            user.password = d.mot_de_passe_hash  # mot de passe choisi par l'agent, jamais vu par le superviseur
            user.save()
            AgentProfil.objects.create(user=user, service=d.service, zones=d.zones, matricule=d.matricule,
                                       fonction=d.fonction or d.structure)
            d.statut, d.utilisateur, d.traite_par, d.date_traitement = 'validee', user, request.user, timezone.now()
            d.mot_de_passe_hash = ''  # plus utile une fois le compte créé
            d.save()
            journaliser(request, 'admin.validation_demande_agent', user, {'demande': d.pk, 'service': d.service_id, 'zones': d.zones})
        send_mail('SenAlert — votre compte agent est activé',
                  f'Bonjour {d.prenom},\n\nVotre demande a été validée. Connectez-vous avec {d.email} et le mot de passe '
                  f'que vous avez choisi : {settings.FRONTEND_URL}/connexion', settings.DEFAULT_FROM_EMAIL, [d.email], fail_silently=True)
        return Response(DemandeSerializer(d).data)

    @action(detail=True, methods=['post'])
    def refuser(self, request, pk=None):
        motif = (request.data.get('motif') or '').strip()
        if len(motif) < 3:
            raise serializers.ValidationError({'motif': 'Indiquez le motif du refus.'})
        with transaction.atomic():
            d = self._a_traiter(pk)
            d.statut, d.motif_refus, d.traite_par, d.date_traitement = 'refusee', motif[:255], request.user, timezone.now()
            d.mot_de_passe_hash = ''
            d.save()
            journaliser(request, 'admin.refus_demande_agent', d, {'motif': d.motif_refus})
        send_mail('SenAlert — demande de compte agent', f'Bonjour {d.prenom},\n\nVotre demande n’a pas été retenue : {d.motif_refus}',
                  settings.DEFAULT_FROM_EMAIL, [d.email], fail_silently=True)
        return Response(DemandeSerializer(d).data)

    @action(detail=False, methods=['get'])
    def compteur(self, request):
        return Response({'en_attente': DemandeCompteAgent.objects.filter(statut='en_attente').count()})
