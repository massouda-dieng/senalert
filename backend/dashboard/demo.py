"""Démonstration guidée (soutenance) : rejoue un parcours complet avec les comptes de test.

Chaque étape utilise la vraie machine à états (workflow) : rien n'est simulé côté
données, mais tout est étiqueté « [DÉMO] » et supprimable par
`python manage.py donnees_demo --supprimer`.
"""

from django.conf import settings
from django.db import transaction
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import User
from alerts.models import AlerteSOS
from alerts.serializers import AlerteSOSSerializer
from core.audit import journaliser
from core.exceptions import Conflit
from core.models import Categorie
from core.params import entier
from core.permissions import EstSuperAdmin
from incidents import workflow
from incidents.models import Incident
from incidents.serializers import IncidentSerializer

CITOYEN = 'citoyen.test@senalert.local'
AGENT = 'agent.pompiers@senalert.local'

ETAPES = {
    1: ('Une habitante déclenche un SOS', "Awa appuie sur le bouton SOS : sa position GPS part immédiatement vers la structure de secours la plus proche, dont le superviseur est prévenu et affecte un agent."),
    2: ('Elle signale un incendie', "Elle précise la situation : incendie dans un entrepôt. L'application lui propose la caserne la plus proche, qu'elle choisit."),
    3: ('La caserne affecte le dossier', "Le superviseur de la caserne affecte l'incendie à un de ses agents. L'agent et la citoyenne sont notifiés."),
    4: ("L'agent accepte", "L'agent accepte l'intervention et le SOS qui lui ont été transmis : le délai de prise en charge est mesuré."),
    5: ("Les secours sont en route", "L'agent démarre et partage sa position : la citoyenne voit « Les secours sont en route » et la distance sur son téléphone."),
    6: ("L'agent approche", "La position se met à jour : l'agent n'est plus qu'à quelques centaines de mètres."),
    7: ("Intervention terminée", "L'agent clôture avec un compte rendu ; sa position est effacée. Les indicateurs de supervision sont mis à jour."),
    8: ("La citoyenne note l'intervention", "Awa donne 5 étoiles : la satisfaction par service apparaît dans la supervision."),
}


class DemoView(APIView):
    """GET : liste des étapes ; POST {etape, incident?, sos?} : exécute une étape."""

    permission_classes = [EstSuperAdmin]

    def _comptes(self):
        citoyen = User.objects.filter(username=CITOYEN, is_active=True).first()
        agent = User.objects.filter(username=AGENT, is_active=True).select_related('profil_agent').first()
        if not citoyen or not agent:
            raise Conflit("Comptes de démonstration absents : lancez « python manage.py creer_comptes_test ».")
        return citoyen, agent

    @extend_schema(responses=OpenApiTypes.OBJECT)
    def get(self, request):
        return Response({'active': settings.DEMO_GUIDEE,
                         'etapes': [{'numero': n, 'titre': t, 'narration': d} for n, (t, d) in ETAPES.items()]})

    @extend_schema(request=OpenApiTypes.OBJECT, responses=OpenApiTypes.OBJECT)
    def post(self, request):
        if not settings.DEMO_GUIDEE:
            raise PermissionDenied('La démonstration guidée est désactivée sur ce serveur.')
        citoyen, agent = self._comptes()
        etape = entier(request.data.get('etape'), 0, 0, 99, 'etape')
        sos_id = entier(request.data.get('sos'), None, 1, 2 ** 62, 'sos')
        incident_id = entier(request.data.get('incident'), None, 1, 2 ** 62, 'incident')
        sos = AlerteSOS.objects.filter(pk=sos_id).first() if sos_id else None
        inc = Incident.objects.filter(pk=incident_id).first() if incident_id else None
        if etape not in ETAPES:
            raise Conflit('Étape inconnue.')
        if etape >= 3 and inc is None or etape >= 4 and sos is None:
            raise Conflit('Recommencez la démonstration depuis le début.')

        with transaction.atomic():
            if etape == 1:
                sos = AlerteSOS.objects.create(citoyen=citoyen, latitude=14.6731, longitude=-17.4369, precision_gps=12,
                                               region='dakar', gravite='critique', source_position='gps',
                                               structure=agent.structure, service=agent.structure.service,
                                               message='[DÉMO] SOS déclenché depuis l’application')
                workflow.apres_creation(sos, citoyen)
                # Le superviseur affecte le SOS à un agent de sa structure.
                sos = workflow.affecter(sos, request.user, agent=agent, message='SOS affecté (démonstration).')
            elif etape == 2:
                cat = Categorie.objects.get(code='incendie')
                inc = Incident.objects.create(
                    citoyen=citoyen, type_incident='incendie', region='dakar', latitude=14.6737, longitude=-17.4378,
                    precision_gps=15, adresse='Marché (scénario de démonstration)', service=cat.service_defaut, gravite='elevee',
                    structure=agent.structure,
                    description='[DÉMO] Fumée épaisse et flammes dans un entrepôt, personnes évacuées.')
                workflow.apres_creation(inc, citoyen)
            elif etape == 3:
                inc = workflow.affecter(inc, request.user, agent=agent, message='Intervention prioritaire (démonstration).')
            elif etape == 4:
                inc = workflow.accepter(inc, agent)
                sos = workflow.accepter(sos, agent)
            elif etape == 5:
                inc = workflow.demarrer(inc, agent)
                sos = workflow.demarrer(sos, agent)
                workflow.partager_position(inc, agent, 14.6858, -17.4452, 20)
            elif etape == 6:
                workflow.partager_position(inc, agent, 14.6762, -17.4391, 15)
            elif etape == 7:
                inc = workflow.resoudre(inc, agent, 'Feu maîtrisé en 25 minutes, entrepôt sécurisé, aucun blessé. (démonstration)',
                                        'Accès étroit pour le camion.')
                sos = workflow.resoudre(sos, agent, 'Personne prise en charge et rassurée sur place. (démonstration)')
            elif etape == 8:
                inc = workflow.evaluer(inc, citoyen, 5, 'Arrivés très vite, merci ! (démonstration)')
            journaliser(request, 'demo.etape', details={'etape': etape})

        ctx = {'request': request}
        titre, narration = ETAPES[etape]
        return Response({
            'etape': etape, 'titre': titre, 'narration': narration,
            'sos': AlerteSOSSerializer(AlerteSOS.objects.get(pk=sos.pk), context=ctx).data if sos else None,
            'incident': IncidentSerializer(Incident.objects.get(pk=inc.pk), context=ctx).data if inc else None,
        })
