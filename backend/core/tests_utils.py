"""Outils communs aux tests SenAlert."""

import io

from django.core.cache import cache
from PIL import Image
from rest_framework.test import APITestCase

from accounts.models import AgentProfil, User
from core.constants import ROLE_AGENT, ROLE_CITOYEN, ROLE_SUPERADMIN, ROLE_SUPERVISEUR
from core.models import Service, Structure
from core.structures import structures_proches

# Position des signalements de test (incident_payload) : Dakar.
POSITION_TEST = (14.70, -17.45)

MDP = 'Motdepasse-Solide-2026'


class SenAlertTestCase(APITestCase):
    def setUp(self):
        cache.clear()  # remet à zéro paramètres en cache et limiteurs de débit

    def citoyen(self, nom='awa', region='dakar'):
        return User.objects.create_user(username=nom, email=f'{nom}@test.sn', password=MDP, role=ROLE_CITOYEN, region=region)

    def structure(self, service='pompiers', position=POSITION_TEST):
        """Structure du service la plus proche de la position (par défaut celle des signalements de test)."""
        return structures_proches(*position, [service], 1)[0][0]

    def structure_par_id(self, pk):
        return Structure.objects.get(pk=pk)

    def agent(self, nom='moussa', service='pompiers', zones=('dakar',), structure=None, disponible=True):
        structure = structure or self.structure(service)
        u = User.objects.create_user(username=nom, email=f'{nom}@test.sn', password=MDP, role=ROLE_AGENT,
                                     first_name=nom.title(), structure=structure)
        AgentProfil.objects.create(user=u, service=Service.objects.get(code=service), zones=list(zones),
                                   disponible=disponible)
        return u

    def superviseur(self, nom='responsable', service='pompiers', structure=None):
        return User.objects.create_user(username=nom, email=f'{nom}@test.sn', password=MDP, role=ROLE_SUPERVISEUR,
                                        structure=structure or self.structure(service))

    def superadmin(self, nom='chef'):
        return User.objects.create_user(username=nom, email=f'{nom}@test.sn', password=MDP, role=ROLE_SUPERADMIN)

    def en_tant_que(self, user):
        self.client.force_authenticate(user=user)
        return user

    def image(self, fmt='PNG', taille=(64, 48)):
        f = io.BytesIO()
        Image.new('RGB', taille, (200, 30, 30)).save(f, fmt)
        f.name = f'photo.{fmt.lower()}'
        f.seek(0)
        return f

    def incident_payload(self, **kw):
        data = {'type_incident': 'incendie', 'description': 'Feu dans un entrepôt', 'latitude': 14.70,
                'longitude': -17.45, 'region': 'dakar', 'precision_gps': 12}
        data.update(kw)
        return data
