import csv
import io

from django.conf import settings
from django.http import FileResponse, Http404, HttpResponse
from django.utils import timezone
from django.views.decorators.clickjacking import xframe_options_sameorigin
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework.response import Response
from rest_framework.views import APIView

from alerts.models import AlerteSOS
from analyse.views import calculer
from core.audit import journaliser
from core.permissions import EstAgent, EstSuperAdmin
from incidents.models import Incident
from incidents.views import FiltreIncident

from . import stats

COLONNES = ['reference', 'date_creation', 'categorie', 'region', 'statut', 'gravite', 'service', 'agent',
            'date_prise_en_charge', 'delai_prise_en_charge_min', 'date_cloture', 'adresse', 'latitude', 'longitude',
            'doublon_potentiel_de']


class StatistiquesView(APIView):
    """Indicateurs de supervision (superadmin). Filtres : date_debut, date_fin, region, type_incident, service, granularite."""

    permission_classes = [EstSuperAdmin]

    @extend_schema(responses=OpenApiTypes.OBJECT)
    def get(self, request):
        return Response(stats.statistiques(request.query_params))


class ActiviteAgentView(APIView):
    permission_classes = [EstAgent]

    @extend_schema(responses=OpenApiTypes.OBJECT)
    def get(self, request):
        return Response(stats.activite_agent(request.user))


def lignes_export(request):
    qs = Incident.objects.select_related('service', 'intervention__agent', 'doublon_potentiel_de').order_by('-date_creation')
    qs = FiltreIncident(request.query_params, queryset=qs, request=request).qs
    for inc in qs.iterator(chunk_size=500):
        inter = getattr(inc, 'intervention', None)
        delai = (round((inc.date_prise_en_charge - inc.date_creation).total_seconds() / 60, 1)
                 if inc.date_prise_en_charge else '')
        # Aucune donnée personnelle du citoyen n'est exportée (minimisation).
        yield [
            inc.reference, timezone.localtime(inc.date_creation).strftime('%Y-%m-%d %H:%M'), inc.type_incident,
            inc.get_region_display(), inc.get_statut_display(), inc.get_gravite_display(),
            inc.service.nom if inc.service else '', inter.agent.nom_affiche if inter and inter.agent else '',
            timezone.localtime(inc.date_prise_en_charge).strftime('%Y-%m-%d %H:%M') if inc.date_prise_en_charge else '',
            delai, timezone.localtime(inc.date_cloture).strftime('%Y-%m-%d %H:%M') if inc.date_cloture else '',
            inc.adresse, inc.latitude, inc.longitude,
            inc.doublon_potentiel_de.reference if inc.doublon_potentiel_de else '',
        ]


class ExportCSVView(APIView):
    """Export CSV des incidents filtrés (mêmes filtres que la liste). Journalisé."""

    permission_classes = [EstSuperAdmin]

    @extend_schema(responses={(200, 'text/csv'): bytes})
    def get(self, request):
        tampon = io.StringIO()
        tampon.write('﻿')  # BOM : ouverture correcte des accents dans Excel
        ecrivain = csv.writer(tampon, delimiter=';')
        ecrivain.writerow(COLONNES)
        nb = 0
        for ligne in lignes_export(request):
            ecrivain.writerow(ligne)
            nb += 1
        journaliser(request, 'export.csv', details={'lignes': nb, 'filtres': dict(request.query_params)})
        reponse = HttpResponse(tampon.getvalue(), content_type='text/csv; charset=utf-8')
        reponse['Content-Disposition'] = f'attachment; filename="senalert-incidents-{timezone.localdate():%Y%m%d}.csv"'
        return reponse


