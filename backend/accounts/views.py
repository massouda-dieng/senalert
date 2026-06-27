from rest_framework import generics, permissions
from .models import User, Autorite
from .serializers import RegisterSerializer, UserSerializer, AutoriteSerializer

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

class ProfileView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user

class MesIncidentsAutoriteView(generics.ListAPIView):
    """Retourne les incidents que CETTE autorité doit traiter"""
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        from incidents.models import Incident
        try:
            autorite = self.request.user.autorite
        except Autorite.DoesNotExist:
            return Incident.objects.none()

        types_concernes = Autorite.TYPE_INCIDENT_MAP.get(autorite.type_autorite, [])
        return Incident.objects.filter(
            type_incident__in=types_concernes,
            region=autorite.region
        )

    def list(self, request, *args, **kwargs):
        from incidents.serializers import IncidentSerializer
        queryset = self.get_queryset()
        serializer = IncidentSerializer(queryset, many=True)
        return Response(serializer.data)

from rest_framework.response import Response
