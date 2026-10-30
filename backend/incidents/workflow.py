"""Cycle de vie des dossiers (incidents et alertes SOS).

    nouveau ──affecter──▶ affecte ──accepter──▶ accepte ──demarrer──▶ en_cours ──resoudre──▶ resolu
       │  ╰──prendre_en_charge (agent)──────────▲
       │                    │ decliner ▶ nouveau
       ├──rejeter──▶ refuse (signalement non fondé)
       ╰──annuler──▶ annule (depuis tout statut actif)

Chaque action :
  * verrouille la ligne (select_for_update) et revérifie le statut courant :
    deux actions concurrentes ne peuvent pas réussir toutes les deux (409) ;
  * est horodatée dans EvenementDossier ;
  * déclenche les notifications APRÈS validation de la transaction, de sorte
    qu'un échec d'envoi n'annule jamais l'enregistrement.
"""

from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework.exceptions import PermissionDenied, ValidationError

from core.constants import (
    ACCEPTE, AFFECTE, ANNULE, EN_COURS, NOUVEAU, REFUSE, RESOLU, ROLE_AGENT, ROLE_SUPERADMIN, STATUTS_ACTIFS,
    STATUTS_FINAUX,
)
from core.exceptions import Conflit
from core.geo import boite_englobante, distance_m
from core.models import Parametre
from notifications import service as notif

from .models import EvenementDossier, Incident, Intervention

LIBELLES_STATUT = {
    NOUVEAU: 'Nouveau', AFFECTE: 'Affecté', ACCEPTE: 'Pris en charge', EN_COURS: 'Intervention en cours',
    RESOLU: 'Résolu', REFUSE: 'Rejeté', ANNULE: 'Annulé',
}


def est_incident(dossier):
    return isinstance(dossier, Incident)


def _lien(dossier):
    return {'incident': dossier} if est_incident(dossier) else {'alerte': dossier}


def evenement(dossier, type_, acteur=None, message='', avant='', apres='', visible=True):
    return EvenementDossier.objects.create(
        type=type_, acteur=acteur, message=message, statut_avant=avant, statut_apres=apres,
        visible_citoyen=visible, **_lien(dossier),
    )


def _verrouiller(dossier):
    return type(dossier).objects.select_for_update().get(pk=dossier.pk)


def _intervention(dossier):
    return Intervention.objects.filter(**_lien(dossier)).select_related('agent', 'service').first()


def _exiger_statut(dossier, autorises, action):
    if dossier.statut not in autorises:
        raise Conflit(
            f"Action « {action} » impossible : le dossier est actuellement « {LIBELLES_STATUT[dossier.statut]} »."
        )


def _changer_statut(dossier, nouveau, acteur, message='', visible=True, motif=''):
    avant = dossier.statut
    dossier.statut = nouveau
    champs = ['statut', 'date_modification']
    if nouveau == ACCEPTE and not dossier.date_prise_en_charge:
        dossier.date_prise_en_charge = timezone.now()
        champs.append('date_prise_en_charge')
    if nouveau in STATUTS_FINAUX:
        dossier.date_cloture = timezone.now()
        dossier.motif_cloture = motif[:255]
        champs += ['date_cloture', 'motif_cloture']
    dossier.save(update_fields=champs)
    evenement(dossier, 'transition', acteur, message, avant, nouveau, visible)
    if dossier.citoyen_id and nouveau != avant:
        transaction.on_commit(lambda: notif.notifier_citoyen_statut(dossier, nouveau))


def regles():
    return Parametre.get('workflow') or {}


# --------------------------------------------------------------------------
# Portée d'un agent
# --------------------------------------------------------------------------

def profil_agent(user):
    return getattr(user, 'profil_agent', None)


def filtre_visibilite(user, est_sos):
    """Q-objet des dossiers visibles par un utilisateur (contrôle d'accès serveur)."""
    if user.role == ROLE_SUPERADMIN:
        return Q()
    if user.role == ROLE_AGENT:
        q = Q(intervention__agent=user)
        profil = profil_agent(user)
        if profil and profil.zones:
            nouveaux = Q(statut=NOUVEAU, region__in=profil.zones)
            if not est_sos:
                # Un incident nouveau n'est visible que par le service compétent.
                nouveaux &= Q(service=profil.service) if profil.service_id else Q(pk__in=[])
            q |= nouveaux
        return q
    return Q(citoyen=user)