class ExportPDFView(APIView):
    """Rapport PDF de synthèse (indicateurs, régions, catégories, zones de risque) pour la période choisie."""

    permission_classes = [EstSuperAdmin]

    @extend_schema(responses={(200, 'application/pdf'): bytes})
    def get(self, request):
        from reportlab.lib import colors
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.styles import getSampleStyleSheet
        from reportlab.lib.units import cm
        from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle

        s = stats.statistiques(request.query_params)
        debut, fin = s['periode']['debut'], s['periode']['fin']
        zones, _ = calculer(debut, fin)
        styles = getSampleStyleSheet()
        nuit = colors.HexColor('#0B1F4D')

        def tableau(entete, lignes, largeurs):
            t = Table([entete, *lignes], colWidths=largeurs, repeatRows=1)
            t.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), nuit), ('TEXTCOLOR', (0, 0), (-1, 0), colors.white),
                ('FONTSIZE', (0, 0), (-1, -1), 8.5), ('GRID', (0, 0), (-1, -1), 0.25, colors.HexColor('#CBD5E1')),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.HexColor('#F1F5F9')]),
            ]))
            return t

        r = s['resume']
        fmt = lambda v, suffixe='': '—' if v is None else f'{v}{suffixe}'  # noqa: E731
        contenu = [
            Paragraph('SenAlert — Rapport de supervision', styles['Title']),
            Paragraph(f'Période du {debut:%d/%m/%Y} au {fin:%d/%m/%Y} · généré le {timezone.localtime():%d/%m/%Y %H:%M}', styles['Normal']),
            Spacer(1, 0.4 * cm),
            tableau(['Indicateur', 'Valeur'], [
                ['Incidents signalés', r['total_incidents']], ['Alertes SOS', r['total_sos']],
                ['Nouveaux (non affectés)', r['nouveaux']], ['En attente d’acceptation', r['en_attente']],
                ['En cours', r['en_cours']], ['Résolus', r['resolus']], ['En retard', r['en_retard']],
                ['Taux de résolution', fmt(r['taux_resolution'], ' %')],
                ['Délai moyen de prise en charge (incidents)', fmt(s['incidents']['delai_moyen_prise_en_charge_min'], ' min')],
                ['Délai moyen de prise en charge (SOS)', fmt(s['sos']['delai_moyen_prise_en_charge_min'], ' min')],
            ], [11 * cm, 5 * cm]),
            Spacer(1, 0.5 * cm), Paragraph('Répartition par région', styles['Heading2']),
            tableau(['Région', 'Incidents', 'SOS'], [[x['libelle'], x['incidents'], x['sos']] for x in s['par_region']],
                    [8 * cm, 4 * cm, 4 * cm]),
            Spacer(1, 0.5 * cm), Paragraph('Répartition par catégorie', styles['Heading2']),
            tableau(['Catégorie', 'Incidents'], [[x['libelle'], x['total']] for x in s['par_categorie']] or [['—', 0]],
                    [11 * cm, 5 * cm]),
            Spacer(1, 0.5 * cm), Paragraph('Score de risque par région (méthode de référence du mémoire)', styles['Heading2']),
            tableau(['Région', 'Score', 'Niveau', 'Incidents', 'Fiabilité'],
                    [[z['region_libelle'], z['score'], z['niveau'], z['total_incidents'],
                      'données insuffisantes' if z['donnees_insuffisantes'] else 'ok'] for z in zones],
                    [5 * cm, 2.5 * cm, 2.5 * cm, 2.5 * cm, 4 * cm]),
            Spacer(1, 0.3 * cm),
            Paragraph("Le score de risque est un indicateur descriptif fondé sur les signalements reçus ; il ne constitue "
                      "pas une prédiction. Les définitions des indicateurs figurent dans la documentation SenAlert.",
                      styles['Italic']),
        ]
        if s['donnees_demo']:
            contenu.insert(2, Paragraph('<b>Attention : la base contient des données de démonstration.</b>', styles['Normal']))
        tampon = io.BytesIO()
        SimpleDocTemplate(tampon, pagesize=A4, title='Rapport SenAlert', leftMargin=2 * cm, rightMargin=2 * cm).build(contenu)
        journaliser(request, 'export.pdf', details={'debut': str(debut), 'fin': str(fin)})
        tampon.seek(0)
        return FileResponse(tampon, as_attachment=True, filename=f'senalert-rapport-{fin:%Y%m%d}.pdf',
                            content_type='application/pdf')


def application_web(request, chemin=''):
    """Sert l'application web React compilée (web/dist) pour toutes les routes /app/…"""
    index = settings.WEB_DIST_DIR / 'index.html'
    if not index.exists():
        return HttpResponse(
            "<h1>SenAlert web non compilé</h1><p>Lancez <code>cd web && npm install && npm run build</code>, "
            "ou utilisez le serveur de développement : <code>npm run dev</code> puis http://localhost:5173/app/</p>",
            status=503,
        )
    reponse = HttpResponse(index.read_bytes(), content_type='text/html; charset=utf-8')
    # Jamais en cache : après chaque `npm run build`, le navigateur charge la nouvelle version.
    reponse['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    return reponse


@xframe_options_sameorigin
def application_mobile(request, chemin=''):
    """Sert l'application Flutter compilée pour le web (simulateur mobile, /mobile/…)."""
    from django.views.static import serve

    racine = settings.MOBILE_WEB_DIR
    if not (racine / 'index.html').exists():
        return HttpResponse(
            "<h1>Application mobile non compilée</h1><p>Lancez : <code>cd mobile && flutter build web "
            "--base-href /mobile/</code> puis rechargez cette page.</p>", status=503)
    cible = (racine / chemin).resolve()
    if not chemin or not cible.is_file() or racine.resolve() not in cible.parents:
        chemin = 'index.html'  # route interne de l'app, ou tentative de sortir du dossier
    reponse = serve(request, chemin, document_root=str(racine))
    if chemin == 'index.html':
        reponse['Cache-Control'] = 'no-cache, no-store, must-revalidate'
    return reponse
