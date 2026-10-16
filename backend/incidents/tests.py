from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from accounts.models import User
from .models import Incident


class IncidentAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='testuser',
            password='password123',
            role='citoyen'
        )
        self.client.force_authenticate(user=self.user)

    def test_create_incident(self):
        url = '/api/incidents/'
        data = {
            'type_incident': 'accident',
            'description': 'Accident sur la route de Rufisque',
            'latitude': 14.7167,
            'longitude': -17.4667,
            'region': 'dakar'
        }
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Incident.objects.count(), 1)

        incident = Incident.objects.first()
        self.assertEqual(incident.type_incident, 'accident')
        self.assertEqual(incident.region, 'dakar')
        self.assertEqual(incident.citoyen, self.user)

    def test_filter_incidents_by_region_or_status(self):
        Incident.objects.create(
            type_incident='accident',
            description='Accident 1',
            latitude=14.7,
            longitude=-17.4,
            region='dakar',
            statut='nouveau',
            citoyen=self.user
        )
        Incident.objects.create(
            type_incident='incendie',
            description='Incendie 1',
            latitude=14.8,
            longitude=-16.9,
            region='thies',
            statut='resolu',
            citoyen=self.user
        )

        response_dakar = self.client.get('/api/incidents/?region=dakar')
        self.assertEqual(response_dakar.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response_dakar.data), 1)
        self.assertEqual(response_dakar.data[0]['region'], 'dakar')

        response_nouveau = self.client.get('/api/incidents/?statut=nouveau')
        self.assertEqual(response_nouveau.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response_nouveau.data), 1)
        self.assertEqual(response_nouveau.data[0]['statut'], 'nouveau')


class IncidentPermissionTests(TestCase):
    """Tests de la permission IsOwnerOrAdminOrReadOnly sur les incidents."""

    def setUp(self):
        self.client = APIClient()
        self.owner = User.objects.create_user(
            username='owner', password='pass123', role='citoyen'
        )
        self.other = User.objects.create_user(
            username='other', password='pass123', role='citoyen'
        )
        self.admin = User.objects.create_user(
            username='admin_user', password='pass123', role='admin', is_staff=True
        )
        self.incident = Incident.objects.create(
            type_incident='accident',
            description='Test incident',
            latitude=14.7, longitude=-17.4,
            region='dakar', statut='nouveau',
            citoyen=self.owner
        )

    def test_owner_can_update_own_incident(self):
        """Le propriétaire peut modifier son propre incident."""
        self.client.force_authenticate(user=self.owner)
        url = f'/api/incidents/{self.incident.id}/'
        response = self.client.patch(url, {'statut': 'en_cours'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_other_user_cannot_update_incident(self):
        """Un autre citoyen ne peut pas modifier l'incident d'un autre."""
        self.client.force_authenticate(user=self.other)
        url = f'/api/incidents/{self.incident.id}/'
        response = self.client.patch(url, {'statut': 'resolu'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_can_update_any_incident(self):
        """Un admin peut modifier n'importe quel incident."""
        self.client.force_authenticate(user=self.admin)
        url = f'/api/incidents/{self.incident.id}/'
        response = self.client.patch(url, {'statut': 'resolu'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_unauthenticated_cannot_delete(self):
        """Un utilisateur non authentifié ne peut pas supprimer."""
        url = f'/api/incidents/{self.incident.id}/'
        response = self.client.delete(url)
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_any_user_can_read_incident(self):
        """La lecture d'un incident est publique."""
        url = f'/api/incidents/{self.incident.id}/'
        response = self.client.get(url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_autorite_can_refuse_incident(self):
        """Un agent (rôle autorite) peut passer un incident au statut 'refuse'."""
        agent = User.objects.create_user(username='agent', password='pass123', role='autorite')
        self.client.force_authenticate(user=agent)
        url = f'/api/incidents/{self.incident.id}/'
        response = self.client.patch(url, {'statut': 'refuse'}, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.incident.refresh_from_db()
        self.assertEqual(self.incident.statut, 'refuse')

    def test_autorite_cannot_delete_incident(self):
        """Un agent ne peut pas supprimer un incident."""
        agent = User.objects.create_user(username='agent2', password='pass123', role='autorite')
        self.client.force_authenticate(user=agent)
        response = self.client.delete(f'/api/incidents/{self.incident.id}/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_create_urgence_medicale(self):
        """Le type 'urgence_medicale' envoyé par le mobile est accepté."""
        self.client.force_authenticate(user=self.owner)
        response = self.client.post('/api/incidents/', {
            'type_incident': 'urgence_medicale', 'description': 'Malaise',
            'latitude': 14.7, 'longitude': -17.4, 'region': 'saint_louis',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)


class DashboardStatsTests(TestCase):
    """Tests de l'endpoint /dashboard/stats/."""

    def setUp(self):
        self.client = APIClient()
        self.admin = User.objects.create_user(
            username='dash_admin', password='admin123', role='admin'
        )
        self.citoyen = User.objects.create_user(
            username='dash_citoyen', password='pass123', role='citoyen'
        )

    def test_stats_requires_authentication(self):
        """L'accès aux stats nécessite une authentification."""
        response = self.client.get('/dashboard/stats/')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_stats_returns_correct_structure(self):
        """Les stats retournent la structure attendue par le dashboard."""
        self.client.force_authenticate(user=self.admin)
        response = self.client.get('/dashboard/stats/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn('resume', response.data)
        self.assertIn('par_type', response.data)
        self.assertIn('par_region', response.data)
        self.assertIn('derniers_incidents', response.data)
        self.assertIn('dernieres_alertes_sos', response.data)

    def test_stats_counts_match_database(self):
        """Les compteurs retournés correspondent à la base de données."""
        Incident.objects.create(
            type_incident='incendie', description='Feu',
            latitude=14.7, longitude=-17.4,
            region='dakar', statut='nouveau', citoyen=self.citoyen
        )
        self.client.force_authenticate(user=self.admin)
        response = self.client.get('/dashboard/stats/')
        self.assertEqual(response.data['resume']['total_incidents'], 1)
        self.assertEqual(response.data['resume']['incidents_nouveaux'], 1)

