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


import requests
from django.conf import settings
from rest_framework import status

class AIAssistantView(APIView):
    permission_classes = []

    def post(self, request):
        prompt = request.data.get('prompt', '').strip()
        if not prompt:
            return Response({'error': 'Le champ prompt est requis.'}, status=status.HTTP_400_BAD_REQUEST)

        groq_key = getattr(settings, 'GROQ_API_KEY', '')
        if not groq_key:
            return Response({'error': 'Clé API Groq non configurée.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        try:
            res = requests.post(
                'https://api.groq.com/openai/v1/chat/completions',
                headers={
                    'Authorization': f'Bearer {groq_key}',
                    'Content-Type': 'application/json',
                },
                json={
                    'model': 'llama-3.3-70b-versatile',
                    'messages': [
                        {
                            'role': 'system',
                            'content': 'Tu es SenAlert AI, l\'assistant virtuel d\'urgence officiel de la plateforme de secours de la République du Sénégal. Réponds avec concision, clarté et professionnalisme. Indique toujours les numéros vitaux (SAMU 15, Pompiers 18, Police 17) quand nécessaire.',
                        },
                        {
                            'role': 'user',
                            'content': prompt,
                        }
                    ],
                    'max_tokens': 500,
                    'temperature': 0.7,
                },
                timeout=10,
            )
            if res.status_code == 200:
                data = res.json()
                reply = data['choices'][0]['message']['content']
                return Response({'reply': reply, 'status': 'success'}, status=status.HTTP_200_OK)
            else:
                return Response({'error': f'Erreur Groq API: {res.status_code}'}, status=status.HTTP_502_BAD_GATEWAY)
        except Exception as e:
            return Response({'error': f'Exception Groq: {str(e)}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)