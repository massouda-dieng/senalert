import secrets
import string
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand

from accounts.models import AgentProfil, User
from core.constants import ROLE_AGENT, ROLE_CITOYEN, ROLE_SUPERADMIN
from core.models import Service

COMPTES = [
    ('citoyen.test@senalert.local', ROLE_CITOYEN, 'Awa', 'Diop', 'dakar', None),
    ('agent.pompiers@senalert.local', ROLE_AGENT, 'Moussa', 'Sarr', 'dakar', 'pompiers'),
    ('agent.police@senalert.local', ROLE_AGENT, 'Fatou', 'Ndiaye', 'dakar', 'police'),
    ('superadmin.test@senalert.local', ROLE_SUPERADMIN, 'Superviseur', 'Test', 'dakar', None),
]


def mot_de_passe():
    alphabet = string.ascii_letters + string.digits
    return 'Sa-' + ''.join(secrets.choice(alphabet) for _ in range(14))


class Command(BaseCommand):
    help = ("Crée (ou réinitialise) les comptes de TEST des trois rôles avec des mots de passe aléatoires. "
            "Les identifiants sont écrits dans backups/comptes_test.txt (hors Git, lecture propriétaire seulement).")

    def handle(self, **opts):
        lignes = ['# Comptes de TEST SenAlert — ne pas utiliser en production', '']
        for email, role, prenom, nom, region, service in COMPTES:
            mdp = mot_de_passe()
            user, _ = User.objects.get_or_create(username=email, defaults={'email': email})
            user.email, user.role, user.first_name, user.last_name, user.region = email, role, prenom, nom, region
            user.is_staff = role == ROLE_SUPERADMIN
            user.is_active = True
            user.doit_changer_mot_de_passe = False
            user.set_password(mdp)
            user.save()
            if role == ROLE_AGENT:
                AgentProfil.objects.update_or_create(user=user, defaults={
                    'service': Service.objects.get(code=service), 'zones': ['dakar', 'thies'], 'fonction': 'Compte de test',
                })
            lignes.append(f'{user.get_role_display():22} {email:34} {mdp}')
        # En test, ne jamais écraser le fichier réel de l'utilisateur.
        dossier = Path(settings.MEDIA_ROOT) / 'comptes-test' if settings.TESTING else Path(settings.PROJECT_DIR) / 'backups'
        dossier.mkdir(parents=True, exist_ok=True)
        fichier = dossier / 'comptes_test.txt'
        fichier.write_text('\n'.join(lignes) + '\n', encoding='utf-8')
        fichier.chmod(0o600)
        self.stdout.write(self.style.SUCCESS(f'{len(COMPTES)} comptes de test prêts. Identifiants : {fichier}'))
