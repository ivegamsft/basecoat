---
description: "Conventions for Ruby on Rails projects targeting Azure: deployment targets, containerization, database migration, auth modernization, and CI/CD patterns."
applyTo: "**/Gemfile,**/config.ru,**/.ruby-version,**/Rakefile,**/config/routes.rb"
---

# Ruby on Rails on Azure Standards

Use this instruction when working on Ruby on Rails applications deployed to Azure, including new services, migrations, containerization, and CI/CD pipelines.

## Azure Deployment Targets

Choose the runtime that best matches the packaging and operational model.

- **Azure App Service (Linux)** — simplest path. Use the Ruby 3.x runtime on Linux App Service. Puma is the default application server and requires no additional startup command in most cases.
- **Azure Container Apps** — preferred for containerized Puma + Rails when you need autoscaling, sidecar support, or a custom base image.

> **Azure Static Web Apps is not a fit for Rails.** It supports only static assets and serverless API functions, not server-rendered Ruby applications.

### Static assets — App Service startup command

Configure the startup command for Puma explicitly when customising worker count:

```bash
bundle exec puma -C config/puma.rb
```

### Static asset delivery

Precompile assets and serve them from Azure CDN or Azure Blob Storage to offload the application server.

```bash
RAILS_ENV=production bundle exec rails assets:precompile
```

Upload the `public/assets` directory to an Azure Blob Storage container and front it with an Azure CDN endpoint. Set `config.asset_host` in `config/environments/production.rb`:

```ruby
config.asset_host = "https://<cdn-endpoint>.azureedge.net"
```

## Containerization

Use a multi-stage Dockerfile to keep the runtime image slim.

