# Migrate Rails Credentials to ENV-Only Runtime Config

Use this guide when migrating an existing Rails app from `Rails.application.credentials` to ENV / Kamal secrets. The goal is one runtime configuration mechanism, no credentials fallback, and no committed encrypted credentials files.

## Target State

- App code reads secrets with `ENV.fetch("NAME")` or explicit `ENV[...]` comparisons.
- Production secrets live in the deployment secret manager, usually 1Password via `.kamal/secrets`.
- Local runtime secrets live in ignored dotenv files such as `.env.development` or `.env.test`. One-time migration exports live under `tmp/` and are not loaded automatically.
- No app code reads `Rails.application.credentials`.
- `config/credentials.yml.enc`, `config/credentials/*.yml.enc`, `config/master.key`, and `config/credentials/*.key` are not committed.

## 1. Audit Existing Credentials Without Printing Values

List the keys first. Do not paste secret values into chat, issue trackers, or PR descriptions.

```bash
ruby - <<'RUBY'
require "yaml"

data = YAML.safe_load(`bin/rails credentials:show`, aliases: true) || {}

def flatten_keys(hash, prefix = nil)
  hash.flat_map do |key, value|
    full = [prefix, key].compact.join(".")
    value.is_a?(Hash) ? flatten_keys(value, full) : full
  end
end

puts flatten_keys(data).sort
RUBY
```

Decide which keys are still used. Do not migrate dead configuration just because it exists.

Common mappings:

| Old key | New ENV |
|---|---|
| `secret_key_base` | `SECRET_KEY_BASE` |
| `database.password` | `POSTGRES_PASSWORD` |
| `cloudflare.account_id` | `CLOUDFLARE_ACCOUNT_ID` |
| `cloudflare.r2.access_key_id` | `R2_ACCESS_KEY_ID` |
| `cloudflare.r2.secret_access_key` | `R2_SECRET_ACCESS_KEY` |
| `cloudflare.r2.bucket_name` | `R2_BUCKET_NAME` |
| `github.client_id` | `GITHUB_CLIENT_ID` |
| `github.client_secret` | `GITHUB_CLIENT_SECRET` |
| `postmark.api_token` | `POSTMARK_API_TOKEN` |
| `stripe.public_key` | `STRIPE_PUBLIC_KEY` |
| `stripe.private_key` | `STRIPE_SECRET_KEY` |
| `stripe.signing_secret` | `STRIPE_SIGNING_SECRET` |

`active_record_encryption.*` keys are only needed if the app uses Rails native field encryption (`encrypts :column`). If the app does not use `encrypts`, do not migrate those keys.

## 2. Extract Values to an Ignored Temporary File

Use a temporary file only as a bridge into 1Password / Kamal secrets. Keep it ignored and permission-restricted. This file is not a dotenv runtime file and should not be auto-loaded by Rails.

```bash
cat > /tmp/extract_credentials_to_env.rb <<'RUBY'
require "yaml"

data = YAML.safe_load(`bin/rails credentials:show`, aliases: true) || {}

env = {
  "SECRET_KEY_BASE" => data.dig("secret_key_base"),
  "POSTGRES_PASSWORD" => data.dig("database", "password"),
  "CLOUDFLARE_ACCOUNT_ID" => data.dig("cloudflare", "account_id"),
  "R2_ACCESS_KEY_ID" => data.dig("cloudflare", "r2", "access_key_id"),
  "R2_SECRET_ACCESS_KEY" => data.dig("cloudflare", "r2", "secret_access_key"),
  "R2_BUCKET_NAME" => data.dig("cloudflare", "r2", "bucket_name"),
  "GITHUB_CLIENT_ID" => data.dig("github", "client_id"),
  "GITHUB_CLIENT_SECRET" => data.dig("github", "client_secret")
}.compact

File.open("tmp/rails-credentials.env", File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
  file.puts "# Temporary migration file. Ignored by git. Copy values into your secret manager."
  file.puts
  env.each do |key, value|
    file.puts "#{key}=#{value.to_s.inspect}"
  end
end

puts "wrote tmp/rails-credentials.env with #{env.size} entries"
RUBY

ruby /tmp/extract_credentials_to_env.rb
rm /tmp/extract_credentials_to_env.rb
git check-ignore -v tmp/rails-credentials.env
```

