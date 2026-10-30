from django.db import migrations

ROLES = {'admin': 'superadmin', 'autorite': 'agent'}
SERVICE_PAR_TYPE = {'pompiers': 'pompiers', 'police': 'police', 'sante': 'sante', 'senelec': 'senelec', 'onas': 'onas'}
REGIONS = {
    'dakar', 'thies', 'saint_louis', 'diourbel', 'louga', 'fatick', 'kaolack', 'kaffrine',
    'matam', 'tambacounda', 'kedougou', 'kolda', 'sedhiou', 'ziguinchor',
}


def normaliser_region(valeur):
    v = (valeur or '').strip().lower()
    for a, b in (('é', 'e'), ('è', 'e'), ('-', '_'), (' ', '_')):
        v = v.replace(a, b)
    return v if v in REGIONS else ''


def avant(apps, schema_editor):
    User = apps.get_model('accounts', 'User')
    Autorite = apps.get_model('accounts', 'Autorite')
    AgentProfil = apps.get_model('accounts', 'AgentProfil')
    Service = apps.get_model('core', 'Service')

    for ancien, nouveau in ROLES.items():
        User.objects.filter(role=ancien).update(role=nouveau)
    for u in User.objects.exclude(region=''):
        r = normaliser_region(u.region)
        if r != u.region:
            u.region = r
            u.save(update_fields=['region'])

    # Copie des anciens profils « Autorite » vers AgentProfil (aucune perte).
    for a in Autorite.objects.all():
        service = Service.objects.filter(code=SERVICE_PAR_TYPE.get(a.type_autorite, '')).first()
        region = normaliser_region(a.region)
        AgentProfil.objects.update_or_create(user_id=a.user_id, defaults={
            'service': service, 'zones': [region] if region else [], 'fonction': a.nom_service,
        })
        User.objects.filter(pk=a.user_id).update(role='agent')
    for u in User.objects.filter(role='agent'):
        AgentProfil.objects.get_or_create(user=u, defaults={'zones': [u.region] if u.region else []})


def arriere(apps, schema_editor):
    User = apps.get_model('accounts', 'User')
    for ancien, nouveau in ROLES.items():
        User.objects.filter(role=nouveau).update(role=ancien)


class Migration(migrations.Migration):
    dependencies = [
        ('accounts', '0004_roles_agentprofil_compteexterne'),
        ('core', '0002_donnees_initiales'),
    ]
    operations = [migrations.RunPython(avant, arriere)]
