from django.db import models

from core.constants import REGION_CHOICES


class ZoneRisque(models.Model):
    """Instantané du score de risque d'une région (classe ZoneRisque du diagramme de classes)."""

    region = models.CharField(max_length=30, choices=REGION_CHOICES, db_index=True)
    score = models.FloatField()
    niveau = models.CharField(max_length=10)
    total_incidents = models.PositiveIntegerField()
    incidents_recents = models.PositiveIntegerField()
    types_predominants = models.JSONField(default=list)
    methode = models.CharField(max_length=40)
    date_calcul = models.DateTimeField(db_index=True)

    class Meta:
        ordering = ['-date_calcul', '-score']
        verbose_name = 'Zone de risque (instantané)'
        verbose_name_plural = 'Zones de risque (historique)'

    def __str__(self):
        return f'{self.region} {self.score} ({self.date_calcul:%Y-%m-%d})'