def dans_portee_agent(agent, dossier):
    profil = profil_agent(agent)
    if not profil or dossier.region not in (profil.zones or []):
        return False
    if est_incident(dossier):
        return bool(profil.service_id) and dossier.service_id == profil.service_id
    return True


# --------------------------------------------------------------------------
# Création
# --------------------------------------------------------------------------

def apres_creation(dossier, acteur):
    """Événement initial, doublons potentiels et notification des agents compétents."""
    evenement(dossier, 'creation', acteur, apres=dossier.statut,
              message='Alerte SOS enregistrée.' if not est_incident(dossier) else 'Signalement enregistré.')
    if est_incident(dossier):
        detecter_doublon(dossier)
    transaction.on_commit(lambda: notif.notifier_nouveau_dossier(dossier))


def detecter_doublon(incident):
    """Repère un incident actif de même catégorie, proche dans l'espace et le temps.

    Le doublon est seulement signalé (jamais fusionné automatiquement) : un
    superadministrateur décide.
    """
    if not incident.a_position:
        return None
    p = Parametre.get('doublons') or {}
    rayon = p.get('rayon_metres', 300)
    fenetre = p.get('fenetre_minutes', 120)
    lat_min, lat_max, lng_min, lng_max = boite_englobante(incident.latitude, incident.longitude, rayon)
    candidats = Incident.objects.filter(
        type_incident=incident.type_incident,
        statut__in=STATUTS_ACTIFS,
        date_creation__gte=incident.date_creation - timezone.timedelta(minutes=fenetre),
        latitude__range=(lat_min, lat_max), longitude__range=(lng_min, lng_max),
    ).exclude(pk=incident.pk)
    meilleur, dmin = None, None
    for c in candidats:
        d = distance_m(incident.latitude, incident.longitude, c.latitude, c.longitude)
        if d <= rayon and (dmin is None or d < dmin):
            meilleur, dmin = c, d
    if meilleur:
        incident.doublon_potentiel_de = meilleur
        incident.save(update_fields=['doublon_potentiel_de'])
        evenement(incident, 'doublon', None, visible=False,
                  message=f'Doublon potentiel de {meilleur.reference} (à {round(dmin)} m).')
    return meilleur


# --------------------------------------------------------------------------
# Actions
# --------------------------------------------------------------------------

@transaction.atomic
def affecter(dossier, acteur, agent=None, service=None, message=''):
    """Affectation ou réaffectation par le superadministrateur."""
    dossier = _verrouiller(dossier)
    _exiger_statut(dossier, {NOUVEAU, AFFECTE, ACCEPTE, EN_COURS}, 'affecter')
    if agent is None and service is None:
        raise ValidationError({'agent': 'Indiquez un agent ou un service.'})
    if agent is not None:
        if agent.role != ROLE_AGENT or not agent.is_active:
            raise ValidationError({'agent': "Ce compte n'est pas un agent actif."})
        profil = profil_agent(agent)
        service = service or (profil.service if profil else None)

    inter = _intervention(dossier)
    reaffectation = bool(inter and inter.agent_id)
    ancien_agent = inter.agent if inter else None
    if inter is None:
        inter = Intervention(**_lien(dossier))
    inter.service = service
    inter.agent = agent
    inter.affecte_par = acteur
    inter.date_affectation = timezone.now()
    inter.date_acceptation = inter.date_debut = None
    inter.save()

    if service and dossier.service_id != service.pk:
        dossier.service = service
        dossier.save(update_fields=['service'])

    cible = agent.nom_affiche if agent else (service.nom if service else '')
    texte = f"{'Réaffecté' if reaffectation else 'Affecté'} à {cible}." + (f' {message}' if message else '')
    evenement(dossier, 'affectation', acteur, texte, visible=False)
    if agent is not None:
        avant = dossier.statut
        if avant != AFFECTE:
            _changer_statut(dossier, AFFECTE, acteur, f"Dossier transmis au service {service.nom if service else ''}.".strip())
        transaction.on_commit(lambda: notif.notifier_affectation(dossier, agent))
        if ancien_agent and ancien_agent.pk != agent.pk:
            transaction.on_commit(lambda: notif.notifier_desaffectation(dossier, ancien_agent))
    return dossier