If `git check-ignore` does not show a matching rule, add one before continuing. Do not use `.env.credentials.local` as a runtime file; dotenv will not load that name by convention.

## 3. Update Code to Read ENV Only

Search for all credentials reads:

```bash
rg "Rails\.application\.credentials|credentials\.dig|credentials:" config app lib .kamal README.md
```

Replace each read with an ENV read. Use `ENV.fetch` for required production values.

### Database

For Kamal with a Postgres accessory:

```yaml
<% production_env = ENV.fetch("RAILS_ENV", ENV.fetch("RACK_ENV", "development")) == "production" %>
<% require_discrete_db_env = production_env && ENV["DATABASE_URL"].to_s.empty? %>

production:
  primary: &primary_production
    <<: *default
    database: my_app_production
    username: my_app
    password: <%= require_discrete_db_env ? ENV.fetch("POSTGRES_PASSWORD") : ENV["POSTGRES_PASSWORD"] %>
    host: <%= require_discrete_db_env ? ENV.fetch("DB_HOST") : ENV["DB_HOST"] %>
```

This allows either `DATABASE_URL` or discrete `POSTGRES_PASSWORD` / `DB_HOST`, while still failing loudly in production when neither is present.

### Active Storage / R2

```yaml
<% production_env = ENV.fetch("RAILS_ENV", ENV.fetch("RACK_ENV", "development")) == "production" %>
<% env = ->(key) { production_env ? ENV.fetch(key) : ENV.fetch(key, "unused") } %>

cloudflare:
  service: S3
  access_key_id: <%= env.call("R2_ACCESS_KEY_ID") %>
  secret_access_key: <%= env.call("R2_SECRET_ACCESS_KEY") %>
  endpoint: https://<%= env.call("CLOUDFLARE_ACCOUNT_ID") %>.r2.cloudflarestorage.com
  region: auto
  bucket: <%= env.call("R2_BUCKET_NAME") %>
  force_path_style: true
```

The non-production fallback avoids local boot failures when development/test use disk storage.

### Devise GitHub OAuth

```ruby
github_client_id = ENV.fetch("GITHUB_CLIENT_ID") do
  raise KeyError, "key not found: GITHUB_CLIENT_ID" if Rails.env.production?

  "github-client-id"
end

github_client_secret = ENV.fetch("GITHUB_CLIENT_SECRET") do
  raise KeyError, "key not found: GITHUB_CLIENT_SECRET" if Rails.env.production?

  "github-client-secret"
end

config.omniauth :github, github_client_id, github_client_secret, scope: "user:email"
```

Use dummy development/test values only when the provider is not exercised locally.

### Active Record Encryption

Only add this if the app actually uses `encrypts`:

```ruby
# config/application.rb or an initializer
config.active_record.encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY")
config.active_record.encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY")
config.active_record.encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT")
```

If the app does not use encrypted attributes, delete the old keys instead of carrying them forward.

## 4. Update Kamal Secrets

`config/deploy.yml` should list the runtime secrets the container needs:

```yaml
env:
  secret:
    - SECRET_KEY_BASE
    - POSTGRES_PASSWORD
    - CLOUDFLARE_ACCOUNT_ID
    - R2_ACCESS_KEY_ID
    - R2_SECRET_ACCESS_KEY
    - R2_BUCKET_NAME
    - GITHUB_CLIENT_ID
    - GITHUB_CLIENT_SECRET
  clear:
    DB_HOST: my_app-db
```

