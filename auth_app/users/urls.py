from django.urls import path
from .views import health_check, status_view, data_view, error_view

urlpatterns = [
    path('', health_check, name='health_check'),
    path('status', status_view, name='status'),
    path('data', data_view, name='data'),
    path('error', error_view, name='error'),
]
