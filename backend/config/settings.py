"""
Configuration Django de SenAlert.

Toutes les valeurs sensibles ou dépendantes de l'environnement sont lues dans
le fichier .env (voir .env.example). Aucun secret ne doit être écrit ici.
"""

import os
from datetime import timedelta
from pathlib import Path

from decouple import Csv, config
from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent
PROJECT_DIR = BASE_DIR.parent

DEBUG = config('DEBUG', default=False, cast=bool)

_INSECURE_KEY = 'dev-only-insecure-key-ne-pas-utiliser-en-production'
SECRET_KEY = config('SECRET_KEY', default=_INSECURE_KEY)
if not DEBUG and SECRET_KEY == _INSECURE_KEY:
    raise ImproperlyConfigured('SECRET_KEY doit être défini dans .env lorsque DEBUG=False.')

ALLOWED_HOSTS = config(
    'ALLOWED_HOSTS',
    default='127.0.0.1,localhost,10.0.2.2',
    cast=Csv(),
)
if DEBUG and '0.0.0.0' not in ALLOWED_HOSTS:
    # `runserver 0.0.0.0:8000` affiche cette adresse : on l'accepte en développement uniquement.
    ALLOWED_HOSTS.append('0.0.0.0')

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # Bibliothèques
    'rest_framework',
    'rest_framework_simplejwt.token_blacklist',
    'django_filters',
    'drf_spectacular',
    'corsheaders',
    # Apps SenAlert
    'core',
    'accounts',
    'alerts',
    'incidents',
    'notifications',
    'analyse',
    'dashboard',
]

MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'

# --- Base de données -------------------------------------------------------
# SQLite par défaut (développement). PostgreSQL dès que DB_ENGINE=postgresql.
DB_ENGINE = config('DB_ENGINE', default='sqlite')
if DB_ENGINE == 'postgresql':
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.postgresql',
            'NAME': config('DB_NAME', default='senalert'),
            'USER': config('DB_USER', default='senalert'),
            'PASSWORD': config('DB_PASSWORD', default=''),
            'HOST': config('DB_HOST', default='localhost'),
            'PORT': config('DB_PORT', default='5432'),
            'CONN_MAX_AGE': 60,
            'ATOMIC_REQUESTS': False,
        }
    }
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator', 'OPTIONS': {'min_length': 8}},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

LANGUAGE_CODE = 'fr-fr'
TIME_ZONE = 'Africa/Dakar'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
WEB_DIST_DIR = PROJECT_DIR / 'web' / 'dist'
STATICFILES_DIRS = [WEB_DIST_DIR] if WEB_DIST_DIR.exists() else []
STORAGES = {
    'default': {'BACKEND': 'django.core.files.storage.FileSystemStorage'},
    'staticfiles': {'BACKEND': 'whitenoise.storage.CompressedStaticFilesStorage'},
}

# Les pièces jointes ne sont JAMAIS servies publiquement : elles passent par
# une vue qui vérifie les permissions (incidents.views.PieceJointeFichierView).
MEDIA_ROOT = config('MEDIA_ROOT', default=str(BASE_DIR / 'media'))
MEDIA_URL = '/media-prive/'
FILE_UPLOAD_MAX_MEMORY_SIZE = 5 * 1024 * 1024
DATA_UPLOAD_MAX_MEMORY_SIZE = 12 * 1024 * 1024
PIECE_JOINTE_TAILLE_MAX = 5 * 1024 * 1024
PIECES_JOINTES_MAX_PAR_DOSSIER = 5

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
AUTH_USER_MODEL = 'accounts.User'
LOGIN_URL = '/admin/login/'

# --- CORS ------------------------------------------------------------------
# Le web est servi par Django (même origine) ou par Vite via un proxy : aucun
# besoin d'ouvrir CORS à tous. En développement, seules les origines locales
# (Flutter web sur un port aléatoire) sont autorisées.
CORS_ALLOW_ALL_ORIGINS = False
CORS_ALLOWED_ORIGINS = config('CORS_ALLOWED_ORIGINS', default='', cast=Csv())
if DEBUG:
    CORS_ALLOWED_ORIGIN_REGEXES = [r'^http://(localhost|127\.0\.0\.1)(:\d+)?$']

# --- DRF / JWT -------------------------------------------------------------
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PERMISSION_CLASSES': [
        'rest_framework.permissions.IsAuthenticated',
    ],
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.OrderingFilter',
    ],
    'DEFAULT_PAGINATION_CLASS': 'core.pagination.Pagination',
    'PAGE_SIZE': 20,
    'DEFAULT_SCHEMA_CLASS': 'drf_spectacular.openapi.AutoSchema',
    'EXCEPTION_HANDLER': 'core.exceptions.gestionnaire_exceptions',
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': config('THROTTLE_ANON', default='60/min'),
        'user': config('THROTTLE_USER', default='600/min'),
        'connexion': config('THROTTLE_CONNEXION', default='10/min'),
        'inscription': config('THROTTLE_INSCRIPTION', default='10/hour'),
        'mot_de_passe': config('THROTTLE_MOT_DE_PASSE', default='5/hour'),
        'sos': config('THROTTLE_SOS', default='10/hour'),
        'signalement': config('THROTTLE_SIGNALEMENT', default='30/hour'),
        'assistant': config('THROTTLE_ASSISTANT', default='20/min'),
        'assistant_jour': config('THROTTLE_ASSISTANT_JOUR', default='200/day'),
        'services': config('THROTTLE_SERVICES', default='30/min'),
    },
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=config('JWT_ACCESS_MINUTES', default=15, cast=int)),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=config('JWT_REFRESH_DAYS', default=7, cast=int)),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'UPDATE_LAST_LOGIN': True,
    'USER_ID_CLAIM': 'user_id',
}

