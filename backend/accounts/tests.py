from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework import status
from .models import User


class AccountAPITests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_register_and_login_success(self):
        """Inscription puis connexion : doit retourner access + refresh."""
        reg_response = self.client.post('/api/auth/register/', {
            'username': 'citoyen1', 'password': 'Password123!',
            'role': 'citoyen', 'telephone': '+221770000000', 'region': 'Dakar'
        }, format='json')
        self.assertEqual(reg_response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(User.objects.filter(username='citoyen1').exists())

        login_response = self.client.post('/api/auth/login/', {
            'username': 'citoyen1', 'password': 'Password123!'
        }, format='json')
        self.assertEqual(login_response.status_code, status.HTTP_200_OK)
        self.assertIn('access', login_response.data)
        self.assertIn('refresh', login_response.data)

    def test_register_weak_password_rejected(self):
        """Un mot de passe trop court doit être refusé."""
        response = self.client.post('/api/auth/register/', {
            'username': 'testuser', 'password': '123',
            'role': 'citoyen'
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_duplicate_username_rejected(self):
        """Deux utilisateurs avec le même identifiant doivent être refusés."""
        data = {'username': 'dupuser', 'password': 'Password123!', 'role': 'citoyen'}
        self.client.post('/api/auth/register/', data, format='json')
        response = self.client.post('/api/auth/register/', data, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_login_wrong_password(self):
        """Mauvais mot de passe : doit retourner 401."""
        User.objects.create_user(username='user2', password='CorrectPwd123!')
        response = self.client.post('/api/auth/login/', {
            'username': 'user2', 'password': 'wrongpassword'
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_profile_requires_auth(self):
        """Accès au profil sans token : 401."""
        response = self.client.get('/api/auth/profile/')
        self.assertIn(response.status_code, [status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN])

    def test_profile_authenticated(self):
        """Un utilisateur authentifié peut lire son profil."""
        user = User.objects.create_user(username='profuser', password='Pass123!')
        self.client.force_authenticate(user=user)
        response = self.client.get('/api/auth/profile/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data['username'], 'profuser')

    def test_device_token_registration(self):
        """Un utilisateur peut enregistrer son token FCM."""
        user = User.objects.create_user(username='devuser', password='Pass123!')
        self.client.force_authenticate(user=user)
        response = self.client.post('/api/auth/device-token/', {
            'token': 'fcm_test_token_abc123'
        }, format='json')
        self.assertIn(response.status_code, [status.HTTP_200_OK, status.HTTP_201_CREATED])
