from django.db import models
from django.conf import settings

class AlerteSOS(models.Model):
    STATUT_CHOICES = [
        ('nouveau', 'Nouveau'),
        ('en_cours', 'En cours'),
        ('traite', 'Traité'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='alerts_sos',
        null=True,
        blank=True
    )
    latitude = models.FloatField()
    longitude = models.FloatField()
    date_creation = models.DateTimeField(auto_now_add=True)
    statut = models.CharField(
        max_length=20,
        choices=STATUT_CHOICES,
        default='nouveau'
    )

    class Meta:
        ordering = ['-date_creation']
        verbose_name = 'Alerte SOS'
        verbose_name_plural = 'Alertes SOS'

    def __str__(self):
        user_name = self.user.username if self.user else 'Citoyen Anonyme'
        return f"SOS #{self.id} - {user_name} ({self.date_creation.strftime('%Y-%m-%d %H:%M')})"
