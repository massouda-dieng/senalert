from rest_framework.permissions import BasePermission

from .constants import ROLE_AGENT, ROLE_CITOYEN, ROLE_SUPERADMIN, ROLE_SUPERVISEUR, ROLES_SUPERVISION


def est_superadmin(user):
    return bool(user and user.is_authenticated and user.role == ROLE_SUPERADMIN)


def est_superviseur(user):
    return bool(user and user.is_authenticated and user.role == ROLE_SUPERVISEUR)


def est_supervision(user):
    """Superadministrateur (tout le pays) ou superviseur de structure (sa structure seulement)."""
    return bool(user and user.is_authenticated and user.role in ROLES_SUPERVISION)


def est_agent(user):
    return bool(user and user.is_authenticated and user.role == ROLE_AGENT)


def est_citoyen(user):
    return bool(user and user.is_authenticated and user.role == ROLE_CITOYEN)


class EstSuperAdmin(BasePermission):
    message = "Action réservée au superadministrateur."

    def has_permission(self, request, view):
        return est_superadmin(request.user)


class EstSupervision(BasePermission):
    message = "Action réservée à la supervision."

    def has_permission(self, request, view):
        return est_supervision(request.user)


class EstAgentOuSupervision(BasePermission):
    message = "Action réservée aux agents et à la supervision."

    def has_permission(self, request, view):
        return est_agent(request.user) or est_supervision(request.user)


class EstAgent(BasePermission):
    message = "Action réservée aux agents de secours."

    def has_permission(self, request, view):
        return est_agent(request.user)


class EstCitoyen(BasePermission):
    message = "Action réservée aux citoyens."

    def has_permission(self, request, view):
        return est_citoyen(request.user)


class EstAgentOuSuperAdmin(BasePermission):
    message = "Action réservée aux agents et au superadministrateur."

    def has_permission(self, request, view):
        return est_agent(request.user) or est_superadmin(request.user)