@transaction.atomic
def prendre_en_charge(dossier, agent):
    """Un agent se positionne lui-même sur un dossier nouveau de sa zone et de son service."""
    if not regles().get('agent_peut_prendre_en_charge', True):
        raise PermissionDenied("La prise en charge directe par un agent est désactivée.")
    dossier = _verrouiller(dossier)
    _exiger_statut(dossier, {NOUVEAU}, 'prendre en charge')
    if not dans_portee_agent(agent, dossier):
        raise PermissionDenied("Ce dossier n'est pas dans votre zone ou votre service.")
    profil = profil_agent(agent)
    now = timezone.now()
    Intervention.objects.update_or_create(**_lien(dossier), defaults={
        'agent': agent, 'service': profil.service, 'affecte_par': agent,
        'date_affectation': now, 'date_acceptation': now,
    })
    _changer_statut(dossier, ACCEPTE, agent, f'Pris en charge par {profil.service or "un agent"}.')
    return dossier


def _exiger_agent_affecte(dossier, agent):
    inter = _intervention(dossier)
    if not inter or inter.agent_id != agent.pk:
        raise PermissionDenied("Ce dossier ne vous est pas affecté.")
    return inter


@transaction.atomic
def accepter(dossier, agent):
    dossier = _verrouiller(dossier)
    _exiger_statut(dossier, {AFFECTE}, 'accepter')
    inter = _exiger_agent_affecte(dossier, agent)
    inter.date_acceptation = timezone.now()
    inter.save(update_fields=['date_acceptation'])
    _changer_statut(dossier, ACCEPTE, agent, 'Intervention acceptée par un agent.')
    return dossier


@transaction.atomic
def decliner(dossier, agent, motif):
    if not motif:
        raise ValidationError({'motif': 'Le motif est obligatoire.'})
    dossier = _verrouiller(dossier)
    _exiger_statut(dossier, {AFFECTE}, 'décliner')
    inter = _exiger_agent_affecte(dossier, agent)
    inter.agent = None
    inter.date_affectation = None
    inter.save(update_fields=['agent', 'date_affectation'])
    _changer_statut(dossier, NOUVEAU, agent, f'Affectation déclinée : {motif}', visible=False)
    transaction.on_commit(lambda: notif.notifier_superadmins(
        dossier, 'affectation', 'Affectation déclinée', f'{dossier.reference} : {motif}', f'decline:{timezone.now().timestamp()}'))
    return dossier


@transaction.atomic
def demarrer(dossier, agent):
    dossier = _verrouiller(dossier)
    _exiger_statut(dossier, {ACCEPTE}, 'démarrer')
    inter = _exiger_agent_affecte(dossier, agent)
    inter.date_debut = timezone.now()
    inter.save(update_fields=['date_debut'])
    _changer_statut(dossier, EN_COURS, agent, 'Les secours sont en route ou sur place.')
    return dossier


@transaction.atomic
def resoudre(dossier, agent, compte_rendu, difficultes=''):
    compte_rendu = (compte_rendu or '').strip()
    if regles().get('compte_rendu_obligatoire', True) and len(compte_rendu) < 10:
        raise ValidationError({'compte_rendu': 'Rédigez un compte rendu (10 caractères minimum).'})
    dossier = _verrouiller(dossier)
    _exiger_statut(dossier, {ACCEPTE, EN_COURS}, 'clôturer')
    inter = _exiger_agent_affecte(dossier, agent)
    inter.compte_rendu = compte_rendu
    inter.difficultes = (difficultes or '').strip()
    inter.date_fin = timezone.now()
    inter.position_lat = inter.position_lng = inter.position_precision = inter.position_date = None
    inter.save(update_fields=['compte_rendu', 'difficultes', 'date_fin', 'position_lat', 'position_lng',
                              'position_precision', 'position_date'])
    _changer_statut(dossier, RESOLU, agent, 'Intervention terminée.')
    return dossier


POSITION_VALIDITE_MIN = 10


def partager_position(dossier, agent, lat, lng, precision=None):
    """Position de l'agent en route ou sur place, visible du déclarant tant que l'intervention est active."""
    _exiger_statut(dossier, {ACCEPTE, EN_COURS}, 'partager sa position')
    inter = _exiger_agent_affecte(dossier, agent)
    Intervention.objects.filter(pk=inter.pk).update(
        position_lat=lat, position_lng=lng, position_precision=precision, position_date=timezone.now())
    inter.refresh_from_db()
    return inter


