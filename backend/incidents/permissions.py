from rest_framework.permissions import BasePermission, SAFE_METHODS


class IsOwnerOrAdminOrReadOnly(BasePermission):
    """
    Permission personnalisée SenAlert :
    - Lecture (GET, HEAD, OPTIONS) : autorisée pour tout utilisateur authentifié
    - Modification / Suppression : uniquement le propriétaire de l'incident ou un admin
    - Les autorités (rôle 'autorite') peuvent mettre à jour le statut mais pas supprimer
    """

    def has_permission(self, request, view):
        # Bloquer les non-authentifiés sur toutes les méthodes sauf lecture
        if request.method in SAFE_METHODS:
            return True
        return request.user and request.user.is_authenticated

    def has_object_permission(self, request, view, obj):
        # Lecture toujours autorisée
        if request.method in SAFE_METHODS:
            return True

        user = request.user
        if not user or not user.is_authenticated:
            return False

        # Admin ou superuser : accès total
        if user.is_staff or user.is_superuser or user.role == 'admin':
            return True

        # Autorité : peut mettre à jour le statut (PATCH/PUT) mais pas supprimer
        if hasattr(user, 'role') and user.role == 'autorite':
            return request.method in ('PUT', 'PATCH')

        # Citoyen propriétaire : peut modifier ou supprimer son propre incident
        return obj.citoyen == user
