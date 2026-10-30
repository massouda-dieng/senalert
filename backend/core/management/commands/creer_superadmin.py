import getpass

from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.core.management.base import BaseCommand, CommandError

from accounts.models import User
from core.audit import journaliser
from core.constants import ROLE_SUPERADMIN


class Command(BaseCommand):
    help = ("Crée ou promeut un superadministrateur. Seul moyen d'attribuer ce rôle : "
            "il exige un accès au serveur (jamais via l'API ni via Google).")

    def add_arguments(self, parser):
        parser.add_argument('email')
        parser.add_argument('--promouvoir', action='store_true', help='Promouvoir un compte existant.')

    def handle(self, email, promouvoir, **opts):
        email = email.strip().lower()
        user = User.objects.filter(email__iexact=email).first()
        if user and not promouvoir:
            raise CommandError('Ce compte existe déjà : utilisez --promouvoir pour lui donner le rôle superadmin.')
        if not user:
            mdp = getpass.getpass('Mot de passe : ')
            if mdp != getpass.getpass('Confirmation : '):
                raise CommandError('Les mots de passe diffèrent.')
            try:
                validate_password(mdp, User(username=email, email=email))
            except ValidationError as e:
                raise CommandError(' '.join(e.messages))
            user = User.objects.create_user(username=email, email=email, password=mdp)
        user.role = ROLE_SUPERADMIN
        user.is_staff = True
        user.save()
        journaliser(None, 'admin.provisionnement_superadmin', user, {'via': 'ligne de commande'})
        self.stdout.write(self.style.SUCCESS(f'{email} est superadministrateur.'))
