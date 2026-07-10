---
description: "Use when working on Django applications targeting Azure. Covers Azure deployment targets, production configuration, PostgreSQL, Entra ID OIDC auth, Redis sessions, and CI/CD."
applyTo: "**/manage.py,**/wsgi.py,**/asgi.py,**/settings.py,**/urls.py"
---

# Django on Azure Standards

Use this instruction when working on Django applications that are deployed to or migrated toward Azure. Covers deployment targets, production hardening, database, authentication, sessions, and CI/CD pipelines.

## Azure Deployment Targets

Django is a server-rendered framework that requires a persistent Python runtime. Choose one of the following Azure targets:

- **Azure App Service (Linux)** — simplest path. Use Python 3.11 or 3.12 runtime. Set the startup command to Gunicorn or Uvicorn.
- **Azure Container Apps** — containerized Django + Gunicorn. Preferred for microservices, sidecars, or when a custom base image is required.

> **Azure Static Web Apps is not a fit for Django.** It supports only static assets and serverless API functions, not server-rendered Python applications.

### App Service startup command examples

For WSGI (synchronous):

```bash
gunicorn myproject.wsgi:application --bind 0.0.0.0:8000 --workers 4
```

For ASGI (async, e.g., Django Channels):

```bash
uvicorn myproject.asgi:application --host 0.0.0.0 --port 8000 --workers 4
```

