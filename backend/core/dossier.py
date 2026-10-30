import uuid

from django.conf import settings
from django.db import models
from django.utils import timezone

from .constants import GRAVITE_CHOICES, NOUVEAU, REGION_CHOICES, STATUT_CHOICES


class Dossier(models.Model):
    """Champs communs aux incidents et aux alertes SOS (un « dossier » suivi)."""

    PREFIXE = 'DOS'

    uuid = models.UUIDField(default=uuid.uuid4, unique=True, editable=False)
    reference = models.CharField(max_length=24, unique=True, null=True, blank=True, editable=False)
    citoyen = models.ForeignKey(
        settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL, related_name='+',
    )
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    precision_gps = models.FloatField(null=True, blank=True, help_text='Précision horizontale en mètres.')
    region = models.CharField(max_length=30, choices=REGION_CHOICES, blank=True, db_index=True)
    adresse = models.CharField(max_length=255, blank=True, help_text='Lieu-dit ou repère donné par le citoyen.')
    statut = models.CharField(max_length=20, choices=STATUT_CHOICES, default=NOUVEAU, db_index=True)
    gravite = models.CharField(max_length=10, choices=GRAVITE_CHOICES, default='moyenne')
    service = models.ForeignKey('core.Service', null=True, blank=True, on_delete=models.SET_NULL, related_name='+')
    client_request_id = models.UUIDField(
        null=True, blank=True, help_text="Clé d'idempotence fournie par le client (anti-doublon réseau).",
    )
    date_creation = models.DateTimeField(default=timezone.now, db_index=True)
    date_modification = models.DateTimeField(auto_now=True)
    date_prise_en_charge = models.DateTimeField(null=True, blank=True)
    date_cloture = models.DateTimeField(null=True, blank=True)
    motif_cloture = models.CharField(max_length=255, blank=True)

    class Meta:
        abstract = True
        ordering = ['-date_creation']

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        if not self.reference:
            # Référence lisible, unique et stable : PRÉFIXE-ANNÉE-NUMÉRO
            self.reference = f'{self.PREFIXE}-{self.date_creation:%Y}-{self.pk:06d}'
            type(self).objects.filter(pk=self.pk).update(reference=self.reference)

    @property
    def a_position(self):
        return self.latitude is not None and self.longitude is not None
