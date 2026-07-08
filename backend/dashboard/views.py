from django.shortcuts import render
from django.contrib.auth.decorators import login_required
from incidents.models import Incident

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