# 🚀 Jalen Rails Template

Welcome! This is a Rails application template with pre-configured deployment setup using Kamal.

## Requirements

You'll need the following installed to run the template successfully:

* Ruby `4.0.2` (see `.ruby-version`)
* PostgreSQL 19+
* Bun
* Libvips or Imagemagick

## Create Your Repository

Create a [new Git](https://github.com/new) repository for your project. Then you can clone this template and push it to your new repository.

```bash
git clone git@github.com:jalen0x/jalen-rails-template.git myapp
cd myapp
git remote rename origin upstream
git remote add origin git@github.com:your-username/your-repo.git # Replace with your new Git repository url
git push -u origin main
```

## Initial Setup

First, configure your project:

```bash
bin/rails setup:project
```

You will be prompted to enter:
- **Project slug** (e.g., `musicforge`) - used for database names and Kamal service/image names
- **Application name** (e.g., `Musicforge`)
- **Canonical host** (e.g., `app.example.com`)
- **Support email**
- **Default from email**
- **Web server IP** - leave empty to keep current settings

This will automatically configure:
- `config/database.yml` - Database names and ENV-backed connection settings
- `config/template_base.rb` - app name, domain, and mail defaults
- `config/deploy.yml` - Service name, image name, servers, domain, and the
  `db` Kamal accessory (PostgreSQL 19 running on the same host, reachable by
  the app container through the `kamal` Docker network as `<prefix>-db`)
- seed override files for the default layout and home page if they do not exist

Copy the local env example before setup:

```bash
cp .env.example .env.development
cp .env.example .env.test
```

Then run `bin/setup` to install Ruby and JavaScript dependencies and setup your database:

```bash
bin/setup
```

`bin/setup` checks the pinned Ruby version before installing gems so mismatched patch versions fail early with a clear message.

## Running the Application

To run your application, use the `bin/dev` command:

```bash
bin/dev
```

This starts up the processes defined in `Procfile.dev`:
- Rails server
- CSS bundling (Tailwind)
- JS bundling

You can add background workers or other services to `Procfile.dev` as needed.

## Deployment with Kamal

This template is pre-configured for deployment with [Kamal](https://kamal-deploy.org/).

### Secrets pattern

The template reads runtime secrets from ENV only. `.kamal/secrets` fetches
deploy and app secrets directly from 1Password and exposes them to Kamal.

Required production secret fields:

- `KAMAL_REGISTRY_PASSWORD`
- `POSTGRES_PASSWORD`
- `SECRET_KEY_BASE`
- `SSL_CERTIFICATE`
- `SSL_PRIVATE_KEY`
- `CLOUDFLARE_ACCOUNT_ID`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`
- `R2_BUCKET_NAME`
- `GITHUB_CLIENT_ID`
- `GITHUB_CLIENT_SECRET`

### First-time setup

1. Point the `SECRETS=$(kamal secrets fetch …)` line in `.kamal/secrets` at
   the 1Password vault/item holding the required fields above.
2. Deploy:

   ```bash
   bin/kamal setup    # First time only — installs Docker + boots the `db` accessory
   bin/kamal deploy   # Deploy the application
   ```

### Subsequent Deployments

```bash
bin/kamal deploy
```

### Useful Kamal Commands

```bash
bin/kamal app logs -f          # Tail application logs
bin/kamal app exec -i "bash"   # SSH into the app container
bin/kamal console              # Rails console (alias)
bin/kamal dbc                  # Rails dbconsole (alias)
```

## Project Structure

```
.
├── app/                    # Application code
├── config/
│   ├── database.yml        # Database configuration (generated from template)
│   ├── deploy.yml          # Kamal deployment config (generated from template)
│   └── template_base.rb    # App-level name/domain/mail defaults
├── lib/
│   ├── template_base/      # Internal template base (engine-backed defaults)
│   ├── tasks/
│   │   └── setup.rake      # Project setup task
│   └── templates/
│       ├── database.yml.tt # Database config template
│       ├── deploy.yml.tt   # Deploy config template
│       └── template_base.rb.tt
└── ...
```

## Customizing Base Files

Default template implementations can live under `lib/template_base/app/...`.
To customize one in your app, copy it into `app/...` first:

```bash
bin/rails generate template_base:override app/views/layouts/application.html.erb
```

## Migration Guides

- [Migrate Rails credentials to ENV-only runtime config](docs/migrations/credentials-to-env.md)

## Merging Updates

To merge changes from the template, you will merge from the `upstream` remote:

```bash
git fetch upstream
git merge upstream/main
```

## Contributing

If you have an improvement you'd like to share, create a fork of the repository and send us a pull request.

## License

This template is available as open source under the terms of the MIT License.
