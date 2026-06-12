from rest_framework import generics, permissions
from .models import Incident
from .serializers import IncidentSerializer

class IncidentListCreateView(generics.ListCreateAPIView):
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
        serializer.save(citoyen=self.request.user)

class IncidentDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Incident.objects.all()
    serializer_class = IncidentSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
