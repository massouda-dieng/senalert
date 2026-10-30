from django.db import models
from django.utils import timezone

from core.dossier import Dossier


class AlerteSOS(Dossier):
    """Alerte SOS géolocalisée. La position peut être absente si le GPS est indisponible."""

    PREFIXE = 'SOS'

    citoyen = models.ForeignKey(
        'accounts.User', null=True, blank=True, on_delete=models.SET_NULL, related_name='alertes_sos',
    )
    message = models.CharField(max_length=280, blank=True)
    source_position = models.CharField(
        max_length=20, blank=True,
        choices=[('gps', 'GPS'), ('reseau', 'Réseau'), ('indisponible', 'Indisponible')],
    )

    class Meta(Dossier.Meta):
        verbose_name = 'Alerte SOS'
        verbose_name_plural = 'Alertes SOS'
        constraints = [
            models.UniqueConstraint(fields=['citoyen', 'client_request_id'], name='sos_idempotence'),
        ]

    def __str__(self):
        return self.reference or f'SOS #{self.pk}'


class AlerteZone(models.Model):
    """Alerte publiée par le superadministrateur pour une ou plusieurs régions
    (inondation annoncée, coupure planifiée, consigne de sécurité…)."""

    NIVEAUX = [('info', 'Information'), ('vigilance', 'Vigilance'), ('danger', 'Danger')]

    titre = models.CharField(max_length=120)
    message = models.TextField(max_length=1000)
    consignes = models.TextField(max_length=1000, blank=True)
    niveau = models.CharField(max_length=10, choices=NIVEAUX, default='vigilance')
    categorie = models.CharField(max_length=30, blank=True, help_text="Code de catégorie concernée (facultatif).")
    regions = models.JSONField(default=list, help_text='Codes des régions concernées (vide = tout le pays).')
    date_debut = models.DateTimeField(default=timezone.now)
    date_fin = models.DateTimeField(null=True, blank=True)
    active = models.BooleanField(default=True)
    publie_par = models.ForeignKey('accounts.User', null=True, on_delete=models.SET_NULL, related_name='+')
    date_creation = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-date_debut']
        verbose_name = 'Alerte de zone'
        verbose_name_plural = 'Alertes de zone'

    def __str__(self):
        return self.titre

    @property
    def en_cours(self):
        maintenant = timezone.now()
        return self.active and self.date_debut <= maintenant and (self.date_fin is None or self.date_fin > maintenant)