```dockerfile
# syntax=docker/dockerfile:1

# ---- Build stage ----
FROM ruby:3.3-slim AS build
WORKDIR /app
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test --jobs 4 --retry 3
COPY . .
RUN RAILS_ENV=production SECRET_KEY_BASE=dummy \
    bundle exec rails assets:precompile

# ---- Runtime stage ----
FROM ruby:3.3-slim AS runtime
WORKDIR /app
RUN apt-get update -qq && apt-get install -y libpq5 && rm -rf /var/lib/apt/lists/*
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /app /app
ENV RAILS_ENV=production \
    RAILS_SERVE_STATIC_FILES=true \
    RAILS_LOG_TO_STDOUT=true
EXPOSE 3000
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

### Secrets — RAILS_MASTER_KEY via Azure Key Vault

Do not store `RAILS_MASTER_KEY` in source control or plain application settings. Reference it from Key Vault using an App Service Key Vault reference:

```text
@Microsoft.KeyVault(SecretUri=https://<vault>.vault.azure.net/secrets/rails-master-key/)
```

For Container Apps, inject it as a Key Vault secret reference in the container environment:

```yaml
secrets:
  - name: rails-master-key
    keyVaultUrl: https://<vault>.vault.azure.net/secrets/rails-master-key
    identity: <managed-identity-resource-id>
env:
  - name: RAILS_MASTER_KEY
    secretRef: rails-master-key
```

### Puma worker and thread tuning

Tune Puma in `config/puma.rb` to stay within the container memory limit. A safe starting point for a 512 MB container is two workers with two threads each:

```ruby
workers ENV.fetch("WEB_CONCURRENCY", 2).to_i
threads_count = ENV.fetch("RAILS_MAX_THREADS", 2).to_i
threads threads_count, threads_count

preload_app!

port ENV.fetch("PORT", 3000)
environment ENV.fetch("RAILS_ENV", "production")
```

Set `WEB_CONCURRENCY` and `RAILS_MAX_THREADS` as environment variables in App Service or Container Apps to override without rebuilding the image.

### RAILS_SERVE_STATIC_FILES

Set `RAILS_SERVE_STATIC_FILES=true` for containers that run without an Nginx reverse proxy in front of Puma. When Nginx or Azure Front Door handles static file serving, leave this unset and rely on `config.asset_host` pointing to CDN.

## Database Migration

### Active Record migrations in CI/CD

Run `rails db:migrate` as a pre-deployment step so migrations are applied before the new application version receives traffic. In GitHub Actions:

```yaml
- name: Run database migrations
  run: bundle exec rails db:migrate
  env:
    DATABASE_URL: ${{ secrets.DATABASE_URL }}
    RAILS_ENV: production
```

### MySQL/PostgreSQL to Azure Database for PostgreSQL Flexible Server

Migrate self-hosted MySQL or PostgreSQL to Azure Database for PostgreSQL Flexible Server. Update `config/database.yml`:

```yaml
production:
  adapter: postgresql
  encoding: unicode
  url: <%= ENV["DATABASE_URL"] %>
  pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
  connect_timeout: 5
  ssl_mode: require
```

Set `DATABASE_URL` as a Key Vault–backed application setting:

```text
postgresql://<user>:<password>@<server>.postgres.database.azure.com/<db>?sslmode=require
```

### Connection pooling

For App Service with multiple instances, use PgBouncer or increase the Active Record `pool:` setting. PgBouncer is the preferred approach when the number of Rails processes × threads exceeds the PostgreSQL `max_connections` limit.

Alternatively, configure the Active Record pool size via environment variable so it can be tuned per environment without code changes:

```yaml
pool: <%= ENV.fetch("RAILS_MAX_THREADS", 5) %>
```

## Auth Modernization

### Devise + Entra ID OIDC via OmniAuth

Replace or supplement database-backed Devise authentication with Entra ID OIDC using the `omniauth-azure-activedirectory-v2` gem.

Add to `Gemfile`:

```ruby
gem "devise"
gem "omniauth-azure-activedirectory-v2"
gem "omniauth-rails_csrf_protection"
```

Configure the OmniAuth provider in `config/initializers/devise.rb`:

```ruby
config.omniauth :azure_activedirectory_v2,
  client_id:     ENV["AZURE_CLIENT_ID"],
  client_secret: ENV["AZURE_CLIENT_SECRET"],
  tenant_id:     ENV["AZURE_TENANT_ID"]
```

### Role claims mapping

Map Entra ID group or app role claims to CanCanCan abilities in the OmniAuth callback:

```ruby
# app/controllers/users/omniauth_callbacks_controller.rb
def azure_activedirectory_v2
  auth = request.env["omniauth.auth"]
  roles = auth.extra.raw_info["roles"] || []
  user = User.from_omniauth(auth, roles)
  sign_in_and_redirect user
end
```

In the `User` model, persist roles from the token and expose them to CanCanCan:

```ruby
def self.from_omniauth(auth, roles)
  find_or_create_by(uid: auth.uid, provider: auth.provider) do |u|
    u.email = auth.info.email
    u.name  = auth.info.name
    u.roles = roles
  end
end
```

### Session externalization — Redis via Azure Cache for Redis

Replace the cookie session store with Redis to support horizontal scaling and reduce cookie size.

Add to `Gemfile`:

```ruby
gem "redis-session-store"
```

Configure in `config/initializers/session_store.rb`:

```ruby
Rails.application.config.session_store :redis_session_store,
  key:    "_myapp_session",
  secure: Rails.env.production?,
  expire_after: 2.hours,
  redis: {
    url: ENV["REDIS_URL"],
    key_prefix: "myapp:session:"
  }
```

Set `REDIS_URL` to the Azure Cache for Redis TLS endpoint:

```text
rediss://:<access-key>@<cache-name>.redis.cache.windows.net:6380
```

## CI/CD

### GitHub Actions pipeline

```yaml
name: Rails CI/CD

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
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
    steps:
      - uses: actions/checkout@v4

      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Set up database
        run: bundle exec rails db:create db:schema:load
        env:
          RAILS_ENV: test
          DATABASE_URL: postgresql://postgres:postgres@localhost/myapp_test

      - name: Run tests
        run: bundle exec rspec
        env:
          RAILS_ENV: test
          DATABASE_URL: postgresql://postgres:postgres@localhost/myapp_test

  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4

      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Precompile assets
        run: bundle exec rails assets:precompile
        env:
          RAILS_ENV: production
          SECRET_KEY_BASE: ${{ secrets.SECRET_KEY_BASE }}

      - name: Azure login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Run database migrations
        run: bundle exec rails db:migrate
        env:
          RAILS_ENV: production
          DATABASE_URL: ${{ secrets.DATABASE_URL }}

      - name: Deploy to Azure App Service
        uses: azure/webapps-deploy@v3
        with:
          app-name: ${{ secrets.AZURE_APP_NAME }}
          package: .
```

### OIDC federated credentials

Configure an Entra ID app registration with a federated credential for the GitHub Actions `repo:IBuySpy-Shared/myapp:ref:refs/heads/main` subject. Do not use client secrets in the deploy job; rely solely on `azure/login` with `client-id`, `tenant-id`, and `subscription-id`.

## Environment Configuration

### RAILS_ENV=production requirements

The following environment variables are required in production. Do not rely on Rails defaults.

| Variable | Source |
|---|---|
| `RAILS_ENV` | App Service / Container Apps setting |
| `SECRET_KEY_BASE` | Key Vault reference |
| `RAILS_MASTER_KEY` | Key Vault reference |
| `DATABASE_URL` | Key Vault reference |
| `REDIS_URL` | Key Vault reference |
| `AZURE_CLIENT_ID` | App Service managed identity / setting |
| `AZURE_TENANT_ID` | App Service setting |
| `RAILS_SERVE_STATIC_FILES` | `true` for containers without Nginx |
| `RAILS_LOG_TO_STDOUT` | `true` for container log aggregation |

### .env.example

Maintain a `.env.example` listing all required variables with placeholder values. Never commit `.env` or any file containing real secrets.

```bash
# .env.example

RAILS_ENV=development
SECRET_KEY_BASE=replace_with_rails_secret
RAILS_MASTER_KEY=replace_with_master_key

# Database
DATABASE_URL=postgresql://postgres:postgres@localhost/myapp_development

# Redis (Azure Cache for Redis in production)
REDIS_URL=redis://localhost:6379/0

# Entra ID / OmniAuth
AZURE_CLIENT_ID=00000000-0000-0000-0000-000000000000
AZURE_CLIENT_SECRET=replace_with_client_secret
AZURE_TENANT_ID=00000000-0000-0000-0000-000000000000

# CDN / asset host (leave blank in development)
ASSET_HOST=
```
