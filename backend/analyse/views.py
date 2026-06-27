from .analyzer import analyser_zones_risque, calculer_statistiques


class StatistiquesView(APIView):
    """
    GET /api/analyse/statistiques/
    Retourne des statistiques globales sur tous les incidents.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        incidents_qs = Incident.objects.all()
        stats = calculer_statistiques(incidents_qs)

        return Response({
            'status': 'success',
            **stats,
        })