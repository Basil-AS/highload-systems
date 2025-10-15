from django.contrib import admin
from django.urls import path, include
from django.views.generic import TemplateView
from users import views as user_views
from django.views.decorators.csrf import csrf_exempt

urlpatterns = [
    path('admin/', admin.site.urls),
    path('accounts/', include('allauth.urls')),
    path('', TemplateView.as_view(template_name='home.html'), name='home'),
    path('dashboard/', TemplateView.as_view(template_name='dashboard.html'), name='dashboard'),
    path('login/', TemplateView.as_view(template_name='account/login.html'), name='login'),
    path('register/', TemplateView.as_view(template_name='account/signup.html'), name='register'),
    path('health/', include('users.urls')),
    # LR2 endpoints
    path('status', user_views.status_view, name='lr2_status'),
    path('data', csrf_exempt(user_views.data_view), name='lr2_data'),
    path('error', user_views.error_view, name='lr2_error'),
]
