from pathlib import Path
import os

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR.parent / ".env")

SECRET_KEY = os.getenv("SECRET_KEY", "django-insecure-dev-only-change-in-production")
DEBUG = os.getenv("DEBUG", "True").lower() == "true"
ALLOWED_HOSTS = [h.strip() for h in os.getenv("ALLOWED_HOSTS", "localhost,127.0.0.1").split(",") if h.strip()]

_db_url = os.getenv("DATABASE_URL", "")
USE_POSTGIS = _db_url.startswith("postgresql") and os.getenv("USE_POSTGIS", "true").lower() == "true"

ML_MODELS_ROOT = BASE_DIR.parent / "ml" / "models"
ML_PROPHET_GRANULARITY = os.getenv("ML_PROPHET_GRANULARITY", "hourly")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    *([] if not USE_POSTGIS else ["django.contrib.gis"]),
    "rest_framework",
    "corsheaders",
    "drf_spectacular",
    "channels",
    "accounts",
    "stations",
    "vehicles",
    "operations",
    "forecasting",
    "crowd",
    "crisis",
    "pricing",
    "realtime",
    "analytics",
]

ASGI_APPLICATION = "config.asgi.application"

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

# PostgreSQL when DATABASE_URL set; SQLite fallback for local dev without Docker
if _db_url.startswith("postgresql"):
    _pg_engine = (
        "django.contrib.gis.db.backends.postgis"
        if USE_POSTGIS
        else "django.db.backends.postgresql"
    )
    DATABASES = {
        "default": {
            "ENGINE": _pg_engine,
            "NAME": os.getenv("POSTGRES_DB", "fuelsense"),
            "USER": os.getenv("POSTGRES_USER", "fuelsense"),
            "PASSWORD": os.getenv("POSTGRES_PASSWORD", "fuelsense_dev"),
            "HOST": os.getenv("POSTGRES_HOST", "localhost"),
            "PORT": os.getenv("POSTGRES_PORT", "5432"),
        }
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }

AUTH_USER_MODEL = "accounts.User"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "en-us"
TIME_ZONE = "Asia/Colombo"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

CORS_ALLOWED_ORIGINS = [
    o.strip() for o in os.getenv("CORS_ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8080").split(",") if o.strip()
]

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.IsAuthenticated",),
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
}

from datetime import timedelta  # noqa: E402

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=int(os.getenv("JWT_ACCESS_TOKEN_LIFETIME_MINUTES", "15"))),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=int(os.getenv("JWT_REFRESH_TOKEN_LIFETIME_DAYS", "7"))),
}

SPECTACULAR_SETTINGS = {
    "TITLE": "FuelSense LK API",
    "DESCRIPTION": "Fuel availability monitoring and demand forecasting API",
    "VERSION": "0.3.0",
}

_broker = os.getenv("CELERY_BROKER_URL", "redis://localhost:6379/1")
CELERY_BROKER_URL = _broker
CELERY_RESULT_BACKEND = os.getenv("CELERY_RESULT_BACKEND", _broker)
CELERY_TIMEZONE = TIME_ZONE
CELERY_BEAT_SCHEDULE = {
    "prophet-nightly": {
        "task": "forecasting.run_prophet_forecasts",
        "schedule": 86400.0,  # daily; replace with crontab when celery beat configured
    },
    "lstm-hourly": {
        "task": "forecasting.run_depletion_risk",
        "schedule": 3600.0,
    },
}

_redis_url = os.getenv("REDIS_URL", "")
if _redis_url:
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {"hosts": [_redis_url]},
        }
    }
else:
    CHANNEL_LAYERS = {
        "default": {"BACKEND": "channels.layers.InMemoryChannelLayer"},
    }
