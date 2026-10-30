from .models import JournalAudit


def adresse_ip(request):
    if request is None:
        return None
    return request.META.get('REMOTE_ADDR')


def journaliser(request, action, cible=None, details=None, acteur=None):
    """Enregistre une opération sensible dans le journal d'audit."""
    if acteur is None and request is not None and getattr(request, 'user', None) and request.user.is_authenticated:
        acteur = request.user
    return JournalAudit.objects.create(
        acteur=acteur,
        action=action,
        cible_type=cible.__class__.__name__ if cible is not None else '',
        cible_id=str(getattr(cible, 'pk', '') or '') if cible is not None else '',
        details=details or {},
        adresse_ip=adresse_ip(request),
    )
