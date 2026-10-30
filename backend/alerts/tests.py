import uuid
from datetime import timedelta

from django.utils import timezone

from core.constants import ACCEPTE, ROLE_SUPERADMIN
from core.tests_utils import SenAlertTestCase
from notifications.models import Notification

from .models import AlerteSOS

URL = '/api/alertes/sos/'


class SOSTests(SenAlertTestCase):
    def setUp(self):
        super().setUp()
        self.awa = self.en_tant_que(self.citoyen('awa', region='dakar'))

    def test_sos_avec_gps(self):
        r = self.client.post(URL, {'latitude': 14.69, 'longitude': -17.44, 'precision_gps': 9}, format='json')
        self.assertEqual(r.status_code, 201, r.data)
        self.assertRegex(r.data['reference'], r'^SOS-\d{4}-\d{6}$')
        self.assertFalse(r.data['deja_enregistree'])
        self.assertEqual(r.data['source_position'], 'gps')
        self.assertEqual(r.data['gravite'], 'critique')

    def test_sos_sans_gps_sans_position_inventee(self):
        r = self.client.post(URL, {}, format='json')
        self.assertEqual(r.status_code, 201)
        self.assertIsNone(r.data['latitude'])
        self.assertEqual(r.data['source_position'], 'indisponible')
        self.assertEqual(r.data['region'], 'dakar', 'région du profil, explicitement')

    def test_idempotence(self):
        cle = str(uuid.uuid4())
        r1 = self.client.post(URL, {'client_request_id': cle}, format='json')
        r2 = self.client.post(URL, {'client_request_id': cle}, format='json')
        self.assertEqual((r1.status_code, r2.status_code), (201, 200))
        self.assertTrue(r2.data['deja_enregistree'])
        self.assertEqual(AlerteSOS.objects.count(), 1)

    def test_double_declenchement_rapproche(self):
        self.client.post(URL, {}, format='json')
        r = self.client.post(URL, {'client_request_id': str(uuid.uuid4())}, format='json')
        self.assertEqual(r.status_code, 200)
        self.assertEqual(AlerteSOS.objects.count(), 1)
        AlerteSOS.objects.update(date_creation=timezone.now() - timedelta(minutes=5))
        self.assertEqual(self.client.post(URL, {}, format='json').status_code, 201)

    def test_authentification_requise(self):
        self.client.force_authenticate(None)
        self.assertEqual(self.client.post(URL, {}, format='json').status_code, 401)

    def test_agents_de_la_zone_et_superadmin_notifies(self):
        pompier = self.agent('pompier', 'pompiers', ['dakar'])
        policier_matam = self.agent('policier', 'police', ['matam'])
        chef = self.superadmin()
        with self.captureOnCommitCallbacks(execute=True):
            self.client.post(URL, {'latitude': 14.69, 'longitude': -17.44}, format='json')
        notifies = set(Notification.objects.filter(type='nouvelle_alerte').values_list('destinataire', flat=True))
        self.assertEqual(notifies, {pompier.pk, chef.pk})
        self.assertNotIn(policier_matam.pk, notifies)

    def test_historique_et_prise_en_charge(self):
        r = self.client.post(URL, {'latitude': 14.69, 'longitude': -17.44}, format='json')
        self.assertEqual(self.client.get(URL).data['count'], 1)
        self.en_tant_que(self.citoyen('autre'))
        self.assertEqual(self.client.get(URL).data['count'], 0)
        policier = self.en_tant_que(self.agent('policier', 'police', ['dakar']))
        r = self.client.post(f"{URL}{r.data['id']}/prendre-en-charge/")
        self.assertEqual(r.data['statut'], ACCEPTE)
        self.assertEqual(r.data['intervention']['agent'], policier.pk)

    def test_superadmin_liste_tout(self):
        self.client.post(URL, {}, format='json')
        self.en_tant_que(self.superadmin())
        self.assertEqual(self.client.get(URL).data['count'], 1)
        self.assertEqual(self.client.get(URL, {'statut': 'nouveau', 'region': 'dakar'}).data['count'], 1)
        self.assertEqual(self.client.get(URL, {'statut': 'resolu'}).data['count'], 0)
