"""Création des notifications et envoi push (Firebase Cloud Messaging).

Les fonctions publiques ne lèvent jamais d'exception : une notification qui
échoue est journalisée avec son statut, sans jamais affecter le dossier.
"""

import logging
import os

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone

from core.constants import ROLE_AGENT, ROLE_SUPERADMIN, RESOLU

from .models import Notification

logger = logging.getLogger('senalert.notifications')

_firebase_pret = None


def firebase_pret():
    """Initialise Firebase Admin à la première utilisation. Retourne False s'il n'est pas configuré."""
    global _firebase_pret
    if _firebase_pret is not None:
        return _firebase_pret
    _firebase_pret = False
    if getattr(settings, 'TESTING', False):
        return False
    chemin = settings.FIREBASE_CREDENTIALS_PATH
    if not os.path.isabs(chemin):
        chemin = os.path.join(settings.BASE_DIR, chemin)
    if not os.path.exists(chemin):
        logger.info('Firebase non configuré (fichier de compte de service absent) : push désactivé.')
        return False
    try:
        import firebase_admin
        from firebase_admin import credentials
        if not firebase_admin._apps:
            firebase_admin.initialize_app(credentials.Certificate(chemin))
        _firebase_pret = True
    except Exception as exc:  # configuration invalide
        logger.warning('Initialisation Firebase impossible : %s', exc.__class__.__name__)
    return _firebase_pret


def envoyer_push(notification):
    """Tente l'envoi FCM et enregistre le résultat. « envoyee » = accepté par FCM, pas lu."""
    user = notification.destinataire
    try:
        if not (user.preferences or {}).get('notifications_push', True):
            statut, erreur = 'desactivee', ''
        else:
            tokens = list(user.device_tokens.filter(actif=True).values_list('token', flat=True))
            if not tokens:
                statut, erreur = 'aucun_appareil', ''
            elif not firebase_pret():
                statut, erreur = 'non_configure', ''
            else:
                statut, erreur = _envoyer_fcm(notification, tokens, user)
    except Exception as exc:
        logger.exception('Échec inattendu de l’envoi push')
        statut, erreur = 'echec', exc.__class__.__name__
    Notification.objects.filter(pk=notification.pk).update(statut_push=statut, erreur_push=erreur[:255])
    return statut


def _envoyer_fcm(notification, tokens, user):
    from firebase_admin import messaging

    dossier = notification.incident or notification.alerte
    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=notification.titre, body=notification.message),
        data={
            'type': notification.type,
            'notification_id': str(notification.pk),
            'dossier': 'incident' if notification.incident_id else ('sos' if notification.alerte_id else ''),
            'dossier_id': str(dossier.pk) if dossier else '',
        },
        tokens=tokens,
    )
    reponse = messaging.send_each_for_multicast(message)
    invalides = [
        tokens[i] for i, r in enumerate(reponse.responses)
        if not r.success and r.exception is not None
        and r.exception.__class__.__name__ in ('UnregisteredError', 'SenderIdMismatchError', 'InvalidArgumentError')
    ]
    if invalides:
        user.device_tokens.filter(token__in=invalides).update(actif=False)
    if reponse.success_count:
        return 'envoyee', ''
    return 'echec', f'{reponse.failure_count} échec(s) FCM'


def notifier(destinataires, type_, titre, message, dossier=None, cle=''):
    """Crée une notification par destinataire (dédupliquée par clé) puis tente le push."""
    from incidents.models import Incident

    creees = []
    for user in {u.pk: u for u in destinataires if u is not None}.values():
        lien = {}
        if dossier is not None:
            lien = {'incident': dossier} if isinstance(dossier, Incident) else {'alerte': dossier}
        try:
            with transaction.atomic():
                n = Notification.objects.create(
                    destinataire=user, type=type_, titre=titre[:120], message=message[:500],
                    cle_deduplication=(cle or f'{type_}:{titre}')[:120], **lien,
                )
        except IntegrityError:
            continue  # déjà notifié pour cet événement
        except Exception:
            logger.exception('Création de notification impossible')
            continue
        creees.append(n)
    for n in creees:
        envoyer_push(n)
    return creees


