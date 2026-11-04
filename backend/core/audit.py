from .models import JournalAudit

# Libellé lisible et rubrique de chaque action tracée (affichage du journal d'audit).
ACTIONS = {
    'compte.connexion': ('Connexion', 'connexions'),
    'compte.connexion_google': ('Connexion avec Google', 'connexions'),
    'compte.echec_connexion': ('Échec de connexion', 'connexions'),
    'compte.deconnexion_toutes_sessions': ('Déconnexion de toutes les sessions', 'connexions'),
    'compte.inscription': ('Inscription', 'comptes'),
    'compte.inscription_google': ('Inscription avec Google', 'comptes'),
    'compte.modification_profil': ('Modification du profil', 'comptes'),
    'compte.changement_mot_de_passe': ('Changement de mot de passe', 'comptes'),
    'compte.demande_reinitialisation': ('Demande de réinitialisation du mot de passe', 'comptes'),
    'compte.reinitialisation_mot_de_passe': ('Réinitialisation du mot de passe', 'comptes'),
    'compte.liaison_google': ('Liaison du compte Google', 'comptes'),
    'compte.deliaison_google': ('Retrait du compte Google', 'comptes'),
    'compte.suppression': ('Suppression du compte', 'comptes'),
    'admin.creation_agent': ('Création d’un compte agent', 'comptes'),
    'admin.creation_superviseur': ('Création d’un compte superviseur', 'comptes'),
    'admin.modification_utilisateur': ('Modification d’un compte ou de ses permissions', 'comptes'),
    'admin.provisionnement_superadmin': ('Création du superadministrateur', 'comptes'),
    'agent.disponibilite': ('Changement de disponibilité', 'comptes'),
    'incident.creation': ('Signalement d’incident', 'signalements'),
    'sos.envoi': ('Envoi d’une alerte SOS', 'signalements'),
    'dossier.affectation': ('Affectation à un agent ou une structure', 'traitement'),
    'dossier.prise_en_charge': ('Prise en charge', 'traitement'),
    'dossier.acceptation': ('Prise en charge (acceptation)', 'traitement'),
    'dossier.refus_affectation': ('Affectation déclinée', 'traitement'),
    'dossier.demarrage': ('Intervention démarrée', 'traitement'),
    'dossier.cloture': ('Clôture (résolu)', 'traitement'),
    'dossier.annulation': ('Annulation', 'traitement'),
    'dossier.rejet': ('Rejet', 'traitement'),
    'dossier.gravite': ('Changement de gravité', 'traitement'),
    'config.creation_structure': ('Création d’une structure', 'configuration'),
    'config.modification_structure': ('Modification d’une structure', 'configuration'),
    'config.creation_service': ('Création d’un service', 'configuration'),
    'config.modification_service': ('Modification d’un service', 'configuration'),
    'config.creation_categorie': ('Création d’une catégorie', 'configuration'),
    'config.modification_categorie': ('Modification d’une catégorie', 'configuration'),
    'config.modification_parametre': ('Modification d’un paramètre', 'configuration'),
    'alerte_zone.publication': ('Publication d’une alerte de zone', 'configuration'),
    'alerte_zone.modification': ('Modification d’une alerte de zone', 'configuration'),
    'alerte_zone.fin': ('Fin d’une alerte de zone', 'configuration'),
}
RUBRIQUES = {
    'connexions': 'Connexions', 'comptes': 'Comptes et permissions', 'signalements': 'Signalements et SOS',
    'traitement': 'Traitement des dossiers', 'configuration': 'Structures et configuration', 'autres': 'Autres',
}


def libelle_action(code):
    return ACTIONS.get(code, (code, 'autres'))


def actions_de(rubrique):
    return [code for code, (_, r) in ACTIONS.items() if r == rubrique]


def adresse_ip(request):
    if request is None:
        return None
    return request.META.get('REMOTE_ADDR')


def _libelle_cible(cible):
    if cible is None:
        return ''
    return str(getattr(cible, 'reference', None) or getattr(cible, 'nom', None) or getattr(cible, 'email', None)
               or getattr(cible, 'cle', None) or cible)[:150]


def journaliser(request, action, cible=None, details=None, acteur=None):
    """Enregistre une opération sensible dans le journal d'audit (jamais de mot de passe ni de jeton)."""
    if acteur is None and request is not None and getattr(request, 'user', None) and request.user.is_authenticated:
        acteur = request.user
    return JournalAudit.objects.create(
        acteur=acteur,
        acteur_role=getattr(acteur, 'role', '') or '',
        action=action,
        cible_type=cible.__class__.__name__ if cible is not None else '',
        cible_id=str(getattr(cible, 'pk', '') or '') if cible is not None else '',
        cible_libelle=_libelle_cible(cible),
        details=details or {},
        adresse_ip=adresse_ip(request),
    )
