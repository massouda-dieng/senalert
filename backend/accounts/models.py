from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    ROLE_CHOICES = [
        ('citoyen', 'Citoyen'),
        ('admin', 'Administrateur'),
        ('autorite', 'Autorité'),
    ]
    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        default='citoyen'
    )
    telephone = models.CharField(max_length=20, blank=True)
    region = models.CharField(max_length=100, blank=True)

    def __str__(self):
        return f"{self.username} ({self.role})"


class Autorite(models.Model):
    TYPE_CHOICES = [
        ('pompiers', 'Pompiers (Sapeurs-Pompiers)'),
        ('police', 'Police / Gendarmerie'),
        ('sante', 'SAMU / Santé'),
        ('senelec', 'SENELEC (Électricité)'),
        ('onas', 'ONAS (Inondations)'),
    ]

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='autorite')
    type_autorite = models.CharField(max_length=20, choices=TYPE_CHOICES)
    region = models.CharField(max_length=50)
    nom_service = models.CharField(max_length=150, blank=True)

    def __str__(self):
        return f"{self.nom_service or self.type_autorite} - {self.region}"

    # Quel type d'incident cette autorité doit recevoir
    TYPE_INCIDENT_MAP = {
        'pompiers': ['incendie'],
        'police': ['insecurite', 'accident'],
        'sante': ['accident', 'insecurite'],
        'senelec': ['electricite'],
        'onas': ['inondation'],
    }