def _nom_dossier(dossier):
    from incidents.models import Incident
    if isinstance(dossier, Incident):
        return f'Incident {dossier.reference}'
    return f'Alerte SOS {dossier.reference}'


def agents_concernes(dossier):
    from accounts.models import User
    from incidents.models import Incident

    qs = User.objects.filter(role=ROLE_AGENT, is_active=True).select_related('profil_agent')
    elus = []
    for agent in qs:
        profil = getattr(agent, 'profil_agent', None)
        if not profil or dossier.region not in (profil.zones or []):
            continue
        if isinstance(dossier, Incident) and profil.service_id != dossier.service_id:
            continue
        elus.append(agent)
    return elus


def superadmins():
    from accounts.models import User
    return list(User.objects.filter(role=ROLE_SUPERADMIN, is_active=True))


def notifier_nouveau_dossier(dossier):
    try:
        from incidents.models import Incident
        sos = not isinstance(dossier, Incident)
        titre = 'Nouvelle alerte SOS' if sos else f'Nouveau signalement : {dossier.type_incident}'
        zone = dossier.get_region_display() if dossier.region else 'zone inconnue'
        destinataires = agents_concernes(dossier) + (superadmins() if sos else [])
        notifier(destinataires, 'nouvelle_alerte', titre, f'{dossier.reference} — {zone}', dossier, f'nouveau:{dossier.reference}')
    except Exception:
        logger.exception('Notification de nouveau dossier impossible')


def notifier_affectation(dossier, agent):
    try:
        notifier([agent], 'affectation', 'Nouvelle intervention affectée',
                 f'{_nom_dossier(dossier)} vous a été affecté.', dossier,
                 f'affectation:{dossier.reference}:{agent.pk}:{timezone.now().timestamp()}')
    except Exception:
        logger.exception("Notification d'affectation impossible")


def notifier_desaffectation(dossier, agent):
    try:
        notifier([agent], 'affectation', 'Intervention retirée',
                 f"{_nom_dossier(dossier)} ne vous est plus affecté.", dossier,
                 f'desaffectation:{dossier.reference}:{agent.pk}:{timezone.now().timestamp()}')
    except Exception:
        logger.exception('Notification de désaffectation impossible')


def notifier_citoyen_statut(dossier, statut):
    try:
        if not dossier.citoyen or not (dossier.citoyen.preferences or {}).get('notifications_statut', True):
            return
        from incidents.workflow import LIBELLES_STATUT
        type_ = 'resolution' if statut == RESOLU else 'statut'
        notifier([dossier.citoyen], type_, f'{_nom_dossier(dossier)}',
                 f'Nouveau statut : {LIBELLES_STATUT.get(statut, statut)}.', dossier,
                 f'statut:{dossier.reference}:{statut}')
    except Exception:
        logger.exception('Notification de statut impossible')


def notifier_superadmins(dossier, type_, titre, message, cle):
    try:
        notifier(superadmins(), type_, titre, message, dossier, cle)
    except Exception:
        logger.exception('Notification des superadministrateurs impossible')


def notifier_alerte_zone(alerte):
    """Prévient les citoyens et agents des régions concernées (préférences respectées)."""
    try:
        from accounts.models import User
        from core.constants import ROLE_AGENT, ROLE_CITOYEN

        qs = User.objects.filter(is_active=True, role__in=[ROLE_CITOYEN, ROLE_AGENT]).select_related('profil_agent')
        cibles = []
        for u in qs:
            zones = (u.profil_agent.zones if getattr(u, 'profil_agent', None) else []) or ([u.region] if u.region else [])
            if not alerte.regions or set(zones) & set(alerte.regions):
                cibles.append(u)
        prefixe = {'danger': '⚠ Danger', 'vigilance': 'Vigilance', 'info': 'Info'}.get(alerte.niveau, 'Alerte')
        notifier(cibles, 'alerte_zone', f'{prefixe} : {alerte.titre}', alerte.message[:500], None, f'alerte_zone:{alerte.pk}')
    except Exception:
        logger.exception("Notification d'alerte de zone impossible")
