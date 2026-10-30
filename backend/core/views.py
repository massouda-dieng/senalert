import logging

import requests
from django.conf import settings
from django.core.cache import cache
from django.utils import timezone
from django_filters import rest_framework as filters
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, permissions, serializers, viewsets
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from .audit import journaliser
from .constants import GRAVITE_CHOICES, REGIONS, ROLE_CHOICES, STATUT_CHOICES
from .exceptions import ServiceIndisponible
from .geo import distance_m
from .models import Categorie, FicheSecours, JournalAudit, Parametre, Service
from .permissions import EstSuperAdmin

logger = logging.getLogger('senalert')


def numeros_verifies():
    return [n for n in (Parametre.get('numeros_urgence') or []) if n.get('verifie')]


class ConfigurationPubliqueView(APIView):
    """Configuration non sensible nécessaire aux clients avant connexion."""

    permission_classes = [permissions.AllowAny]

    @extend_schema(responses=OpenApiTypes.OBJECT)
    def get(self, request):
        fonctions = Parametre.get('fonctionnalites') or {}
        return Response({
            'google_client_id_web': settings.GOOGLE_CLIENT_ID_WEB or None,
            'google_actif': bool(settings.GOOGLE_CLIENT_IDS) and fonctions.get('connexion_google', True),
            'numeros_urgence': numeros_verifies(),
            'avertissement': ("SenAlert ne remplace pas les services officiels de secours. "
                              "En cas de danger immédiat, appelez directement les numéros d'urgence."),
            'regions': [{'code': c, **r} for c, r in REGIONS.items()],
            'statuts': [{'code': c, 'libelle': l} for c, l in STATUT_CHOICES],
            'gravites': [{'code': c, 'libelle': l} for c, l in GRAVITE_CHOICES],
            'roles': [{'code': c, 'libelle': l} for c, l in ROLE_CHOICES],
            'categories': CategorieSerializer(Categorie.objects.filter(actif=True).select_related('service_defaut'), many=True).data,
            'fonctionnalites': fonctions,
        })


class ServiceSerializer(serializers.ModelSerializer):
    class Meta:
        model = Service
        fields = ['id', 'code', 'nom', 'description', 'actif']


class CategorieSerializer(serializers.ModelSerializer):
    service_defaut_nom = serializers.CharField(source='service_defaut.nom', default=None, read_only=True)

    class Meta:
        model = Categorie
        fields = ['id', 'code', 'libelle', 'description', 'service_defaut', 'service_defaut_nom', 'gravite_defaut',
                  'icone', 'couleur', 'ordre', 'actif']


class LectureOuSuperAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        if request.method in permissions.SAFE_METHODS:
            return request.user and request.user.is_authenticated
        return EstSuperAdmin().has_permission(request, view)


class ReferentielViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, mixins.CreateModelMixin,
                         mixins.UpdateModelMixin, viewsets.GenericViewSet):
    """Lecture pour tout compte connecté, écriture superadmin (journalisée). Pas de suppression : on désactive."""

    permission_classes = [LectureOuSuperAdmin]
    pagination_class = None

    def perform_create(self, serializer):
        obj = serializer.save()
        journaliser(self.request, f'config.creation_{obj.__class__.__name__.lower()}', obj, serializer.data)

    def perform_update(self, serializer):
        obj = serializer.save()
        journaliser(self.request, f'config.modification_{obj.__class__.__name__.lower()}', obj, self.request.data)


class ServiceViewSet(ReferentielViewSet):
    queryset = Service.objects.all()
    serializer_class = ServiceSerializer


class CategorieViewSet(ReferentielViewSet):
    queryset = Categorie.objects.select_related('service_defaut')
    serializer_class = CategorieSerializer


class ParametreSerializer(serializers.ModelSerializer):
    modifie_par_nom = serializers.CharField(source='modifie_par.username', default=None, read_only=True)

    class Meta:
        model = Parametre
        fields = ['cle', 'valeur', 'description', 'modifie_par_nom', 'date_modification']
        read_only_fields = ['cle', 'description', 'modifie_par_nom', 'date_modification']

    def validate_valeur(self, valeur):
        defaut = Parametre.DEFAUTS.get(self.instance.cle, {}).get('valeur')
        if defaut is not None and type(valeur) is not type(defaut):
            raise serializers.ValidationError('Le format de la valeur ne correspond pas au paramètre.')
        if isinstance(defaut, dict):
            inconnues = set(valeur) - set(defaut)
            if inconnues:
                raise serializers.ValidationError(f"Clés inconnues : {', '.join(sorted(inconnues))}.")
        return valeur


class ParametreViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, mixins.UpdateModelMixin,
                       viewsets.GenericViewSet):
    permission_classes = [EstSuperAdmin]
    serializer_class = ParametreSerializer
    queryset = Parametre.objects.all()
    lookup_field = 'cle'
    pagination_class = None
    http_method_names = ['get', 'patch']

    def perform_update(self, serializer):
        avant = serializer.instance.valeur
        obj = serializer.save(modifie_par=self.request.user)
        journaliser(self.request, 'config.modification_parametre', obj, {'cle': obj.cle, 'avant': avant, 'apres': obj.valeur})


class JournalAuditSerializer(serializers.ModelSerializer):
    acteur_nom = serializers.CharField(source='acteur.username', default=None, read_only=True)

    class Meta:
        model = JournalAudit
        fields = ['id', 'date', 'acteur', 'acteur_nom', 'action', 'cible_type', 'cible_id', 'details', 'adresse_ip']


class FiltreAudit(filters.FilterSet):
    action = filters.CharFilter(lookup_expr='startswith')
    acteur = filters.NumberFilter()
    date_debut = filters.DateFilter(field_name='date', lookup_expr='date__gte')
    date_fin = filters.DateFilter(field_name='date', lookup_expr='date__lte')

    class Meta:
        model = JournalAudit
        fields = []


class JournalAuditViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    permission_classes = [EstSuperAdmin]
    serializer_class = JournalAuditSerializer
    queryset = JournalAudit.objects.select_related('acteur')
    filterset_class = FiltreAudit


class FicheSecoursSerializer(serializers.ModelSerializer):
    validee = serializers.SerializerMethodField()

    class Meta:
        model = FicheSecours
        fields = ['slug', 'titre', 'categorie', 'resume', 'etapes', 'a_eviter', 'appeler_si', 'sources',
                  'valide_par', 'validee', 'date_mise_a_jour', 'ordre']

    def get_validee(self, obj) -> bool:
        return bool(obj.valide_par)


class FicheSecoursViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin, viewsets.GenericViewSet):
    """Fiches de premiers secours (lecture publique, aussi embarquées dans l'app mobile pour le hors ligne)."""

    permission_classes = [permissions.AllowAny]
    serializer_class = FicheSecoursSerializer
    queryset = FicheSecours.objects.filter(publie=True)
    lookup_field = 'slug'
    pagination_class = None


# --- Services de proximité (OpenStreetMap) -----------------------------------

TYPES_OSM = {
    'hopital': ('amenity', 'hospital'),
    'clinique': ('amenity', 'clinic'),
    'pharmacie': ('amenity', 'pharmacy'),
    'police': ('amenity', 'police'),
    'pompiers': ('amenity', 'fire_station'),
}


def interroger_overpass(lat, lng, rayon, types):
    clauses = ''.join(
        f'nwr["{TYPES_OSM[t][0]}"="{TYPES_OSM[t][1]}"](around:{rayon},{lat},{lng});' for t in types
    )
    requete = f'[out:json][timeout:20];({clauses});out center tags 200;'
    reponse = requests.post(settings.OVERPASS_URL, data={'data': requete}, timeout=25,
                            headers={'User-Agent': 'SenAlert/3.0 (projet academique ISEP Diamniadio)'})
    reponse.raise_for_status()
    return reponse.json().get('elements', [])


