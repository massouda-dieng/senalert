from django.db import migrations


def avant(apps, schema_editor):
    Incident = apps.get_model('incidents', 'Incident')
    PieceJointe = apps.get_model('incidents', 'PieceJointe')
    Categorie = apps.get_model('core', 'Categorie')
    EvenementDossier = apps.get_model('incidents', 'EvenementDossier')
    services = {c.code: c.service_defaut_id for c in Categorie.objects.all()}
    for inc in Incident.objects.all():
        champs = []
        if not inc.reference:
            inc.reference = f'INC-{inc.date_creation:%Y}-{inc.pk:06d}'
            champs.append('reference')
        if inc.service_id is None and services.get(inc.type_incident):
            inc.service_id = services[inc.type_incident]
            champs.append('service')
        if champs:
            inc.save(update_fields=champs)
        if inc.photo:
            PieceJointe.objects.get_or_create(incident=inc, fichier=inc.photo.name, defaults={
                'taille': 0, 'auteur_id': inc.citoyen_id,
            })
        if not EvenementDossier.objects.filter(incident=inc).exists():
            EvenementDossier.objects.create(
                incident=inc, type='creation', statut_apres=inc.statut, acteur_id=inc.citoyen_id,
                message='Dossier repris lors de la migration v3.', date=inc.date_creation,
            )


class Migration(migrations.Migration):
    dependencies = [
        ('incidents', '0003_dossiers_interventions_evenements'),
        ('core', '0002_donnees_initiales'),
    ]
    operations = [
        migrations.RunPython(avant, migrations.RunPython.noop),
        migrations.RemoveField(model_name='incident', name='photo'),
    ]