SPECTACULAR_SETTINGS = {
    'TITLE': 'API SenAlert',
    'DESCRIPTION': "API REST de la plateforme SenAlert (signalement et suivi des urgences au Sénégal).",
    'VERSION': '3.0.0',
    'SERVE_INCLUDE_SCHEMA': False,
    'SERVE_PERMISSIONS': ['rest_framework.permissions.AllowAny'],
    'COMPONENT_SPLIT_REQUEST': True,
    'ENUM_NAME_OVERRIDES': {
        'GraviteEnum': 'core.constants.GRAVITE_CHOICES',
        'RoleEnum': 'core.constants.ROLE_CHOICES',
        'StatutEnum': 'core.constants.STATUT_CHOICES',
        'RegionEnum': 'core.constants.REGION_CHOICES',
    },
}

CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
        'LOCATION': 'senalert',
    }
}

# --- E-mail (réinitialisation du mot de passe) ------------------------------
# Sans SMTP configuré, les e-mails sont affichés dans la console du serveur.
EMAIL_BACKEND = config('EMAIL_BACKEND', default='django.core.mail.backends.console.EmailBackend')
EMAIL_HOST = config('EMAIL_HOST', default='')
EMAIL_PORT = config('EMAIL_PORT', default=587, cast=int)
EMAIL_HOST_USER = config('EMAIL_HOST_USER', default='')
EMAIL_HOST_PASSWORD = config('EMAIL_HOST_PASSWORD', default='')
EMAIL_USE_TLS = config('EMAIL_USE_TLS', default=True, cast=bool)
DEFAULT_FROM_EMAIL = config('DEFAULT_FROM_EMAIL', default='SenAlert <no-reply@senalert.local>')
FRONTEND_URL = config('FRONTEND_URL', default='http://127.0.0.1:8000/app')
PASSWORD_RESET_TIMEOUT = 60 * 60  # 1 heure

# --- Google (OpenID Connect) -------------------------------------------------
# Identifiants client OAuth (publics). Le backend vérifie que l'audience du
# jeton d'identité correspond à l'un d'eux.
GOOGLE_CLIENT_ID_WEB = config('GOOGLE_CLIENT_ID_WEB', default='')
GOOGLE_CLIENT_IDS = [c for c in [GOOGLE_CLIENT_ID_WEB, *config('GOOGLE_CLIENT_IDS_MOBILE', default='', cast=Csv())] if c]

# --- Firebase Cloud Messaging -----------------------------------------------
FIREBASE_CREDENTIALS_PATH = config('FIREBASE_CREDENTIALS_PATH', default='firebase-adminsdk.json')

# --- Assistant IA (Groq) ----------------------------------------------------
GROQ_API_KEY = config('GROQ_API_KEY', default='')
GROQ_MODEL = config('GROQ_MODEL', default='qwen/qwen3.8-27b')
GROQ_TIMEOUT = config('GROQ_TIMEOUT', default=15, cast=int)

# --- Services de proximité (OpenStreetMap / Overpass) -----------------------
OVERPASS_URL = config('OVERPASS_URL', default='https://overpass-api.de/api/interpreter')

# --- Sécurité en production -------------------------------------------------
SESSION_COOKIE_HTTPONLY = True
CSRF_COOKIE_HTTPONLY = False
X_FRAME_OPTIONS = 'DENY'
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = 'same-origin'
if not DEBUG:
    SECURE_SSL_REDIRECT = config('SECURE_SSL_REDIRECT', default=True, cast=bool)
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = config('SECURE_HSTS_SECONDS', default=31536000, cast=int)
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    CSRF_TRUSTED_ORIGINS = config('CSRF_TRUSTED_ORIGINS', default='', cast=Csv())

# --- Journalisation ---------------------------------------------------------
# Le filtre RedactionSecrets masque mots de passe, jetons et clés dans les logs.
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'filters': {
        'redaction': {'()': 'core.logging.RedactionSecrets'},
    },
    'formatters': {
        'simple': {'format': '{asctime} {levelname} {name} — {message}', 'style': '{'},
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'simple',
            'filters': ['redaction'],
        },
    },
    'root': {'handlers': ['console'], 'level': 'INFO'},
    'loggers': {
        'django.request': {'handlers': ['console'], 'level': 'WARNING', 'propagate': False},
    },
}

TESTING = os.environ.get('SENALERT_TESTING') == '1'
if TESTING:
    PASSWORD_HASHERS = ['django.contrib.auth.hashers.MD5PasswordHasher']  # tests rapides uniquement
    MEDIA_ROOT = str(BASE_DIR / '.media-tests')
    GROQ_API_KEY = ''
    GOOGLE_CLIENT_ID_WEB = ''
    GOOGLE_CLIENT_IDS = []
    EMAIL_BACKEND = 'django.core.mail.backends.locmem.EmailBackend'
    LOGGING['root']['level'] = 'CRITICAL'
