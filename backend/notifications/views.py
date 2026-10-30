from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import mixins, serializers, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Notification


class NotificationSerializer(serializers.ModelSerializer):
    dossier = serializers.SerializerMethodField()

    class Meta:
        model = Notification
        fields = ['id', 'type', 'titre', 'message', 'lue', 'date_lecture', 'statut_push', 'date_creation', 'dossier']

    def get_dossier(self, obj) -> dict | None:
        if obj.incident_id:
            return {'type': 'incident', 'id': obj.incident_id}
        if obj.alerte_id:
            return {'type': 'sos', 'id': obj.alerte_id}
        return None


class NotificationViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """Notifications de l'utilisateur connecté uniquement."""

    serializer_class = NotificationSerializer

    def get_queryset(self):
        if getattr(self, 'swagger_fake_view', False):
            return Notification.objects.none()
        qs = Notification.objects.filter(destinataire=self.request.user)
        if self.request.query_params.get('non_lues') in ('1', 'true'):
            qs = qs.filter(lue=False)
        return qs

    @action(detail=True, methods=['post'])
    def lire(self, request, pk=None):
        n = get_object_or_404(self.get_queryset(), pk=pk)
        if not n.lue:
            n.lue, n.date_lecture = True, timezone.now()
            n.save(update_fields=['lue', 'date_lecture'])
        return Response(self.get_serializer(n).data)

    @action(detail=False, methods=['post'], url_path='tout-lire')
    def tout_lire(self, request):
        nb = self.get_queryset().filter(lue=False).update(lue=True, date_lecture=timezone.now())
        return Response({'marquees': nb})

    @action(detail=False, methods=['get'])
    def compteur(self, request):
        return Response({'non_lues': Notification.objects.filter(destinataire=request.user, lue=False).count()})
