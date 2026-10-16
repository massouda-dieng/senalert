from rest_framework import generics, permissions
from .models import Incident
from .serializers import IncidentSerializer
from .permissions import IsOwnerOrAdminOrReadOnly


class IncidentListCreateView(generics.ListCreateAPIView):
    """
    GET  : Liste de tous les incidents (public en lecture, authentifié pour créer)
    POST : Création d'un incident (authentification requise)
    Filtres disponibles : ?region=dakar&type_incident=incendie&statut=nouveau
    """
    serializer_class = IncidentSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        queryset = Incident.objects.all()
        region = self.request.query_params.get('region')
        type_incident = self.request.query_params.get('type_incident')
        statut = self.request.query_params.get('statut')
        if region:
            queryset = queryset.filter(region=region)
        if type_incident:
            queryset = queryset.filter(type_incident=type_incident)
        if statut:
            queryset = queryset.filter(statut=statut)
        return queryset

    def perform_create(self, serializer):
        # Associe l'incident au citoyen connecté
        serializer.save(citoyen=self.request.user)


class IncidentDetailView(generics.RetrieveUpdateDestroyAPIView):
    """
    GET    : Détail d'un incident (public)
    PUT/PATCH : Modification (propriétaire ou admin uniquement)
    DELETE : Suppression (propriétaire ou admin uniquement)
    Les autorités peuvent mettre à jour le statut via PATCH.
    """
    queryset = Incident.objects.all()
    serializer_class = IncidentSerializer
    permission_classes = [IsOwnerOrAdminOrReadOnly]
