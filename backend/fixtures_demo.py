import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from incidents.models import Incident

incidents_demo = [
    {'type_incident':'accident','description':'Collision entre deux véhicules sur l autoroute','latitude':14.6928,'longitude':-17.4467,'region':'dakar','statut':'nouveau'},
    {'type_incident':'inondation','description':'Quartier Pikine inondé après fortes pluies','latitude':14.7500,'longitude':-17.3900,'region':'dakar','statut':'en_cours'},
    {'type_incident':'incendie','description':'Incendie marché HLM Dakar','latitude':14.7200,'longitude':-17.4600,'region':'dakar','statut':'nouveau'},
    {'type_incident':'electricite','description':'Coupure générale secteur Almadies','latitude':14.7400,'longitude':-17.5100,'region':'dakar','statut':'en_cours'},
    {'type_incident':'insecurite','description':'Rixe dans le quartier Médina','latitude':14.6800,'longitude':-17.4400,'region':'dakar','statut':'resolu'},
    {'type_incident':'accident','description':'Renversement camion RN1','latitude':14.8000,'longitude':-16.9500,'region':'thies','statut':'nouveau'},
    {'type_incident':'inondation','description':'Inondation cité Lamy Thiès','latitude':14.7833,'longitude':-16.9333,'region':'thies','statut':'en_cours'},
    {'type_incident':'incendie','description':'Début incendie forêt Thiès','latitude':14.8100,'longitude':-16.9100,'region':'thies','statut':'resolu'},
    {'type_incident':'inondation','description':'Débordement fleuve Sénégal','latitude':16.0179,'longitude':-16.4897,'region':'saint_louis','statut':'nouveau'},
    {'type_incident':'accident','description':'Carambolage 4 véhicules RN2','latitude':16.0300,'longitude':-16.5000,'region':'saint_louis','statut':'en_cours'},
    {'type_incident':'electricite','description':'Panne centrale électrique Podor','latitude':16.6500,'longitude':-14.9500,'region':'saint_louis','statut':'nouveau'},
    {'type_incident':'accident','description':'Accident camion citerne','latitude':14.1500,'longitude':-16.0700,'region':'kaolack','statut':'resolu'},
    {'type_incident':'inondation','description':'Inondation zone basse Kaolack','latitude':14.1500,'longitude':-16.0800,'region':'kaolack','statut':'en_cours'},
    {'type_incident':'insecurite','description':'Vol à main armée marché','latitude':12.5500,'longitude':-16.2700,'region':'ziguinchor','statut':'nouveau'},
    {'type_incident':'incendie','description':'Incendie forêt Casamance','latitude':12.6000,'longitude':-16.3000,'region':'ziguinchor','statut':'en_cours'},
    {'type_incident':'accident','description':'Renversement bus Tambacounda','latitude':13.7700,'longitude':-13.6700,'region':'tambacounda','statut':'resolu'},
    {'type_incident':'electricite','description':'Coupure électricité Louga','latitude':15.6200,'longitude':-16.2200,'region':'louga','statut':'nouveau'},
    {'type_incident':'inondation','description':'Inondation champs Fatick','latitude':14.3400,'longitude':-16.4100,'region':'fatick','statut':'en_cours'},
    {'type_incident':'accident','description':'Accident moto Kolda','latitude':12.8900,'longitude':-14.9400,'region':'kolda','statut':'nouveau'},
    {'type_incident':'electricite','description':'Transformateur en feu Diourbel','latitude':14.6500,'longitude':-16.2300,'region':'diourbel','statut':'en_cours'},
]

Incident.objects.all().delete()
for data in incidents_demo:
    Incident.objects.create(**data)

print(f"✅ {len(incidents_demo)} incidents de démo créés !")
