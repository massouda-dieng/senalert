from django.shortcuts import render
from django.http import JsonResponse
from incidents.models import Incident

def dashboard_view(request):
    return render(request, 'dashboard/index.html')
