from django.db import migrations


def creer(apps, schema_editor):
    from core.models import Parametre as ParametreReel
    defaut = ParametreReel.DEFAUTS['sms_secours']
    apps.get_model('core', 'Parametre').objects.get_or_create(
        cle='sms_secours', defaults={'valeur': defaut['valeur'], 'description': defaut['description']})


class Migration(migrations.Migration):
    dependencies = [('core', '0002_donnees_initiales')]
    operations = [migrations.RunPython(creer, migrations.RunPython.noop)]
