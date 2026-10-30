"""Indicateurs du centre de supervision. Toutes les valeurs proviennent de la base."""

from datetime import datetime, time, timedelta

from django.db.models import Avg, Count, DurationField, ExpressionWrapper, F, Q
from django.db.models.functions import TruncDate, TruncMonth, TruncWeek
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from accounts.models import User
from alerts.models import AlerteSOS
from core.constants import (
    ACCEPTE, AFFECTE, ANNULE, EN_COURS, NOUVEAU, REFUSE, RESOLU, ROLE_AGENT, ROLE_CITOYEN,
)
from core.models import Categorie, Parametre
from core.constants import REGIONS
from incidents.models import Incident

DEFINITIONS = {
    'total_incidents': "Incidents signalés pendant la période (tous statuts).",
    'total_sos': "Alertes SOS reçues pendant la période (tous statuts).",
    'nouveaux': "Dossiers de la période encore au statut « Nouveau » (non affectés).",
    'en_attente': "Dossiers de la période affectés à un agent mais pas encore acceptés.",
    'en_cours': "Dossiers de la période acceptés ou en intervention.",
    'resolus': "Dossiers de la période clôturés comme résolus.",
    'rejetes_annules': "Dossiers de la période rejetés (non fondés) ou annulés.",
    'en_retard': "Dossiers non pris en charge au-delà du délai configuré (paramètre « délais de prise en charge »).",
    'delai_moyen_prise_en_charge_min': "Moyenne, en minutes, entre la création et l'acceptation par un agent (dossiers pris en charge).",
    'delai_moyen_resolution_min': "Moyenne, en minutes, entre la création et la clôture « résolu ».",
    'taux_resolution': "Résolus ÷ (total − rejetés − annulés), en %, sur la période.",
    'citoyens': "Comptes citoyens actifs (indépendant de la période).",
    'agents': "Comptes agents actifs (indépendant de la période).",
}


def periode(params):
    def lire(nom):
        v = params.get(nom)
        if not v:
            return None
        try:
            return datetime.strptime(v, '%Y-%m-%d').date()
        except ValueError:
            raise ValidationError({nom: 'Format attendu : AAAA-MM-JJ.'})

    fin = lire('date_fin') or timezone.localdate()
    debut = lire('date_debut') or (fin - timedelta(days=29))
    if debut > fin:
        raise ValidationError({'date_debut': 'La date de début doit précéder la date de fin.'})
    return debut, fin


def filtrer(qs, params, debut, fin, est_incident):
    qs = qs.filter(date_creation__date__gte=debut, date_creation__date__lte=fin)
    if params.get('region'):
        qs = qs.filter(region=params['region'])
    if params.get('service'):
        qs = qs.filter(service_id=params['service'])
    if est_incident and params.get('type_incident'):
        qs = qs.filter(type_incident=params['type_incident'])
    return qs


def minutes(d):
    return round(d.total_seconds() / 60, 1) if d else None


def compteurs(qs, delai_retard):
    limite = timezone.now() - timedelta(minutes=delai_retard)
    agg = qs.aggregate(
        total=Count('id'),
        nouveaux=Count('id', filter=Q(statut=NOUVEAU)),
        en_attente=Count('id', filter=Q(statut=AFFECTE)),
        en_cours=Count('id', filter=Q(statut__in=[ACCEPTE, EN_COURS])),
        resolus=Count('id', filter=Q(statut=RESOLU)),
        rejetes_annules=Count('id', filter=Q(statut__in=[REFUSE, ANNULE])),
        en_retard=Count('id', filter=Q(statut__in=[NOUVEAU, AFFECTE], date_creation__lt=limite)),
        delai_pec=Avg(ExpressionWrapper(F('date_prise_en_charge') - F('date_creation'), output_field=DurationField()),
                      filter=Q(date_prise_en_charge__isnull=False)),
        delai_res=Avg(ExpressionWrapper(F('date_cloture') - F('date_creation'), output_field=DurationField()),
                      filter=Q(statut=RESOLU, date_cloture__isnull=False)),
    )
    base = agg['total'] - agg['rejetes_annules']
    agg['taux_resolution'] = round(100 * agg['resolus'] / base, 1) if base else None
    agg['delai_moyen_prise_en_charge_min'] = minutes(agg.pop('delai_pec'))
    agg['delai_moyen_resolution_min'] = minutes(agg.pop('delai_res'))
    return agg


def debut_periode(jour, granularite):
    if granularite == 'semaine':
        return jour - timedelta(days=jour.weekday())
    if granularite == 'mois':
        return jour.replace(day=1)
    return jour


def serie(qs, granularite, debut, fin):
    """Nombre de dossiers par période, AVEC les périodes vides (0) pour ne pas fausser la courbe."""
    trunc = {'jour': TruncDate, 'semaine': TruncWeek, 'mois': TruncMonth}[granularite]
    lignes = qs.annotate(p=trunc('date_creation')).values('p').annotate(n=Count('id')).order_by('p')
    valeurs = {(l['p'].date() if hasattr(l['p'], 'date') else l['p']): l['n'] for l in lignes if l['p']}
    resultat, courant = {}, debut_periode(debut, granularite)
    while courant <= fin:
        resultat[courant.isoformat()] = valeurs.get(courant, 0)
        if granularite == 'mois':
            courant = (courant.replace(day=28) + timedelta(days=4)).replace(day=1)
        else:
            courant += timedelta(days=7 if granularite == 'semaine' else 1)
    return resultat


