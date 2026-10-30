from rest_framework.routers import DefaultRouter

from .communaute import CommunauteViewSet
from .views import IncidentViewSet

router = DefaultRouter()
router.register('communaute', CommunauteViewSet, basename='communaute')
router.register('', IncidentViewSet, basename='incident')
urlpatterns = router.urls
