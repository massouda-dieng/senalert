from rest_framework.routers import DefaultRouter

from .views import AlerteSOSViewSet
from .zone_views import AlerteZoneViewSet

router = DefaultRouter()
router.register('sos', AlerteSOSViewSet, basename='sos')
router.register('zones', AlerteZoneViewSet, basename='alerte-zone')
urlpatterns = router.urls
