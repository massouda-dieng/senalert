from django.db import models

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
