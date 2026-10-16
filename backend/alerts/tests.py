from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from accounts.models import User
from .models import AlerteSOS

class AlertAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='sosuser',
            password='Password123!',
            role='citoyen'
        )
        self.client.force_authenticate(user=self.user)

    def test_create_sos_alert(self):
        url = '/api/alerts/sos/'
        data = {
            'latitude': 14.6928,
            'longitude': -17.4467
        }
        response = self.client.post(url, data, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(AlerteSOS.objects.count(), 1)

        alert = AlerteSOS.objects.first()
        self.assertEqual(alert.user, self.user)
        self.assertEqual(alert.latitude, 14.6928)
        self.assertEqual(alert.longitude, -17.4467)
        self.assertEqual(alert.statut, 'nouveau')
