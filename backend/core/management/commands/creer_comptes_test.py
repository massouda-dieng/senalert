import secrets
import string
from pathlib import Path

from django.conf import settings
from django.contrib.auth.hashers import make_password
from django.core.management.base import BaseCommand

from accounts.models import AgentProfil, DemandeCompteAgent, User
from core.constants import ROLE_AGENT, ROLE_CITOYEN, ROLE_SUPERADMIN
from core.models import Service

COMPTES = [
    ('citoyen.test@senalert.local', ROLE_CITOYEN, 'Awa', 'Diop', 'dakar', None),
    ('agent.pompiers@senalert.local', ROLE_AGENT, 'Moussa', 'Sarr', 'dakar', 'pompiers'),
    ('agent.police@senalert.local', ROLE_AGENT, 'Fatou', 'Ndiaye', 'dakar', 'police'),
    ('agent.sante@senalert.local', ROLE_AGENT, 'Aminata', 'Fall', 'dakar', 'sante'),
    ('agent.senelec@senalert.local', ROLE_AGENT, 'Ibrahima', 'Ba', 'dakar', 'senelec'),
    ('agent.onas@senalert.local', ROLE_AGENT, 'Ousmane', 'Gueye', 'dakar', 'onas'),
    ('superadmin.test@senalert.local', ROLE_SUPERADMIN, 'Superviseur', 'Test', 'dakar', None),
]


# Demandes d'accès d'exemple (en attente), une par service, pour tester la validation par le superadmin.
DEMANDES = [
    ('demande.police@senalert.local', 'Cheikh', 'Diallo', 'police', 'Commissariat (exemple)', 'Brigadier', ['dakar']),
    ('demande.pompiers@senalert.local', 'Mame', 'Faye', 'pompiers', 'Caserne (exemple)', 'Sapeur', ['thies']),
    ('demande.sante@senalert.local', 'Khady', 'Sow', 'sante', 'Centre de santé (exemple)', 'Infirmière', ['dakar']),
    ('demande.senelec@senalert.local', 'Modou', 'Ndour', 'senelec', 'Agence (exemple)', 'Technicien', ['dakar', 'thies']),
    ('demande.onas@senalert.local', 'Astou', 'Mbaye', 'onas', 'Antenne (exemple)', 'Agent d’exploitation', ['dakar']),
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
        lignes += ['', '# Demandes de compte agent d’exemple (en attente de validation). Après validation,',
                   '# connexion avec l’e-mail et le mot de passe ci-dessous.', '']
        for email, prenom, nom, service, structure, fonction, zones in DEMANDES:
            if User.objects.filter(username__iexact=email).exists():
                lignes.append(f'{"Demande déjà validée":22} {email:34} (mot de passe inchangé)')
                continue
            mdp = mot_de_passe()
            DemandeCompteAgent.objects.filter(email=email, statut='en_attente').delete()
            DemandeCompteAgent.objects.create(
                prenom=prenom, nom=nom, email=email, telephone='', matricule=f'EX-{service.upper()}-001',
                service=Service.objects.get(code=service), structure=structure, fonction=fonction, zones=zones,
                message='[EXEMPLE] Demande fictive créée par creer_comptes_test.', mot_de_passe_hash=make_password(mdp))
            lignes.append(f'{"Demande " + service:22} {email:34} {mdp}')
        # En test, ne jamais écraser le fichier réel de l'utilisateur.
        dossier = Path(settings.MEDIA_ROOT) / 'comptes-test' if settings.TESTING else Path(settings.PROJECT_DIR) / 'backups'
        dossier.mkdir(parents=True, exist_ok=True)
        fichier = dossier / 'comptes_test.txt'
        fichier.write_text('\n'.join(lignes) + '\n', encoding='utf-8')
        fichier.chmod(0o600)
        self.stdout.write(self.style.SUCCESS(f'{len(COMPTES)} comptes de test et {len(DEMANDES)} demandes d’exemple prêts. Identifiants : {fichier}'))
