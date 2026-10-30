from django.db import migrations


def avant(apps, schema_editor):
    AlerteSOS = apps.get_model('alerts', 'AlerteSOS')
    AlerteSOS.objects.filter(statut='traite').update(statut='resolu')
    for a in AlerteSOS.objects.filter(reference__isnull=True):
        a.reference = f'SOS-{a.date_creation:%Y}-{a.pk:06d}'
        a.save(update_fields=['reference'])


def arriere(apps, schema_editor):
    apps.get_model('alerts', 'AlerteSOS').objects.filter(statut='resolu').update(statut='traite')


class Migration(migrations.Migration):
    dependencies = [('alerts', '0004_dossier_sos')]
    operations = [migrations.RunPython(avant, arriere)]
