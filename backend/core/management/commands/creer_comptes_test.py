import secrets
import string
from pathlib import Path

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from accounts.models import AgentProfil, User
from core.constants import REGIONS, ROLE_AGENT, ROLE_CITOYEN, ROLE_SUPERADMIN, ROLE_SUPERVISEUR
from core.structures import structures_proches

# (e-mail, rôle, prénom, nom, service de la structure, fonction). Agents et superviseurs sont rattachés
# à la structure de leur service la plus proche du centre de Dakar.
COMPTES = [
    ('citoyen.test@senalert.local', ROLE_CITOYEN, 'Awa', 'Diop', None, ''),
    ('agent.pompiers@senalert.local', ROLE_AGENT, 'Moussa', 'Sarr', 'pompiers', 'Sapeur-pompier'),
    ('agent2.pompiers@senalert.local', ROLE_AGENT, 'Mame', 'Faye', 'pompiers', 'Sergent sapeur-pompier'),
    ('agent.police@senalert.local', ROLE_AGENT, 'Fatou', 'Ndiaye', 'police', 'Policière'),
    ('agent.sante@senalert.local', ROLE_AGENT, 'Aminata', 'Fall', 'sante', 'Infirmière urgentiste'),
    ('agent.senelec@senalert.local', ROLE_AGENT, 'Ibrahima', 'Ba', 'senelec', 'Technicien SENELEC'),
    ('agent.onas@senalert.local', ROLE_AGENT, 'Ousmane', 'Gueye', 'onas', 'Agent d’exploitation ONAS'),
    ('superviseur.pompiers@senalert.local', ROLE_SUPERVISEUR, 'Cheikh', 'Diallo', 'pompiers', ''),
    ('superviseur.police@senalert.local', ROLE_SUPERVISEUR, 'Khady', 'Sow', 'police', ''),
    ('superviseur.sante@senalert.local', ROLE_SUPERVISEUR, 'Astou', 'Mbaye', 'sante', ''),
    ('superviseur.senelec@senalert.local', ROLE_SUPERVISEUR, 'Modou', 'Ndour', 'senelec', ''),
    ('superviseur.onas@senalert.local', ROLE_SUPERVISEUR, 'Aïssatou', 'Kane', 'onas', ''),
    ('superadmin.test@senalert.local', ROLE_SUPERADMIN, 'Superviseur', 'National', None, ''),
]


def structure_de_test(service):
    dakar = REGIONS['dakar']
    proches = structures_proches(dakar['lat'], dakar['lng'], [service], 1)
    if not proches:
        raise CommandError(f'Aucune structure « {service} » : appliquez les migrations (python manage.py migrate).')
    return proches[0][0]


def mot_de_passe():
    alphabet = string.ascii_letters + string.digits
    return 'Sa-' + ''.join(secrets.choice(alphabet) for _ in range(14))


class Command(BaseCommand):
    help = ("Crée (ou réinitialise) les comptes de TEST de chaque rôle avec des mots de passe aléatoires. "
            "Les identifiants sont écrits dans backups/comptes_test.txt (hors Git, lecture propriétaire seulement).")

    def handle(self, **opts):
        if not (settings.DEBUG or settings.TESTING):
            raise CommandError('Comptes de test interdits en production (DEBUG=False).')
        lignes = ['# Comptes de TEST SenAlert — ne pas utiliser en production', '']
        for email, role, prenom, nom, service, fonction in COMPTES:
            mdp = mot_de_passe()
            structure = structure_de_test(service) if service else None
            user, _ = User.objects.get_or_create(username=email, defaults={'email': email})
            user.email, user.role, user.first_name, user.last_name = email, role, prenom, nom
            user.region = structure.region if structure else 'dakar'
            user.structure = structure
            user.is_staff = role == ROLE_SUPERADMIN
            user.is_active = True
            user.doit_changer_mot_de_passe = False
            user.set_password(mdp)
            user.save()
            if role == ROLE_AGENT:
                AgentProfil.objects.update_or_create(user=user, defaults={
                    'service': structure.service, 'zones': [structure.region], 'fonction': fonction, 'disponible': True,
                })
            lignes.append(f'{user.get_role_display():26} {email:38} {mdp}'
                          + (f'   ({structure.nom})' if structure else ''))
        # En test, ne jamais écraser le fichier réel de l'utilisateur.
        dossier = Path(settings.MEDIA_ROOT) / 'comptes-test' if settings.TESTING else Path(settings.PROJECT_DIR) / 'backups'
        dossier.mkdir(parents=True, exist_ok=True)
        fichier = dossier / 'comptes_test.txt'
        fichier.write_text('\n'.join(lignes) + '\n', encoding='utf-8')
        fichier.chmod(0o600)
        self.stdout.write(self.style.SUCCESS(f'{len(COMPTES)} comptes de test prêts. Identifiants : {fichier}'))
