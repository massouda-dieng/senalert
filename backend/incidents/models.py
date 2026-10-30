import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone

from core.constants import STATUT_CHOICES
from core.dossier import Dossier


class Incident(Dossier):
    """Signalement d'incident par un citoyen (catégorie, description, position, photos)."""

    PREFIXE = 'INC'

    citoyen = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name='incidents',
    )
    # Code d'une core.Categorie active (validé par le sérialiseur). Conservé en
    # texte pour préserver l'historique si une catégorie est désactivée.
    type_incident = models.CharField(max_length=30, db_index=True)
    description = models.TextField(blank=True)
    date_incident = models.DateTimeField(null=True, blank=True, help_text="Date/heure de l'incident si différente du signalement.")
    infos_complementaires = models.TextField(blank=True)
    doublon_potentiel_de = models.ForeignKey(
        'self', null=True, blank=True, on_delete=models.SET_NULL, related_name='doublons_potentiels',
    )

    class Meta(Dossier.Meta):
        constraints = [
            models.UniqueConstraint(fields=['citoyen', 'client_request_id'], name='incident_idempotence'),
        ]

    def __str__(self):
        return f'{self.reference or self.pk} — {self.type_incident} ({self.statut})'


def chemin_piece_jointe(instance, filename):
    # Nom aléatoire : ni le nom d'origine ni l'identité du citoyen ne fuient.
    return f'pieces_jointes/{timezone.now():%Y/%m}/{uuid.uuid4().hex}.jpg'


class PieceJointe(models.Model):
    """Photo jointe à un incident (ré-encodée en JPEG, métadonnées EXIF supprimées)."""

    incident = models.ForeignKey(Incident, on_delete=models.CASCADE, related_name='pieces_jointes')
    fichier = models.FileField(upload_to=chemin_piece_jointe)
    taille = models.PositiveIntegerField()
    largeur = models.PositiveIntegerField(null=True)
    hauteur = models.PositiveIntegerField(null=True)
    auteur = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name='+')
    date_ajout = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['date_ajout']


class Intervention(models.Model):
    """Affectation d'un dossier (incident OU alerte SOS) à un service et à un agent.

    Le statut opérationnel est porté par le dossier lui-même (source unique de
    vérité) ; l'intervention conserve l'affectation, les dates et le compte rendu.
    """

    incident = models.OneToOneField(Incident, null=True, blank=True, on_delete=models.CASCADE, related_name='intervention')
    alerte = models.OneToOneField('alerts.AlerteSOS', null=True, blank=True, on_delete=models.CASCADE, related_name='intervention')
    service = models.ForeignKey('core.Service', null=True, blank=True, on_delete=models.SET_NULL, related_name='interventions')
    agent = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name='interventions',
    )
    affecte_par = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name='+')
    date_affectation = models.DateTimeField(null=True, blank=True)
    date_acceptation = models.DateTimeField(null=True, blank=True)
    date_debut = models.DateTimeField(null=True, blank=True)
    date_fin = models.DateTimeField(null=True, blank=True)
    compte_rendu = models.TextField(blank=True)
    difficultes = models.TextField(blank=True)

    class Meta:
        constraints = [
            models.CheckConstraint(
                condition=(models.Q(incident__isnull=False, alerte__isnull=True)
                           | models.Q(incident__isnull=True, alerte__isnull=False)),
                name='intervention_un_seul_dossier',
            ),
        ]

    @property
    def dossier(self):
        return self.incident or self.alerte

    @property
    def statut(self):
        return self.dossier.statut

    def __str__(self):
        return f'Intervention {self.dossier}'


class EvenementDossier(models.Model):
    """Historique horodaté d'un dossier (création, affectation, transitions, notes…)."""

    TYPES = [
        ('creation', 'Création'),
        ('affectation', 'Affectation'),
        ('transition', 'Changement de statut'),
        ('complement', 'Complément du citoyen'),
        ('note', 'Note interne'),
        ('gravite', 'Changement de gravité'),
        ('doublon', 'Doublon potentiel'),
        ('notification', 'Notification'),
    ]

    incident = models.ForeignKey(Incident, null=True, blank=True, on_delete=models.CASCADE, related_name='evenements')
    alerte = models.ForeignKey('alerts.AlerteSOS', null=True, blank=True, on_delete=models.CASCADE, related_name='evenements')
    type = models.CharField(max_length=20, choices=TYPES)
    statut_avant = models.CharField(max_length=20, choices=STATUT_CHOICES, blank=True)
    statut_apres = models.CharField(max_length=20, choices=STATUT_CHOICES, blank=True)
    acteur = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name='+')
    message = models.TextField(blank=True)
    visible_citoyen = models.BooleanField(default=True)
    date = models.DateTimeField(default=timezone.now, db_index=True)

    class Meta:
        ordering = ['date', 'pk']
        verbose_name = 'Événement de dossier'


class Confirmation(models.Model):
    """Un citoyen confirme avoir constaté le même incident (« je le vois aussi »)."""

    incident = models.ForeignKey(Incident, on_delete=models.CASCADE, related_name='confirmations')
    citoyen = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='+')
    date = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [models.UniqueConstraint(fields=['incident', 'citoyen'], name='confirmation_unique')]


class Commentaire(models.Model):
    """Message communautaire public sur un incident, modérable par le superadministrateur."""

    incident = models.ForeignKey(Incident, on_delete=models.CASCADE, related_name='commentaires')
    auteur = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, on_delete=models.SET_NULL, related_name='+')
    texte = models.CharField(max_length=500)
    masque = models.BooleanField(default=False)
    masque_par = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name='+')
    date = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['date']
