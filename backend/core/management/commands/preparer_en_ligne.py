"""Prépare une plateforme en ligne (Render) sans console : lancé à chaque démarrage, il ne fait que créer ce qui manque.

- SENALERT_ADMIN_EMAIL et SENALERT_ADMIN_MOT_DE_PASSE : compte administrateur de la plateforme.
- SENALERT_MOT_DE_PASSE_DEMO : comptes de démonstration de la soutenance (Awa, Cheikh, Moussa…), tous avec ce mot de passe.

Un compte qui existe déjà n'est jamais modifié : un mot de passe changé depuis l'application est conservé.
Sans ces variables, la commande ne fait rien.
"""
import os

from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.core.management.base import BaseCommand, CommandError

from accounts.models import AgentProfil, User
from core.constants import ROLE_AGENT, ROLE_SUPERADMIN
from core.management.commands.creer_comptes_test import COMPTES, structure_de_test


def verifier(mdp, email):
    try:
        validate_password(mdp, User(username=email, email=email))
    except ValidationError as e:
        raise CommandError(f'Mot de passe refusé pour {email} : {" ".join(e.messages)}') from e


class Command(BaseCommand):
    help = "Crée l'administrateur et, si demandé, les comptes de démonstration, à partir des variables d'environnement."

    def handle(self, **opts):
        crees = 0
        email = os.environ.get('SENALERT_ADMIN_EMAIL', '').strip()
        mdp = os.environ.get('SENALERT_ADMIN_MOT_DE_PASSE', '')
        if email and mdp and not User.objects.filter(username=email).exists():
            verifier(mdp, email)
            user = User.objects.create_user(username=email, email=email, password=mdp)
            user.role, user.is_staff, user.doit_changer_mot_de_passe = ROLE_SUPERADMIN, True, False
            user.save()
            crees += 1

        mdp_demo = os.environ.get('SENALERT_MOT_DE_PASSE_DEMO', '')
        if mdp_demo:
            for email, role, prenom, nom, service, fonction in COMPTES:
                if User.objects.filter(username=email).exists():
                    continue
                verifier(mdp_demo, email)
                structure = structure_de_test(service) if service else None
                user = User(username=email, email=email, role=role, first_name=prenom, last_name=nom,
                            region=structure.region if structure else 'dakar', structure=structure,
                            is_staff=role == ROLE_SUPERADMIN, is_active=True, doit_changer_mot_de_passe=False)
                user.set_password(mdp_demo)
                user.save()
                if role == ROLE_AGENT:
                    AgentProfil.objects.update_or_create(user=user, defaults={
                        'service': structure.service, 'zones': [structure.region], 'fonction': fonction, 'disponible': True,
                    })
                crees += 1
        self.stdout.write(self.style.SUCCESS(f'Préparation en ligne : {crees} compte(s) créé(s).'))
