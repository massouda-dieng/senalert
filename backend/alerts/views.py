import logging
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status, permissions
from accounts.models import User, DeviceToken
from .models import AlerteSOS
from .serializers import AlerteSOSSerializer

logger = logging.getLogger(__name__)

def _send_sos_push_notifications(user, latitude, longitude):
    try:
        user_region = getattr(user, 'region', '') or ''
        autorites = User.objects.filter(role='autorite')
        if user_region:
            region_autorites = autorites.filter(region__iexact=user_region)
            if region_autorites.exists():
                autorites = region_autorites

        tokens = list(DeviceToken.objects.filter(user__in=autorites).values_list('token', flat=True))
        if not tokens:
            logger.info("Aucun token FCM trouvé pour les autorités.")
            return

        import firebase_admin
        from firebase_admin import messaging

        if not firebase_admin._apps:
            logger.warning("Firebase Admin SDK non initialisé, notification ignorée.")
            return

        title = "Alerte SOS"
        body = f"Région: {user_region or 'Sénégal'} | Coordonnées GPS: ({latitude}, {longitude})"

        message = messaging.MulticastMessage(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data={
                'type': 'sos_alert',
                'latitude': str(latitude),
                'longitude': str(longitude),
                'region': str(user_region),
            },
            tokens=tokens,
        )
        response = messaging.send_each_for_multicast(message)
        logger.info(f"Notification SOS envoyée : {response.success_count} réussis / {response.failure_count} échecs")
    except Exception as e:
        logger.error(f"Échec envoi notification push SOS: {e}")

class CreateSOSAlertView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        latitude = request.data.get('latitude', 14.6928)
        longitude = request.data.get('longitude', -17.4467)

        try:
            latitude = float(latitude)
            longitude = float(longitude)
        except (ValueError, TypeError):
            latitude = 14.6928
            longitude = -17.4467

        current_user = request.user if request.user and request.user.is_authenticated else None

        alerte = AlerteSOS.objects.create(
            user=current_user,
            latitude=latitude,
            longitude=longitude,
            statut='nouveau'
        )

        _send_sos_push_notifications(current_user, latitude, longitude)

        serializer = AlerteSOSSerializer(alerte)
        return Response(
            {
                'message': 'Alerte SOS enregistrée avec succès.',
                'alerte': serializer.data
            },
            status=status.HTTP_201_CREATED
        )

class ListSOSAlertView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        alertes = AlerteSOS.objects.all()
        serializer = AlerteSOSSerializer(alertes, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
