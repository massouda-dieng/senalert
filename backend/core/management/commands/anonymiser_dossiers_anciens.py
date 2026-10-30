from django.core.management.base import BaseCommand
from django.utils import timezone

from alerts.models import AlerteSOS
from core.audit import journaliser
from core.constants import STATUTS_FINAUX
from core.models import Parametre
from incidents.models import Incident, PieceJointe


class Command(BaseCommand):
    help = ("Politique de conservation : anonymise les dossiers clos depuis plus de N jours "
            "(paramètre « conservation »). Utilisez --appliquer pour exécuter ; sinon simulation.")

    def add_arguments(self, parser):
        parser.add_argument('--appliquer', action='store_true')

    def handle(self, appliquer, **opts):
        jours = (Parametre.get('conservation') or {}).get('jours_avant_anonymisation', 730)
        limite = timezone.now() - timezone.timedelta(days=jours)
        incidents = Incident.objects.filter(statut__in=STATUTS_FINAUX, date_cloture__lt=limite).exclude(citoyen=None)
        sos = AlerteSOS.objects.filter(statut__in=STATUTS_FINAUX, date_cloture__lt=limite).exclude(citoyen=None)
        self.stdout.write(f'{incidents.count()} incident(s) et {sos.count()} SOS clos depuis plus de {jours} jours.')
        if not appliquer:
            self.stdout.write('Simulation uniquement. Ajoutez --appliquer pour anonymiser.')
            return
        for pj in PieceJointe.objects.filter(incident__in=incidents):
            pj.fichier.delete(save=False)
            pj.delete()
        n1 = incidents.update(citoyen=None, description='[anonymisé]', adresse='', infos_complementaires='')
        n2 = sos.update(citoyen=None, message='', adresse='')
        journaliser(None, 'conservation.anonymisation', details={'incidents': n1, 'sos': n2, 'jours': jours})
        self.stdout.write(self.style.SUCCESS(f'Anonymisés : {n1} incident(s), {n2} SOS.'))
