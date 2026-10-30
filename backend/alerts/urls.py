from rest_framework.routers import DefaultRouter

from .views import AlerteSOSViewSet

router = DefaultRouter()
router.register('sos', AlerteSOSViewSet, basename='sos')
urlpatterns = router.urls
