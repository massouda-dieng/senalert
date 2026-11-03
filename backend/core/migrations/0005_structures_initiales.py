"""Crée les structures (OpenStreetMap + agences SENELEC/ONAS) et rattache agents et dossiers existants."""
from django.db import migrations

from core.constants import REGIONS
from core.geo import distance_m
from core.structures_osm import structures_osm

SERVICES_SOS = ('pompiers', 'sante', 'police')


def la_plus_proche(structures, lat, lng, services):
    candidates = [s for s in structures if s.service.code in services]
    return min(candidates, key=lambda s: distance_m(lat, lng, s.latitude, s.longitude), default=None)


def position(dossier):
    if dossier.latitude is not None and dossier.longitude is not None:
        return dossier.latitude, dossier.longitude
    r = REGIONS.get(dossier.region) or REGIONS['dakar']
    return r['lat'], r['lng']


def creer(apps, schema_editor):
    Service = apps.get_model('core', 'Service')
    Structure = apps.get_model('core', 'Structure')
    User = apps.get_model('accounts', 'User')
    Intervention = apps.get_model('incidents', 'Intervention')
    services = {s.code: s for s in Service.objects.all()}
    Structure.objects.bulk_create([
        Structure(**{**d, 'service': services[d['service']]}) for d in structures_osm() if d['service'] in services
    ])
    structures = list(Structure.objects.select_related('service'))
    if not structures:
        return

    for user in User.objects.filter(role='agent', structure__isnull=True):
        profil = getattr(user, 'profil_agent', None)
        if not profil or not profil.service_id:
            continue
        zone = (profil.zones or [user.region or 'dakar'])[0]
        r = REGIONS.get(zone) or REGIONS['dakar']
        user.structure = la_plus_proche(structures, r['lat'], r['lng'], [profil.service.code])
        user.save(update_fields=['structure'])

    for modele, champ in (('incidents', 'Incident'), ('alerts', 'AlerteSOS')):
        Dossier = apps.get_model(modele, champ)
        lien = 'incident' if champ == 'Incident' else 'alerte'
        agents = {i[lien + '_id']: i['agent__structure_id'] for i in Intervention.objects.filter(
            **{f'{lien}__isnull': False, 'agent__structure__isnull': False}).values(lien + '_id', 'agent__structure_id')}
        for d in Dossier.objects.filter(structure__isnull=True).select_related('service'):
            if d.pk in agents:
                d.structure_id = agents[d.pk]
            else:
                lat, lng = position(d)
                codes = [d.service.code] if d.service_id else SERVICES_SOS
                s = la_plus_proche(structures, lat, lng, codes)
                d.structure_id = s.pk if s else None
            d.save(update_fields=['structure'])


def supprimer(apps, schema_editor):
    apps.get_model('core', 'Structure').objects.all().delete()


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0004_structure'),
        ('accounts', '0008_agentprofil_disponible_user_structure_and_more'),
        ('incidents', '0007_incident_structure'),
        ('alerts', '0007_alertesos_structure'),
    ]

    operations = [migrations.RunPython(creer, supprimer)]
