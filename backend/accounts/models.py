from django.contrib.auth.models import AbstractUser
from django.db import models
from django.db.models.functions import Lower

from core.constants import REGION_CHOICES, ROLE_AGENT, ROLE_CHOICES, ROLE_CITOYEN, ROLE_SUPERADMIN

PREFERENCES_DEFAUT = {
    'notifications_push': True,
    'notifications_statut': True,
    'economie_donnees': False,
    'langue': 'fr',
}


def preferences_defaut():
    return dict(PREFERENCES_DEFAUT)


class User(AbstractUser):
    """Utilisateur SenAlert. Le rôle est attribué côté serveur uniquement."""

    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default=ROLE_CITOYEN, db_index=True)
    telephone = models.CharField(max_length=20, blank=True)
    region = models.CharField(max_length=30, choices=REGION_CHOICES, blank=True)
    preferences = models.JSONField(default=preferences_defaut, blank=True)
    doit_changer_mot_de_passe = models.BooleanField(default=False)
    date_anonymisation = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(
                Lower('email'), name='email_unique_insensible_casse',
                condition=~models.Q(email=''),
            ),
        ]

    def __str__(self):
        return f'{self.username} ({self.role})'

    @property
    def est_superadmin(self):
        return self.role == ROLE_SUPERADMIN

    @property
    def est_agent(self):
        return self.role == ROLE_AGENT

    @property
    def nom_affiche(self):
        return self.get_full_name() or self.username


class AgentProfil(models.Model):
    """Rattachement professionnel d'un agent : service et zones de couverture."""

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profil_agent')
    service = models.ForeignKey('core.Service', null=True, blank=True, on_delete=models.SET_NULL, related_name='agents')
    zones = models.JSONField(default=list, blank=True, help_text='Codes des régions couvertes.')
    matricule = models.CharField(max_length=40, blank=True)
    fonction = models.CharField(max_length=80, blank=True)

    class Meta:
        verbose_name = "Profil d'agent"

    def __str__(self):
        return f'{self.user.username} — {self.service or "sans service"}'


class CompteExterne(models.Model):
    """Liaison entre un compte SenAlert et une identité externe (Google)."""

    PROVIDERS = [('google', 'Google')]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='comptes_externes')
    fournisseur = models.CharField(max_length=20, choices=PROVIDERS)
    identifiant = models.CharField(max_length=255, help_text='Identifiant stable (claim « sub »).')
    email = models.EmailField(blank=True)
    date_liaison = models.DateTimeField(auto_now_add=True)
    derniere_connexion = models.DateTimeField(null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['fournisseur', 'identifiant'], name='compte_externe_unique'),
            models.UniqueConstraint(fields=['fournisseur', 'user'], name='un_compte_par_fournisseur'),
        ]

    def __str__(self):
        return f'{self.fournisseur}:{self.user.username}'


class DeviceToken(models.Model):
    PLATEFORMES = [('android', 'Android'), ('ios', 'iOS'), ('web', 'Web'), ('inconnu', 'Inconnue')]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='device_tokens')
    token = models.CharField(max_length=255, unique=True)
    plateforme = models.CharField(max_length=10, choices=PLATEFORMES, default='inconnu')
    actif = models.BooleanField(default=True)
    date_creation = models.DateTimeField(auto_now_add=True)
    derniere_utilisation = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f'{self.user.username} - {self.token[:12]}…'


class DemandeCompteAgent(models.Model):
    """Demande d'accès d'un agent (policier, pompier…) validée ou refusée par le superadministrateur.

    Le demandeur choisit son mot de passe : seul son empreinte (hash) est conservée.
    Aucun compte n'existe tant que la demande n'est pas validée.
    """

    STATUTS = [('en_attente', 'En attente'), ('validee', 'Validée'), ('refusee', 'Refusée')]

    prenom = models.CharField(max_length=150)
    nom = models.CharField(max_length=150)
    email = models.EmailField()
    telephone = models.CharField(max_length=20)
    matricule = models.CharField(max_length=40)
    service = models.ForeignKey('core.Service', on_delete=models.PROTECT, related_name='demandes')
    structure = models.CharField(max_length=150, help_text='Commissariat, caserne, hôpital, agence…')
    fonction = models.CharField(max_length=80, blank=True)
    zones = models.JSONField(default=list)
    message = models.TextField(max_length=1000, blank=True)
    mot_de_passe_hash = models.CharField(max_length=256)
    statut = models.CharField(max_length=12, choices=STATUTS, default='en_attente', db_index=True)
    motif_refus = models.CharField(max_length=255, blank=True)
    traite_par = models.ForeignKey(User, null=True, blank=True, on_delete=models.SET_NULL, related_name='+')
    date_traitement = models.DateTimeField(null=True, blank=True)
    utilisateur = models.OneToOneField(User, null=True, blank=True, on_delete=models.SET_NULL, related_name='demande_agent')
    date_demande = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date_demande']
        verbose_name = "Demande de compte agent"

    def __str__(self):
        return f'{self.prenom} {self.nom} — {self.service} ({self.statut})'
