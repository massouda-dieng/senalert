from rest_framework.throttling import ScopedRateThrottle, UserRateThrottle


class ThrottleAssistantJour(UserRateThrottle):
    scope = 'assistant_jour'


__all__ = ['ScopedRateThrottle', 'ThrottleAssistantJour']
