from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from incidents.models import Incident
from alerts.models import AlerteSOS
from accounts.models import User


class DashboardStatsView(APIView):
    """
    Endpoint principal du dashboard administrateur.
    Retourne les indicateurs agrégés en temps réel depuis la base de données.
    Authentification requise (rôle admin ou autorite).
    GET /dashboard/stats/
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        maintenant = timezone.now()
        il_y_a_7j = maintenant - timedelta(days=7)
        il_y_a_30j = maintenant - timedelta(days=30)

        # --- Compteurs principaux ---
        total_incidents = Incident.objects.count()
        incidents_nouveaux = Incident.objects.filter(statut='nouveau').count()
        incidents_en_cours = Incident.objects.filter(statut='en_cours').count()
        incidents_resolus = Incident.objects.filter(statut='resolu').count()
        total_alertes_sos = AlerteSOS.objects.count()
        alertes_sos_nouvelles = AlerteSOS.objects.filter(statut='nouveau').count()
        total_citoyens = User.objects.filter(role='citoyen').count()

        # --- Incidents récents (7 jours) ---
        incidents_recents = Incident.objects.filter(
            date_creation__gte=il_y_a_7j
        ).count()

        # --- Répartition par type ---
        from django.db.models import Count
        par_type = list(
            Incident.objects.values('type_incident')
            .annotate(total=Count('id'))
            .order_by('-total')
        )

        # --- Répartition par région ---
        par_region = list(
            Incident.objects.values('region')
            .annotate(total=Count('id'))
            .order_by('-total')[:10]
        )

        # --- Répartition par statut ---
        par_statut = {
            'nouveau': incidents_nouveaux,
            'en_cours': incidents_en_cours,
            'resolu': incidents_resolus,
        }

        # --- 10 derniers incidents pour le flux ---
        from incidents.serializers import IncidentSerializer
        derniers_incidents = Incident.objects.order_by('-date_creation')[:10]
        derniers_incidents_data = IncidentSerializer(derniers_incidents, many=True).data

        # --- 10 dernières alertes SOS ---
        from alerts.serializers import AlerteSOSSerializer
        dernieres_alertes = AlerteSOS.objects.order_by('-date_creation')[:10]
        dernieres_alertes_data = AlerteSOSSerializer(dernieres_alertes, many=True).data

        return Response({
            'resume': {
                'total_incidents': total_incidents,
                'incidents_nouveaux': incidents_nouveaux,
                'incidents_en_cours': incidents_en_cours,
                'incidents_resolus': incidents_resolus,
                'incidents_recents_7j': incidents_recents,
                'total_alertes_sos': total_alertes_sos,
                'alertes_sos_nouvelles': alertes_sos_nouvelles,
                'total_citoyens': total_citoyens,
            },
            'par_type': par_type,
            'par_region': par_region,
            'par_statut': par_statut,
            'derniers_incidents': derniers_incidents_data,
            'dernieres_alertes_sos': dernieres_alertes_data,
            'periode_analyse': {
                'debut': il_y_a_30j.isoformat(),
                'fin': maintenant.isoformat(),
            }
        })

@login_required
def dashboard_view(request):
    total_alertes = Incident.objects.count()
    en_attente = Incident.objects.filter(statut='nouveau').count()
    en_cours = Incident.objects.filter(statut='en_cours').count()
    traitees = Incident.objects.filter(statut='resolu').count()
    alertes_recentes = Incident.objects.order_by('-date_creation')[:10]

    context = {
        'total_alertes': total_alertes,
        'en_attente': en_attente,
        'en_cours': en_cours,
        'traitees': traitees,
        'alertes_recentes': alertes_recentes,
    }
    return render(request, 'dashboard/index.html', context)