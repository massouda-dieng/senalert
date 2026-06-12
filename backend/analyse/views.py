from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from incidents.models import Incident
from .analyzer import analyser_zones_risque


class ZonesRisqueView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        incidents_qs = Incident.objects.all()
        resultats = analyser_zones_risque(incidents_qs)

        niveau_filtre = request.query_params.get('niveau')
        region_filtre = request.query_params.get('region')

        if niveau_filtre:
            resultats = [r for r in resultats if r['niveau'] == niveau_filtre]

        if region_filtre:
            resultats = [r for r in resultats if r['region'] == region_filtre]

        return Response({
            'status': 'success',
            'total_zones_analysees': len(resultats),
            'zones': resultats,
        })