from django.conf import settings
from django.db import models


class Notification(models.Model):
    """Notification liée à un événement réel d'un dossier.

    L'état « enregistrée » (cette ligne existe) est distinct de l'envoi push :
    statut_push indique seulement si FCM a accepté le message, pas qu'il a été
    lu. La lecture n'est connue que lorsque l'utilisateur l'ouvre (lue=True).
    """

    PUSH_STATUTS = [
        ('en_attente', 'En attente'),
        ('envoyee', 'Acceptée par FCM'),
        ('echec', 'Échec'),
        ('non_configure', 'Push non configuré'),
        ('aucun_appareil', 'Aucun appareil enregistré'),
        ('desactivee', 'Désactivée par l’utilisateur'),
    ]
    TYPES = [
        ('nouvelle_alerte', 'Nouvelle alerte'),
        ('affectation', 'Affectation'),
        ('statut', 'Changement de statut'),
        ('resolution', 'Résolution'),
        ('complement', 'Complément'),
        ('systeme', 'Système'),
    ]

    destinataire = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    type = models.CharField(max_length=20, choices=TYPES)
    titre = models.CharField(max_length=120)
    message = models.CharField(max_length=500)
    incident = models.ForeignKey('incidents.Incident', null=True, blank=True, on_delete=models.CASCADE, related_name='+')
    alerte = models.ForeignKey('alerts.AlerteSOS', null=True, blank=True, on_delete=models.CASCADE, related_name='+')
    cle_deduplication = models.CharField(max_length=120)
    lue = models.BooleanField(default=False)
    date_lecture = models.DateTimeField(null=True, blank=True)
    statut_push = models.CharField(max_length=20, choices=PUSH_STATUTS, default='en_attente')
    erreur_push = models.CharField(max_length=255, blank=True)
    date_creation = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-date_creation']
        constraints = [
            models.UniqueConstraint(fields=['destinataire', 'cle_deduplication'], name='notification_unique'),
        ]

    def __str__(self):
        return f'{self.destinataire} — {self.titre}'