@transaction.atomic
def evaluer(dossier, citoyen, note, commentaire=''):
    dossier = _verrouiller(dossier)
    if dossier.citoyen_id != citoyen.pk:
        raise PermissionDenied('Seul le déclarant peut évaluer cette intervention.')
    _exiger_statut(dossier, {RESOLU}, 'évaluer')
    inter = _intervention(dossier)
    if inter is None:
        raise Conflit('Aucune intervention à évaluer pour ce dossier.')
    if inter.note_satisfaction is not None:
        raise Conflit('Vous avez déjà évalué cette intervention.')
    inter.note_satisfaction, inter.commentaire_satisfaction = note, (commentaire or '').strip()[:500]
    inter.date_evaluation = timezone.now()
    inter.save(update_fields=['note_satisfaction', 'commentaire_satisfaction', 'date_evaluation'])
    evenement(dossier, 'evaluation', citoyen, f'Évaluation du citoyen : {note}/5.'
              + (f' « {inter.commentaire_satisfaction} »' if inter.commentaire_satisfaction else ''))
    if inter.agent_id:
        agent = inter.agent
        transaction.on_commit(lambda: notif.notifier(
            [agent], 'statut', f'Votre intervention {dossier.reference} a été notée {note}/5', '', dossier,
            f'evaluation:{dossier.reference}'))
    return dossier


@transaction.atomic
def annuler(dossier, acteur, motif):
    if not motif:
        raise ValidationError({'motif': "Le motif d'annulation est obligatoire."})
    dossier = _verrouiller(dossier)
    if acteur.role == ROLE_SUPERADMIN:
        _exiger_statut(dossier, STATUTS_ACTIFS, 'annuler')
    elif dossier.citoyen_id == acteur.pk:
        if not regles().get('citoyen_peut_annuler', True):
            raise PermissionDenied("L'annulation par le citoyen est désactivée.")
        _exiger_statut(dossier, {NOUVEAU, AFFECTE}, 'annuler')
    else:
        raise PermissionDenied("Vous ne pouvez pas annuler ce dossier.")
    _changer_statut(dossier, ANNULE, acteur, f'Annulé : {motif}', motif=motif)
    inter = _intervention(dossier)
    if inter and inter.agent_id and inter.agent_id != acteur.pk:
        transaction.on_commit(lambda: notif.notifier_desaffectation(dossier, inter.agent))
    return dossier


@transaction.atomic
def rejeter(dossier, acteur, motif):
    if not motif:
        raise ValidationError({'motif': 'Le motif est obligatoire.'})
    dossier = _verrouiller(dossier)
    _exiger_statut(dossier, {NOUVEAU}, 'rejeter')
    _changer_statut(dossier, REFUSE, acteur, f'Signalement rejeté : {motif}', motif=motif)
    return dossier


@transaction.atomic
def changer_gravite(dossier, acteur, gravite):
    dossier = _verrouiller(dossier)
    _exiger_statut(dossier, STATUTS_ACTIFS, 'modifier la gravité')
    avant = dossier.gravite
    dossier.gravite = gravite
    dossier.save(update_fields=['gravite'])
    evenement(dossier, 'gravite', acteur, f'Gravité : {avant} → {gravite}.', visible=False)
    return dossier


def ajouter_note(dossier, acteur, message, visible_citoyen=False):
    message = (message or '').strip()
    if not message:
        raise ValidationError({'message': 'Le message est vide.'})
    ev = evenement(dossier, 'note', acteur, message[:2000], visible=visible_citoyen)
    if visible_citoyen and dossier.citoyen_id:
        transaction.on_commit(lambda: notif.notifier(
            [dossier.citoyen], 'statut', f'Mise à jour de {dossier.reference}', message[:200], dossier,
            f'note:{ev.pk}'))
    return ev


def completer(dossier, citoyen, message):
    """Information complémentaire du citoyen sur son propre dossier encore ouvert."""
    if dossier.citoyen_id != citoyen.pk:
        raise PermissionDenied("Ce dossier ne vous appartient pas.")
    if dossier.statut in STATUTS_FINAUX:
        raise Conflit('Ce dossier est clos : il ne peut plus être complété.')
    message = (message or '').strip()
    if not message:
        raise ValidationError({'message': 'Le complément est vide.'})
    ev = evenement(dossier, 'complement', citoyen, message[:2000])
    inter = _intervention(dossier)
    if inter and inter.agent_id:
        agent = inter.agent
        transaction.on_commit(lambda: notif.notifier(
            [agent], 'complement', f'Complément sur {dossier.reference}', message[:200], dossier, f'complement:{ev.pk}'))
    return ev
