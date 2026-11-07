import json
import logging
import time
from functools import lru_cache
from pathlib import Path

import requests
from django.conf import settings
from django.core.cache import cache, caches
from django.utils import timezone
from django_filters import rest_framework as filters
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import mixins, permissions, serializers, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from .audit import ACTIONS, actions_de, journaliser, libelle_action
from .constants import GRAVITE_CHOICES, REGIONS, ROLE_CHOICES, STATUT_CHOICES, TYPES_URGENCE
from .exceptions import ServiceIndisponible
from .geo import dans_senegal, distance_m, region_la_plus_proche
from .models import Categorie, FicheSecours, JournalAudit, Parametre, Service, Structure
from .params import coordonnees, entier
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
        sms = Parametre.get('sms_secours') or {}
        return Response({
            'sms_secours': sms.get('numero') if sms.get('actif') and sms.get('numero') else None,
            'google_client_id_web': settings.GOOGLE_CLIENT_ID_WEB or None,
            'google_actif': bool(settings.GOOGLE_CLIENT_IDS) and fonctions.get('connexion_google', True),
            # Dictée vocale de l'assistant : possible seulement avec une clé Groq (Whisper).
            'assistant_vocal': bool(settings.GROQ_API_KEY) and fonctions.get('assistant_ia', True),
            'numeros_urgence': numeros_verifies(),
            'avertissement': ("SenAlert ne remplace pas les services officiels de secours. "
                              "En cas de danger immédiat, appelez directement les numéros d'urgence."),
            'regions': [{'code': c, **r} for c, r in REGIONS.items()],
            'statuts': [{'code': c, 'libelle': l} for c, l in STATUT_CHOICES],
            'gravites': [{'code': c, 'libelle': l} for c, l in GRAVITE_CHOICES],
            'roles': [{'code': c, 'libelle': l} for c, l in ROLE_CHOICES],
            'services': [{'code': str(i), 'libelle': n} for i, n in Service.objects.filter(actif=True).values_list('id', 'nom')],
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


class StructureSerializer(serializers.ModelSerializer):
    service_nom = serializers.CharField(source='service.nom', read_only=True)
    service_code = serializers.CharField(source='service.code', read_only=True)
    region_libelle = serializers.CharField(source='get_region_display', read_only=True)
    distance_m = serializers.SerializerMethodField()
    nb_agents_disponibles = serializers.SerializerMethodField()
    dans_la_zone = serializers.SerializerMethodField()
    suggeree = serializers.SerializerMethodField()

    class Meta:
        model = Structure
        fields = ['id', 'nom', 'service', 'service_nom', 'service_code', 'latitude', 'longitude', 'region',
                  'region_libelle', 'adresse', 'telephone', 'position_approximative', 'source', 'actif',
                  'distance_m', 'nb_agents_disponibles', 'dans_la_zone', 'suggeree']
        read_only_fields = ['source']

    def get_distance_m(self, obj) -> int | None:
        d = self.context.get('distances', {}).get(obj.pk)
        return round(d) if d is not None else None

    def get_nb_agents_disponibles(self, obj) -> int | None:
        return self.context.get('agents', {}).get(obj.pk)

    def get_suggeree(self, obj) -> bool:
        """Recherche par position : structure présélectionnée pour le citoyen (celle que le serveur choisirait)."""
        return self.context.get('suggeree') == obj.pk

    def get_dans_la_zone(self, obj) -> bool | None:
        """Recherche par position : la structure est-elle compétente pour la région du lieu ?"""
        region = self.context.get('region')
        return obj.region == region if region else None

    def validate(self, attrs):
        lat = attrs.get('latitude', getattr(self.instance, 'latitude', None))
        lng = attrs.get('longitude', getattr(self.instance, 'longitude', None))
        if lat is not None and lng is not None and not dans_senegal(lat, lng):
            raise serializers.ValidationError({'latitude': 'La structure doit être située au Sénégal.'})
        if 'latitude' in attrs or 'longitude' in attrs:
            attrs['position_approximative'] = attrs.get('position_approximative', False)
        return attrs


class FiltreStructure(filters.FilterSet):
    service = filters.CharFilter(field_name='service__code')
    region = filters.CharFilter()
    q = filters.CharFilter(field_name='nom', lookup_expr='icontains')
    actif = filters.BooleanFilter()

    class Meta:
        model = Structure
        fields = []


class StructureViewSet(ReferentielViewSet):
    """Structures d'intervention géolocalisées.

    * `?lat=…&lng=…` (tout compte connecté) : les plus proches, avec la distance et le nombre d'agents
      disponibles ; filtrées par `categorie` (service compétent) ou `service` (code).
    * Sans position : liste filtrable (service, région, q) ; écriture réservée au superadministrateur.
    * `/structures/{id}/agents/` : agents disponibles, présentés au citoyen par prénom et fonction seulement.
    """

    queryset = Structure.objects.select_related('service')
    serializer_class = StructureSerializer
    filterset_class = FiltreStructure

    def list(self, request, *args, **kwargs):
        from .structures import agents_disponibles, structure_competente, structures_proches
        p = request.query_params
        if p.get('lat') is None and p.get('lng') is None:
            return super().list(request, *args, **kwargs)
        lat, lng = coordonnees(p.get('lat'), p.get('lng'))
        services = [p['service']] if p.get('service') else None
        if services and services[0].isdigit():  # identifiant du service (configuration publique) ou son code
            services = list(Service.objects.filter(pk=int(services[0])).values_list('code', flat=True)) or ['?']
        if p.get('type_urgence') in TYPES_URGENCE:
            services = list(TYPES_URGENCE[p['type_urgence']]['services'])
        if p.get('categorie'):
            cat = Categorie.objects.filter(code=p['categorie'], actif=True).select_related('service_defaut').first()
            if cat and cat.service_defaut_id:
                services = [cat.service_defaut.code]
        region = p.get('region') if p.get('region') in REGIONS else region_la_plus_proche(lat, lng)
        proches = structures_proches(lat, lng, services, entier(p.get('limite'), 8, 1, 20, 'limite'), region=region)
        suggeree = structure_competente(lat, lng, region, services) if proches else None
        contexte = {**self.get_serializer_context(), 'region': region, 'suggeree': suggeree.pk if suggeree else None,
                    'distances': {s.pk: d for s, d in proches},
                    'agents': {s.pk: agents_disponibles(s).count() for s, _ in proches}}
        return Response(StructureSerializer([s for s, _ in proches], many=True, context=contexte).data)

    @extend_schema(responses=OpenApiTypes.OBJECT)
    @action(detail=True, methods=['get'])
    def agents(self, request, pk=None):
        from .structures import agents_disponibles
        structure = self.get_object()
        return Response([
            {'id': a.pk, 'prenom': a.first_name or 'Agent', 'fonction': a.profil_agent.fonction or structure.service.nom,
             'missions_actives': a.missions_actives}
            for a in agents_disponibles(structure)
        ])


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
    """Entrée lisible : qui (nom et rôle), quoi (action en clair), quand et sur quel élément."""

    acteur_nom = serializers.SerializerMethodField()
    acteur_role_libelle = serializers.SerializerMethodField()
    action_libelle = serializers.SerializerMethodField()
    rubrique = serializers.SerializerMethodField()
    element = serializers.SerializerMethodField()

    class Meta:
        model = JournalAudit
        fields = ['id', 'date', 'acteur', 'acteur_nom', 'acteur_role', 'acteur_role_libelle', 'action', 'action_libelle',
                  'rubrique', 'cible_type', 'cible_id', 'cible_libelle', 'element', 'details', 'adresse_ip']

    def get_acteur_nom(self, obj) -> str:
        return obj.acteur.nom_affiche if obj.acteur else 'Système'

    def get_acteur_role_libelle(self, obj) -> str:
        role = obj.acteur_role or (obj.acteur.role if obj.acteur else '')
        return dict(ROLE_CHOICES).get(role, '—')

    def get_action_libelle(self, obj) -> str:
        return libelle_action(obj.action)[0]

    def get_rubrique(self, obj) -> str:
        return libelle_action(obj.action)[1]

    def get_element(self, obj) -> str:
        types = {'Incident': 'Incident', 'AlerteSOS': 'Alerte SOS', 'User': 'Compte', 'Structure': 'Structure',
                 'Service': 'Service', 'Categorie': 'Catégorie', 'Parametre': 'Paramètre', 'AlerteZone': 'Alerte de zone'}
        if not obj.cible_type:
            return '—'
        nature = types.get(obj.cible_type, obj.cible_type)
        return f'{nature} · {obj.cible_libelle}' if obj.cible_libelle else f'{nature} #{obj.cible_id}'


class FiltreAudit(filters.FilterSet):
    action = filters.CharFilter(lookup_expr='startswith')
    rubrique = filters.CharFilter(method='filtre_rubrique')
    acteur = filters.NumberFilter()
    date_debut = filters.DateFilter(field_name='date', lookup_expr='date__gte')
    date_fin = filters.DateFilter(field_name='date', lookup_expr='date__lte')

    class Meta:
        model = JournalAudit
        fields = []

    def filtre_rubrique(self, qs, name, value):
        if value == 'autres':
            return qs.exclude(action__in=list(ACTIONS))
        return qs.filter(action__in=actions_de(value))


class JournalAuditViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """Journal d'audit en lecture seule, réservé au superadministrateur (aucune modification ni suppression)."""

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


# Au-delà, l'utilisateur attend trop : on répond avec les données déjà disponibles.
OVERPASS_DELAI_TOTAL = 8
# Après une panne, Overpass n'est plus interrogé pendant ce délai (secondes).
OVERPASS_PAUSE_APRES_PANNE = 600


@lru_cache(maxsize=1)
def base_services_locale():
    """Extrait OpenStreetMap embarqué (scripts/extraire_services_osm.py), ou None s'il est absent."""
    chemin = Path(__file__).resolve().parent / 'data' / 'services_osm.json'
    if not chemin.exists():
        return None
    return json.loads(chemin.read_text(encoding='utf-8'))


def interroger_overpass(lat, lng, rayon, types):
    clauses = ''.join(
        f'nwr["{TYPES_OSM[t][0]}"="{TYPES_OSM[t][1]}"](around:{rayon},{lat},{lng});' for t in types
    )
    requete = f'[out:json][timeout:15];({clauses});out center tags 200;'
    derniere = None
    echeance = time.monotonic() + OVERPASS_DELAI_TOTAL
    for url in settings.OVERPASS_URLS:  # serveur principal puis miroirs
        reste = echeance - time.monotonic()
        if reste <= 1:
            break
        try:
            reponse = requests.post(url, data={'data': requete}, timeout=(min(3, reste), reste),
                                    headers={'User-Agent': 'SenAlert/3.0 (projet academique ISEP Diamniadio)'})
            reponse.raise_for_status()
            return reponse.json()['elements']
        except Exception as exc:  # saturé, hors délai ou réponse non JSON : serveur suivant
            logger.info('Overpass %s indisponible : %s', url, exc.__class__.__name__)
            derniere = exc
    raise derniere or TimeoutError('Overpass : délai total dépassé')


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
        lat, lng = coordonnees(request.query_params.get('lat'), request.query_params.get('lng'))
        rayon = entier(request.query_params.get('rayon'), 5000, 500, 20000, 'rayon')
        types = [t for t in request.query_params.getlist('type') if t in TYPES_OSM] or list(TYPES_OSM)

        # Arrondi (~1 km) : améliore le cache et évite d'envoyer la position exacte à un tiers.
        lat_r, lng_r = round(lat, 2), round(lng, 2)
        cle = f'osm:{lat_r}:{lng_r}:{rayon}:{",".join(sorted(types))}'
        cache_val = cache.get(cle)
        if cache_val is None:
            try:
                if cache.get('osm:en_panne'):
                    raise TimeoutError('Overpass en pause après une panne récente')
                elements = interroger_overpass(lat_r, lng_r, rayon + 1500, types)
                cache_val = {'elements': elements, 'date': timezone.now().isoformat()}
                cache.set(cle, cache_val, 60 * 60)
                caches['osm'].set(cle, cache_val)
            except Exception as exc:
                logger.warning('Overpass indisponible : %s', exc.__class__.__name__)
                cache.set('osm:en_panne', True, OVERPASS_PAUSE_APRES_PANNE)
                # Derniers résultats réels obtenus pour cette zone, sinon l'extrait OpenStreetMap
                # embarqué (daté), sinon erreur honnête.
                cache_val = caches['osm'].get(cle)
                if cache_val is not None:
                    cache_val = {**cache_val, 'ancien': True}
                else:
                    base = base_services_locale()
                    if base is None:
                        raise ServiceIndisponible("Les serveurs OpenStreetMap sont saturés en ce moment. Réessayez dans quelques minutes.")
                    cache_val = {'elements': base['elements'], 'date': base['extrait_le'], 'ancien': True, 'source': base['source']}

        resultats = []
        inverse = {v: k for k, v in TYPES_OSM.items()}
        for el in cache_val['elements']:
            tags = el.get('tags', {})
            plat = el.get('lat') or el.get('center', {}).get('lat')
            plng = el.get('lon') or el.get('center', {}).get('lon')
            if plat is None or plng is None:
                continue
            type_ = next((inverse[(k, v)] for k, v in tags.items() if (k, v) in inverse), None)
            # Le repli (extrait embarqué) contient tous les types : on ne garde que ceux demandés.
            if type_ is None or type_ not in types:
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
            'source': cache_val.get('source', '© contributeurs OpenStreetMap (ODbL)'),
            'donnees_du': cache_val['date'],
            'donnees_anciennes': bool(cache_val.get('ancien')),
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
