import json
from datetime import date
from pathlib import Path

from django.db import migrations

SERVICES = [
    ('police', 'Police nationale / Gendarmerie', "Sécurité publique, agressions, accidents de la circulation."),
    ('pompiers', 'Sapeurs-pompiers', 'Incendies, secours aux personnes, accidents.'),
    ('sante', 'Santé / SAMU', 'Urgences médicales.'),
    ('senelec', 'SENELEC', "Incidents sur le réseau électrique."),
    ('onas', 'ONAS', "Assainissement et inondations."),
]

# code, libellé, service par défaut, gravité, icône, couleur, ordre
CATEGORIES = [
    ('accident', 'Accident', 'pompiers', 'elevee', 'car-crash', '#EA580C', 1),
    ('incendie', 'Incendie', 'pompiers', 'elevee', 'flame', '#DC2626', 2),
    ('inondation', 'Inondation', 'onas', 'moyenne', 'waves', '#0284C7', 3),
    ('insecurite', 'Insécurité', 'police', 'moyenne', 'shield-alert', '#7C3AED', 4),
    ('agression', 'Agression', 'police', 'elevee', 'hand', '#9333EA', 5),
    ('electricite', 'Problème électrique', 'senelec', 'moyenne', 'zap', '#CA8A04', 6),
    ('urgence_medicale', 'Urgence médicale', 'sante', 'elevee', 'heart-pulse', '#059669', 7),
    ('autre', 'Autre incident', None, 'moyenne', 'circle-help', '#475569', 99),
]


def peupler(apps, schema_editor):
    Service = apps.get_model('core', 'Service')
    Categorie = apps.get_model('core', 'Categorie')
    Parametre = apps.get_model('core', 'Parametre')
    FicheSecours = apps.get_model('core', 'FicheSecours')
    from core.models import Parametre as ParametreReel

    services = {}
    for code, nom, desc in SERVICES:
        services[code], _ = Service.objects.get_or_create(code=code, defaults={'nom': nom, 'description': desc})
    for code, libelle, service, gravite, icone, couleur, ordre in CATEGORIES:
        Categorie.objects.get_or_create(code=code, defaults={
            'libelle': libelle, 'service_defaut': services.get(service), 'gravite_defaut': gravite,
            'icone': icone, 'couleur': couleur, 'ordre': ordre,
        })
    for cle, defaut in ParametreReel.DEFAUTS.items():
        Parametre.objects.get_or_create(cle=cle, defaults={'valeur': defaut['valeur'], 'description': defaut['description']})

    data = json.loads((Path(__file__).resolve().parent.parent / 'data' / 'fiches_secours.json').read_text('utf-8'))
    version = date.fromisoformat(data['version'])
    for f in data['fiches']:
        FicheSecours.objects.get_or_create(slug=f['slug'], defaults={
            'titre': f['titre'], 'categorie': f['categorie'], 'resume': f['resume'], 'etapes': f['etapes'],
            'a_eviter': f.get('a_eviter', []), 'appeler_si': f.get('appeler_si', ''), 'sources': f['sources'],
            'ordre': f.get('ordre', 100), 'date_mise_a_jour': version,
        })


class Migration(migrations.Migration):
    dependencies = [('core', '0001_initial')]
    operations = [migrations.RunPython(peupler, migrations.RunPython.noop)]
