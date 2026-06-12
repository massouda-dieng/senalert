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