class ServicesProximiteView(APIView):
    """Établissements réels issus d'OpenStreetMap autour d'une position.

    Aucune donnée n'est inventée : nom, position et, s'ils sont renseignés
    dans OSM, téléphone et horaires. La disponibilité opérationnelle n'est
    jamais connue et n'est pas affichée.
    """

    throttle_scope = 'services'

    def get_throttles(self):
        return [ScopedRateThrottle()]

    @extend_schema(responses=OpenApiTypes.OBJECT)
    def get(self, request):
        try:
            lat = float(request.query_params['lat'])
            lng = float(request.query_params['lng'])
        except (KeyError, ValueError):
            raise serializers.ValidationError({'lat': 'Paramètres lat et lng requis.'})
        rayon = max(500, min(int(request.query_params.get('rayon', 5000) or 5000), 20000))
        types = [t for t in request.query_params.getlist('type') if t in TYPES_OSM] or list(TYPES_OSM)

        # Arrondi (~1 km) : améliore le cache et évite d'envoyer la position exacte à un tiers.
        lat_r, lng_r = round(lat, 2), round(lng, 2)
        cle = f'osm:{lat_r}:{lng_r}:{rayon}:{",".join(sorted(types))}'
        cache_val = cache.get(cle)
        if cache_val is None:
            try:
                elements = interroger_overpass(lat_r, lng_r, rayon + 1500, types)
            except Exception as exc:
                logger.warning('Overpass indisponible : %s', exc.__class__.__name__)
                raise ServiceIndisponible("Le service cartographique OpenStreetMap ne répond pas. Réessayez plus tard.")
            cache_val = {'elements': elements, 'date': timezone.now().isoformat()}
            cache.set(cle, cache_val, 60 * 60)

        resultats = []
        inverse = {v: k for k, v in TYPES_OSM.items()}
        for el in cache_val['elements']:
            tags = el.get('tags', {})
            plat = el.get('lat') or el.get('center', {}).get('lat')
            plng = el.get('lon') or el.get('center', {}).get('lon')
            if plat is None or plng is None:
                continue
            type_ = next((inverse[(k, v)] for k, v in tags.items() if (k, v) in inverse), None)
            if type_ is None:
                continue
            d = distance_m(lat, lng, plat, plng)
            if d > rayon:
                continue
            resultats.append({
                'id': f"{el['type']}/{el['id']}",
                'type': type_,
                'nom': tags.get('name') or tags.get('name:fr') or None,
                'latitude': plat, 'longitude': plng,
                'distance_m': round(d),
                'telephone': tags.get('phone') or tags.get('contact:phone') or None,
                'horaires': tags.get('opening_hours') or None,
                'adresse': ' '.join(filter(None, [tags.get('addr:housenumber'), tags.get('addr:street'), tags.get('addr:city')])) or None,
                'urgences': tags.get('emergency') == 'yes' or None,
            })
        resultats.sort(key=lambda r: r['distance_m'])
        return Response({
            'resultats': resultats[:100],
            'source': '© contributeurs OpenStreetMap (ODbL)',
            'donnees_du': cache_val['date'],
            'avertissement': ("Données collaboratives : vérifiez avant de vous déplacer. "
                              "La disponibilité des établissements n'est pas connue."),
        })


# --- Recherche d'adresse (OpenStreetMap / Nominatim) --------------------------

class GeocodageView(APIView):
    """Recherche d'un lieu au Sénégal (adresse, quartier, établissement). Résultats mis en cache 24 h."""

    throttle_scope = 'services'

    def get_throttles(self):
        return [ScopedRateThrottle()]

    @extend_schema(responses=OpenApiTypes.OBJECT)
    def get(self, request):
        q = (request.query_params.get('q') or '').strip()
        if len(q) < 3 or len(q) > 120:
            raise serializers.ValidationError({'q': 'Saisissez entre 3 et 120 caractères.'})
        cle = f'geo:{q.lower()}'
        resultats = cache.get(cle)
        if resultats is None:
            try:
                r = requests.get(settings.NOMINATIM_URL, timeout=10, params={
                    'q': q, 'format': 'jsonv2', 'countrycodes': 'sn', 'limit': 6, 'accept-language': 'fr'},
                    headers={'User-Agent': 'SenAlert/3.0 (projet academique ISEP Diamniadio)'})
                r.raise_for_status()
                resultats = [{'nom': x.get('display_name'), 'latitude': float(x['lat']), 'longitude': float(x['lon']),
                              'type': x.get('type')} for x in r.json()]
            except Exception as exc:
                logger.warning('Nominatim indisponible : %s', exc.__class__.__name__)
                raise ServiceIndisponible("La recherche d'adresse est momentanément indisponible.")
            cache.set(cle, resultats, 60 * 60 * 24)
        return Response({'resultats': resultats, 'source': '© contributeurs OpenStreetMap (Nominatim)'})


# --- Chiffres publics (page d'accueil) -----------------------------------------

class StatistiquesPubliquesView(APIView):
    """Chiffres réels et agrégés pour la page de présentation (aucune donnée personnelle)."""

    permission_classes = [permissions.AllowAny]

    @extend_schema(responses=OpenApiTypes.OBJECT)
    def get(self, request):
        donnees = cache.get('stats_publiques')
        if donnees is None:
            from accounts.models import User
            from alerts.models import AlerteSOS
            from incidents.models import Incident
            from .constants import RESOLU, ROLE_AGENT, ROLE_CITOYEN

            incidents = Incident.objects.all()
            donnees = {
                'signalements': incidents.count(),
                'resolus': incidents.filter(statut=RESOLU).count() + AlerteSOS.objects.filter(statut=RESOLU).count(),
                'alertes_sos': AlerteSOS.objects.count(),
                'citoyens': User.objects.filter(role=ROLE_CITOYEN, is_active=True).count(),
                'agents': User.objects.filter(role=ROLE_AGENT, is_active=True).count(),
                'regions_couvertes': incidents.exclude(region='').values('region').distinct().count(),
                'services': Service.objects.filter(actif=True).count(),
                'donnees_demo': incidents.filter(description__startswith='[DÉMO]').exists(),
                'calcule_le': timezone.now(),
            }
            cache.set('stats_publiques', donnees, 300)
        return Response(donnees)
