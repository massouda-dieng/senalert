from django.db import models
from accounts.models import User

class Incident(models.Model):
    TYPE_CHOICES = [
        ('accident', 'Accident'),
        ('inondation', 'Inondation'),
        ('incendie', 'Incendie'),
        ('electricite', 'Coupure electricite'),
        ('insecurite', 'Insecurite'),
        ('autre', 'Autre'),
    ]
    STATUT_CHOICES = [
        ('nouveau', 'Nouveau'),
        ('en_cours', 'En cours'),
        ('resolu', 'Resolu'),
    ]
    REGION_CHOICES = [
        ('dakar', 'Dakar'),
        ('thies', 'Thies'),
        ('saint_louis', 'Saint-Louis'),
        ('kaolack', 'Kaolack'),
        ('ziguinchor', 'Ziguinchor'),
        ('tambacounda', 'Tambacounda'),
        ('louga', 'Louga'),
        ('fatick', 'Fatick'),
        ('kolda', 'Kolda'),
        ('matam', 'Matam'),
        ('diourbel', 'Diourbel'),
        ('kaffrine', 'Kaffrine'),
        ('sedhiou', 'Sedhiou'),
        ('kedougou', 'Kedougou'),
    ]
    type_incident = models.CharField(max_length=20, choices=TYPE_CHOICES)
    description = models.TextField(blank=True)
    photo = models.ImageField(upload_to='incidents/', blank=True, null=True)
    latitude = models.FloatField()
    longitude = models.FloatField()
    region = models.CharField(max_length=50, choices=REGION_CHOICES)
    statut = models.CharField(max_length=20, choices=STATUT_CHOICES, default='nouveau')
    citoyen = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    date_creation = models.DateTimeField(auto_now_add=True)
    date_modification = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.type_incident} - {self.region} ({self.statut})"

    class Meta:
        ordering = ['-date_creation']