### Container Apps — minimal Dockerfile

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
RUN python manage.py collectstatic --noinput
EXPOSE 8000
CMD ["gunicorn", "myproject.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "4"]
```

## Production Configuration

Always separate production settings from development settings using `DJANGO_SETTINGS_MODULE`.

```bash
# App Service / Container Apps application setting
DJANGO_SETTINGS_MODULE=myproject.settings.production
```

### Required production settings

```python
# myproject/settings/production.py
import os

DEBUG = False

ALLOWED_HOSTS = os.environ["ALLOWED_HOSTS"].split(",")

CSRF_TRUSTED_ORIGINS = os.environ["CSRF_TRUSTED_ORIGINS"].split(",")

SECURE_HSTS_SECONDS = 31536000          # 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
```

### SECRET_KEY via Azure Key Vault

Do not store `SECRET_KEY` in source control or plain App Service settings. Reference it from Key Vault using an App Service Key Vault reference:

```text
@Microsoft.KeyVault(SecretUri=https://<vault>.vault.azure.net/secrets/django-secret-key/)
```

Set this as the value of the `SECRET_KEY` application setting. App Service resolves the reference at runtime using the app's managed identity. Grant the managed identity `Key Vault Secrets User` on the vault.

### Static files

Run `collectstatic` in CI before deploying; never run it at request time.

- **WhiteNoise** (simplest — no extra Azure resource): add `whitenoise.middleware.WhiteNoiseMiddleware` immediately after `SecurityMiddleware` and set `STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"`.
- **Azure Blob + CDN** (recommended for high-traffic sites): use `django-storages[azure]` with `STATICFILES_STORAGE = "storages.backends.azure_storage.AzureStorage"` and serve via Azure CDN.

```python
# WhiteNoise setup
MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    # ...
]
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"
```

## Database Migration

Replace the default SQLite backend with **Azure Database for PostgreSQL Flexible Server** for any environment beyond local development.

### Driver

Prefer `psycopg` (v3) over `psycopg2-binary`. `psycopg2-binary` ships a bundled C extension unsuitable for production containers and does not support async.

```text
psycopg[binary]>=3.1
dj-database-url>=2.0
```

### DATABASE_URL pattern

Configure the database through a single `DATABASE_URL` environment variable using `dj-database-url`:

```python
import dj_database_url

DATABASES = {
    "default": dj_database_url.config(
        env="DATABASE_URL",
        conn_max_age=600,
        conn_health_checks=True,
    )
}
```

Example connection string (store in App Service application settings or Key Vault):

```text
postgresql+psycopg://myuser:PASSWORD@myserver.postgres.database.azure.com/mydb?sslmode=require
```

### Migrations as a release command

Run `migrate` automatically on each deployment using the App Service startup command or a Container Apps init container. Never rely on developers running migrations manually in production.

```bash
# App Service startup command — run migrate then start Gunicorn
python manage.py migrate --noinput && gunicorn myproject.wsgi:application --bind 0.0.0.0:8000 --workers 4
```

## Auth Modernization

Replace `django.contrib.auth` form-based login with **Entra ID OIDC** for enterprise users. Do not build a custom username/password login flow when Entra ID is available.

### Recommended libraries

- `social-auth-app-django` with the `social_core.backends.microsoft.MicrosoftOAuth2` backend — well-maintained, supports pipeline customization.
- `django-allauth` with the Microsoft provider — simpler if allauth is already in the project.

### social-auth-app-django setup

```python
# settings/production.py
INSTALLED_APPS += ["social_django"]

AUTHENTICATION_BACKENDS = [
    "social_core.backends.microsoft.MicrosoftOAuth2",
    "django.contrib.auth.backends.ModelBackend",
]

SOCIAL_AUTH_MICROSOFT_GRAPH_KEY = os.environ["ENTRA_CLIENT_ID"]
SOCIAL_AUTH_MICROSOFT_GRAPH_SECRET = os.environ["ENTRA_CLIENT_SECRET"]
SOCIAL_AUTH_MICROSOFT_GRAPH_TENANT_ID = os.environ["ENTRA_TENANT_ID"]

SOCIAL_AUTH_PIPELINE = (
    "social_core.pipeline.social_auth.social_details",
    "social_core.pipeline.social_auth.social_uid",
    "social_core.pipeline.social_auth.auth_allowed",
    "social_core.pipeline.social_auth.social_user",
    "social_core.pipeline.user.get_username",
    "social_core.pipeline.user.create_user",       # auto-create on first login
    "social_core.pipeline.social_auth.associate_user",
    "myproject.pipeline.map_entra_roles_to_groups", # custom step
    "social_core.pipeline.social_auth.load_extra_data",
    "social_core.pipeline.user.user_details",
)
```

### Map Entra ID app roles to Django groups

```python
# myproject/pipeline.py
from django.contrib.auth.models import Group

def map_entra_roles_to_groups(backend, user, response, *args, **kwargs):
    """Sync Entra ID app roles from the token claims to Django groups."""
    roles = response.get("roles", [])
    for role in roles:
        group, _ = Group.objects.get_or_create(name=role)
        user.groups.add(group)
    # Remove groups that are no longer in the token
    current_role_names = set(roles)
    for group in user.groups.all():
        if group.name not in current_role_names:
            user.groups.remove(group)
```

### urls.py

```python
from django.urls import path, include

urlpatterns = [
    # ...
    path("auth/", include("social_django.urls", namespace="social")),
]
```

## Session Externalization

The default database-backed session backend does not scale horizontally. Replace it with **Redis** before deploying multiple App Service instances or Container Apps replicas.

Use **Azure Cache for Redis** as the backing store and `django-redis` as the cache/session backend.

```text
django-redis>=5.4
```

```python
# settings/production.py
CACHES = {
    "default": {
        "BACKEND": "django_redis.cache.RedisCache",
        "LOCATION": os.environ["REDIS_URL"],  # redis://:PASSWORD@host:6380/0
        "OPTIONS": {
            "CLIENT_CLASS": "django_redis.client.DefaultClient",
            "CONNECTION_POOL_KWARGS": {"ssl_cert_reqs": None},
        },
    }
}

SESSION_ENGINE = "django.contrib.sessions.backends.cache"
SESSION_CACHE_ALIAS = "default"
```

Enable TLS on the Azure Cache for Redis instance (port 6380) and store the connection string in Key Vault.

## CI/CD

Use GitHub Actions with OIDC federated credentials to authenticate to Azure — no long-lived secrets.

### Workflow structure

```yaml
name: Django CI/CD

on:
  push:
    branches: [main]
  pull_request:

permissions:
  id-token: write
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: testdb
          POSTGRES_USER: testuser
          POSTGRES_PASSWORD: testpass
        ports: ["5432:5432"]
        options: --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5
    env:
      DATABASE_URL: postgresql+psycopg://testuser:testpass@localhost:5432/testdb
      DJANGO_SETTINGS_MODULE: myproject.settings.test
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - run: pip install -r requirements.txt
      - run: python manage.py collectstatic --noinput
      - run: pytest --tb=short

  deploy:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip
      - run: pip install -r requirements.txt
      - run: python manage.py collectstatic --noinput
      - uses: azure/webapps-deploy@v3
        with:
          app-name: ${{ secrets.AZURE_WEBAPP_NAME }}
```

### .env.example

Document all required variables. Commit `.env.example`; never commit `.env`.

```bash
# Django core
DJANGO_SETTINGS_MODULE=myproject.settings.production
SECRET_KEY=change-me-use-key-vault-in-production
ALLOWED_HOSTS=myapp.azurewebsites.net,myapp.example.com
CSRF_TRUSTED_ORIGINS=https://myapp.azurewebsites.net,https://myapp.example.com

# Database
DATABASE_URL=postgresql+psycopg://user:password@host/dbname?sslmode=require

# Redis
REDIS_URL=rediss://:password@myredis.redis.cache.windows.net:6380/0

# Entra ID
ENTRA_CLIENT_ID=00000000-0000-0000-0000-000000000000
ENTRA_CLIENT_SECRET=change-me-use-key-vault-in-production
ENTRA_TENANT_ID=00000000-0000-0000-0000-000000000000

# Azure (CI/CD — set as GitHub Actions secrets, not in .env)
AZURE_CLIENT_ID=
AZURE_TENANT_ID=
AZURE_SUBSCRIPTION_ID=
AZURE_WEBAPP_NAME=
```