`.kamal/secrets` should fetch those values directly from the secret manager, not from Rails credentials:

```bash
SECRETS=$(kamal secrets fetch --adapter 1password --account my --from vault-uuid/item-uuid \
  KAMAL_REGISTRY_PASSWORD \
  POSTGRES_PASSWORD \
  SECRET_KEY_BASE \
  CLOUDFLARE_ACCOUNT_ID \
  R2_ACCESS_KEY_ID \
  R2_SECRET_ACCESS_KEY \
  R2_BUCKET_NAME \
  GITHUB_CLIENT_ID \
  GITHUB_CLIENT_SECRET)

KAMAL_REGISTRY_PASSWORD=$(kamal secrets extract KAMAL_REGISTRY_PASSWORD ${SECRETS})
POSTGRES_PASSWORD=$(kamal secrets extract POSTGRES_PASSWORD ${SECRETS})
SECRET_KEY_BASE=$(kamal secrets extract SECRET_KEY_BASE ${SECRETS})
CLOUDFLARE_ACCOUNT_ID=$(kamal secrets extract CLOUDFLARE_ACCOUNT_ID ${SECRETS})
R2_ACCESS_KEY_ID=$(kamal secrets extract R2_ACCESS_KEY_ID ${SECRETS})
R2_SECRET_ACCESS_KEY=$(kamal secrets extract R2_SECRET_ACCESS_KEY ${SECRETS})
R2_BUCKET_NAME=$(kamal secrets extract R2_BUCKET_NAME ${SECRETS})
GITHUB_CLIENT_ID=$(kamal secrets extract GITHUB_CLIENT_ID ${SECRETS})
GITHUB_CLIENT_SECRET=$(kamal secrets extract GITHUB_CLIENT_SECRET ${SECRETS})
```

If SSL certs are managed by Kamal proxy settings, add `SSL_CERTIFICATE` and `SSL_PRIVATE_KEY` to the same pattern.

## 5. Remove Credentials Artifacts

After the app reads ENV and secrets are present in the secret manager:

```bash
git rm config/credentials.yml.enc 2>/dev/null || true
git rm -r config/credentials 2>/dev/null || true
git rm lib/templates/rails/credentials/credentials.yml.tt 2>/dev/null || true
rm -f config/master.key
```

Update `.gitignore` so generated credentials artifacts do not come back:

```gitignore
/config/master.key
/config/*.key
/config/credentials.yml.enc
/config/credentials/*.yml.enc
/.env*
!/.env.example
```

## 6. Verify

Run the smallest checks that prove the migration:

```bash
rg "Rails\.application\.credentials|credentials\.dig|credentials:edit|credentials:show|RAILS_MASTER_KEY" . \
  -g '!tmp' -g '!log'

git diff --check
bin/rails runner 'puts "boot ok"'

RAILS_ENV=production \
SECRET_KEY_BASE=dummy-secret-key-base-with-enough-length \
POSTGRES_PASSWORD=postgres \
DB_HOST=localhost \
CLOUDFLARE_ACCOUNT_ID=dummy \
R2_ACCESS_KEY_ID=dummy \
R2_SECRET_ACCESS_KEY=dummy \
R2_BUCKET_NAME=dummy \
GITHUB_CLIENT_ID=dummy \
GITHUB_CLIENT_SECRET=dummy \
bin/rails runner 'puts "production boot ok"'

bin/rails test
```

If the app precompiles assets in a production Docker build, provide dummy build-time ENV values for initializers that run during precompile. Real values still belong only in runtime secrets.

## 7. Commit Checklist

Before committing:

- `git status --short` shows credentials files deleted, not modified with new secret content.
- `tmp/rails-credentials.env` is ignored and not staged.
- No literal secret value appears in the staged diff.
- Production ENV values have been copied to the secret manager.
- `SECRET_KEY_BASE` exists in production secrets. If it was exposed, rotate it and expect old sessions/signed tokens to become invalid.
