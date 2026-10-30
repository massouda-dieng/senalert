import uuid

from django.conf import settings
from django.core.cache import cache
from django.db import models

from .constants import GRAVITE_CHOICES


class Service(models.Model):
    """Service de secours ou d'intervention (Police, Pompiers, Santé, SENELEC, ONAS…)."""

    code = models.SlugField(max_length=30, unique=True)
    nom = models.CharField(max_length=120)
    description = models.TextField(blank=True)
    actif = models.BooleanField(default=True)
    date_creation = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['nom']

    def __str__(self):
        return self.nom


class Categorie(models.Model):
    """Catégorie d'incident, administrable sans modifier le code."""

    code = models.SlugField(max_length=30, unique=True)
    libelle = models.CharField(max_length=80)
    description = models.CharField(max_length=255, blank=True)
    service_defaut = models.ForeignKey(
        Service, null=True, blank=True, on_delete=models.SET_NULL, related_name='categories',
        help_text="Service qui reçoit par défaut les incidents de cette catégorie.",
    )
    gravite_defaut = models.CharField(max_length=10, choices=GRAVITE_CHOICES, default='moyenne')
    icone = models.CharField(max_length=40, blank=True, help_text="Nom d'icône (Material / Lucide).")
    couleur = models.CharField(max_length=9, default='#475569')
    ordre = models.PositiveSmallIntegerField(default=100)
    actif = models.BooleanField(default=True)

    class Meta:
        ordering = ['ordre', 'libelle']
        verbose_name = 'Catégorie'

    def __str__(self):
        return self.libelle


class Parametre(models.Model):
    """Paramètre de configuration modifiable par un superadministrateur (journalisé)."""

    DEFAUTS = {
        'numeros_urgence': {
            'description': "Numéros d'urgence officiels. Seuls les numéros marqués vérifiés sont affichés aux citoyens.",
            'valeur': [
                {'service': 'Police', 'numero': '17', 'verifie': True,
                 'source': 'Mémoire SenAlert ch. 1 ; voyage.gc.ca ; senego.com (vérifié le 29/10/2026)'},
                {'service': 'Sapeurs-pompiers', 'numero': '18', 'verifie': True,
                 'source': 'Mémoire SenAlert ch. 1 ; voyage.gc.ca ; senego.com (vérifié le 29/10/2026)'},
                {'service': 'SAMU national', 'numero': '1515', 'verifie': False,
                 'source': "Sources divergentes (15 ou 1515) : à confirmer auprès du SAMU national avant affichage."},
            ],
        },
        'delais_prise_en_charge_minutes': {
            'description': "Délai au-delà duquel un dossier non pris en charge est signalé en retard.",
            'valeur': {'sos': 10, 'incident': 60},
        },
        'doublons': {
            'description': "Détection des doublons potentiels : même catégorie, distance et fenêtre de temps.",
            'valeur': {'rayon_metres': 300, 'fenetre_minutes': 120},
        },
        'workflow': {
            'description': "Règles du cycle de vie des dossiers.",
            'valeur': {
                'agent_peut_prendre_en_charge': True,
                'citoyen_peut_annuler': True,
                'compte_rendu_obligatoire': True,
            },
        },
        'conservation': {
            'description': "Durée de conservation (jours) avant anonymisation des dossiers clos.",
            'valeur': {'jours_avant_anonymisation': 730},
        },
        'sms_secours': {
            'description': ("Numéro qui reçoit les SOS par SMS quand internet est coupé (passerelle SMS ou centre "
                            "d'appel). Laisser inactif tant qu'aucun numéro réel n'est en service."),
            'valeur': {'actif': False, 'numero': ''},
        },
        'fonctionnalites': {
            'description': "Activation des fonctionnalités optionnelles.",
            'valeur': {'assistant_ia': True, 'connexion_google': True, 'carte_publique': True},
        },
    }

    cle = models.SlugField(max_length=60, unique=True)
    valeur = models.JSONField()
    description = models.CharField(max_length=255, blank=True)
    modifie_par = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL)
    date_modification = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['cle']
        verbose_name = 'Paramètre'

    def __str__(self):
        return self.cle

    @classmethod
    def get(cls, cle):
        cache_key = f'parametre:{cle}'
        valeur = cache.get(cache_key)
        if valeur is None:
            obj = cls.objects.filter(cle=cle).first()
            valeur = obj.valeur if obj else cls.DEFAUTS.get(cle, {}).get('valeur')
            cache.set(cache_key, valeur, 60)
        return valeur

    def save(self, *args, **kwargs):
        super().save(*args, **kwargs)
        cache.delete(f'parametre:{self.cle}')


class JournalAudit(models.Model):
    """Trace des opérations sensibles. Ne contient jamais de mot de passe ni de jeton."""

    acteur = models.ForeignKey(settings.AUTH_USER_MODEL, null=True, blank=True, on_delete=models.SET_NULL)
    action = models.CharField(max_length=60, db_index=True)
    cible_type = models.CharField(max_length=40, blank=True)
    cible_id = models.CharField(max_length=60, blank=True)
    details = models.JSONField(default=dict, blank=True)
    adresse_ip = models.GenericIPAddressField(null=True, blank=True)
    date = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['-date']
        verbose_name = "Entrée du journal d'audit"
        verbose_name_plural = "Journal d'audit"

    def __str__(self):
        return f'{self.date:%Y-%m-%d %H:%M} {self.action}'


class FicheSecours(models.Model):
    """Fiche de premiers secours. Contenu rédigé par l'équipe, jamais généré par l'IA."""

    slug = models.SlugField(max_length=60, unique=True)
    titre = models.CharField(max_length=120)
    categorie = models.CharField(max_length=60)
    resume = models.CharField(max_length=255)
    etapes = models.JSONField(help_text='Liste ordonnée d’instructions courtes.')
    a_eviter = models.JSONField(default=list, blank=True)
    appeler_si = models.CharField(max_length=255, blank=True)
    sources = models.JSONField(default=list)
    valide_par = models.CharField(
        max_length=120, blank=True,
        help_text="Nom et qualité du professionnel de santé ayant validé la fiche (vide = non validée).",
    )
    date_mise_a_jour = models.DateField()
    ordre = models.PositiveSmallIntegerField(default=100)
    publie = models.BooleanField(default=True)

    class Meta:
        ordering = ['ordre', 'titre']
        verbose_name = 'Fiche de premiers secours'
        verbose_name_plural = 'Fiches de premiers secours'

    def __str__(self):
        return self.titre


def nouvel_uuid():
    return uuid.uuid4()