def qualite(qs):
    total = qs.count()
    if not total:
        return {'total': 0}
    pct = lambda n: round(100 * n / total, 1)  # noqa: E731
    return {
        'total': total,
        'avec_position_pct': pct(qs.filter(latitude__isnull=False).count()),
        'precision_gps_50m_pct': pct(qs.filter(precision_gps__isnull=False, precision_gps__lte=50).count()),
        'avec_description_pct': pct(qs.exclude(description='').filter(description__regex=r'.{20,}').count()),
        'avec_photo_pct': pct(qs.filter(pieces_jointes__isnull=False).distinct().count()),
        'avec_region_pct': pct(qs.exclude(region='').count()),
        'doublons_potentiels': qs.filter(doublon_potentiel_de__isnull=False).count(),
        'definitions': {
            'avec_position_pct': 'Part des incidents ayant des coordonnées.',
            'precision_gps_50m_pct': 'Part des incidents dont la précision GPS déclarée est ≤ 50 m.',
            'avec_description_pct': 'Part des incidents avec une description d’au moins 20 caractères.',
            'avec_photo_pct': 'Part des incidents avec au moins une photo.',
            'doublons_potentiels': 'Incidents signalés comme doublons potentiels (même catégorie, proches).',
        },
    }


def statistiques(params):
    debut, fin = periode(params)
    granularite = params.get('granularite', 'jour')
    if granularite not in ('jour', 'semaine', 'mois'):
        raise ValidationError({'granularite': 'jour, semaine ou mois.'})
    delais = Parametre.get('delais_prise_en_charge_minutes') or {}
    incidents = filtrer(Incident.objects.all(), params, debut, fin, True)
    sos = filtrer(AlerteSOS.objects.all(), params, debut, fin, False)
    ci = compteurs(incidents, delais.get('incident', 60))
    cs = compteurs(sos, delais.get('sos', 10))

    libelles = {c.code: c.libelle for c in Categorie.objects.all()}
    par_categorie = [{'code': l['type_incident'], 'libelle': libelles.get(l['type_incident'], l['type_incident']), 'total': l['n']}
                     for l in incidents.values('type_incident').annotate(n=Count('id')).order_by('-n')]
    regions_i = dict(incidents.values_list('region').annotate(n=Count('id')))
    regions_s = dict(sos.values_list('region').annotate(n=Count('id')))
    par_region = sorted([
        {'code': c, 'libelle': r['libelle'], 'incidents': regions_i.get(c, 0), 'sos': regions_s.get(c, 0)}
        for c, r in REGIONS.items()
    ], key=lambda x: -(x['incidents'] + x['sos']))

    total = ci['total'] + cs['total']
    resume = {
        'total_incidents': ci['total'], 'total_sos': cs['total'],
        'nouveaux': ci['nouveaux'] + cs['nouveaux'],
        'en_attente': ci['en_attente'] + cs['en_attente'],
        'en_cours': ci['en_cours'] + cs['en_cours'],
        'resolus': ci['resolus'] + cs['resolus'],
        'rejetes_annules': ci['rejetes_annules'] + cs['rejetes_annules'],
        'en_retard': ci['en_retard'] + cs['en_retard'],
        'taux_resolution': (round(100 * (ci['resolus'] + cs['resolus']) / (total - ci['rejetes_annules'] - cs['rejetes_annules']), 1)
                            if total - ci['rejetes_annules'] - cs['rejetes_annules'] else None),
        'citoyens': User.objects.filter(role=ROLE_CITOYEN, is_active=True).count(),
        'agents': User.objects.filter(role=ROLE_AGENT, is_active=True).count(),
    }
    return {
        'periode': {'debut': debut, 'fin': fin, 'granularite': granularite},
        'filtres': {k: params.get(k) for k in ('region', 'type_incident', 'service') if params.get(k)},
        'resume': resume,
        'incidents': ci,
        'sos': cs,
        'par_categorie': par_categorie,
        'par_region': par_region,
        'par_gravite': dict(incidents.values_list('gravite').annotate(n=Count('id'))),
        'evolution': {'incidents': serie(incidents, granularite, debut, fin), 'sos': serie(sos, granularite, debut, fin)},
        'qualite': qualite(incidents),
        'definitions': DEFINITIONS,
        'genere_le': timezone.now(),
        'donnees_demo': Incident.objects.filter(description__startswith='[DÉMO]').exists(),
    }


def activite_agent(agent):
    """Indicateurs personnels d'un agent (ses interventions uniquement)."""
    res = {}
    for nom, model in (('incidents', Incident), ('sos', AlerteSOS)):
        qs = model.objects.filter(intervention__agent=agent)
        res[nom] = compteurs(qs, 10 if nom == 'sos' else 60)
    semaine = timezone.now() - timedelta(days=7)
    res['resolus_7j'] = (Incident.objects.filter(intervention__agent=agent, statut=RESOLU, date_cloture__gte=semaine).count()
                         + AlerteSOS.objects.filter(intervention__agent=agent, statut=RESOLU, date_cloture__gte=semaine).count())
    return res


def bornes(debut, fin):
    return (timezone.make_aware(datetime.combine(debut, time.min)), timezone.make_aware(datetime.combine(fin, time.max)))
