# Local WordPress (Docker)

[![WordPress](https://img.shields.io/badge/WordPress-latest-21759B.svg)](https://wordpress.org/)
[![PHP](https://img.shields.io/badge/PHP-8.2-777BB4.svg)](https://www.php.net/)
[![Docker](https://img.shields.io/badge/Docker-Compose-blue.svg)](https://docs.docker.com/compose/)
[![MySQL](https://img.shields.io/badge/MySQL-8-4479A1.svg)](https://www.mysql.com/)
[![Traefik](https://img.shields.io/badge/Traefik-HTTPS-24A1C1.svg)](https://github.com/MrBrims/wptraefik)
[![Version](https://img.shields.io/badge/Version-1.0.7-green.svg)](#changelog)

Local WordPress stack: PHP-FPM, Nginx, MySQL, phpMyAdmin. HTTPS is terminated by an external Traefik instance. The first start installs a stock WordPress (core, default Twenty* themes, default plugins). Themes are not cloned from remote repositories.

## Works with wptraefik

HTTPS and routing are handled by **[MrBrims/wptraefik](https://github.com/MrBrims/wptraefik)** — a local Traefik reverse proxy with mkcert TLS.

This stack joins the external Docker network `traefik_web` and does not publish ports 80/443 on the host. Traefik labels are already defined in `docker-compose.yml`.

## Requirements

- Docker and Docker Compose
- [mkcert](https://github.com/FiloSottile/mkcert) — run **`mkcert -install`** after install
- [wptraefik](https://github.com/MrBrims/wptraefik) running (`make up`) with TLS registered for your slug (`make add-site`)
- GNU Make (for `Makefile` targets)

## Get the project from Git

Clone the repository (WordPress core is not in Git; it is downloaded into a Docker volume on first start):

```bash
git clone https://github.com/MrBrims/wpdocker.git
cd wpdocker
```

`.env` is gitignored. After clone, configure the project slug (updates `.env.example` and copies it to `.env`):

```bash
make PROJECT=wp
```

For a different slug, pass your name instead of `wp` (e.g. `make PROJECT=myshop` sets `myshop.localhost` and `pma.myshop.localhost`).

Empty `app/themes/`, `app/plugins/`, and `app/mu-plugins/` are kept in the repo via `index.php` (`// Silence is golden.`). Empty `app/logs/` and `app/uploads/` use `.gitkeep`. Put your own themes, plugins, and must-use plugins into those folders; they are not fetched from Git remotes by this stack. Media uploads appear in `app/uploads/` on the host.

To update an existing checkout:

```bash
git pull
```

`git pull` does not replace the database or WordPress core in Docker volumes. After pulling changes to `php/Dockerfile` or `php/entrypoint.sh`, run `make restart-build`.

## Quick start

Full stack from two repositories:

```bash
# 1. Traefik (separate clone)
git clone https://github.com/MrBrims/wptraefik.git
cd wptraefik
make up
make add-site SLUG=wp DOMAIN=wp.localhost

# 2. WordPress (this repo)
git clone https://github.com/MrBrims/wpdocker.git
cd wpdocker
make PROJECT=wp
make start
```

`make start` builds the PHP image and starts the containers. If `wp-config.php` is missing, the entrypoint downloads WordPress core, creates the config, waits for the database, and runs `wp core install`.

Site: [https://wp.localhost](https://wp.localhost)  
phpMyAdmin: [https://pma.wp.localhost](https://pma.wp.localhost)

Use `.localhost` hostnames because Chrome blocks HTTPS on `.local`. Admin and database credentials live in `.env`.

## Traefik setup

Match wptraefik `make add-site` arguments to your `.env` hostnames:

| wpdocker `.env` | wptraefik |
| --- | --- |
| `PROJECT_NAME=wp` | `SLUG=wp` in `make add-site` |
| `SITE_HOSTNAME=wp.localhost` | `DOMAIN=wp.localhost` |
| `PMA_HOSTNAME=pma.wp.localhost` | covered by `*.wp.localhost` wildcard |

If you change `PROJECT_NAME` or hostnames in `.env`, update wptraefik too:

```bash
make add-site SLUG=<new-slug> DOMAIN=<new-domain>.localhost
```

See [wptraefik README](https://github.com/MrBrims/wptraefik#full-stack-quick-start-with-wpdocker) for the full proxy setup.

## Themes and plugins

Host directories are bind-mounted into the container:

| Host | Container |
| --- | --- |
| `app/themes/` | `/var/www/html/wp-content/themes` |
| `app/plugins/` | `/var/www/html/wp-content/plugins` |
| `app/mu-plugins/` | `/var/www/html/wp-content/mu-plugins` |
| `app/logs/` | `/var/www/html/wp-content/debug-logs` |
| `app/uploads/` | `/var/www/html/wp-content/uploads` |

WordPress core is stored in the `wordpress_core` Docker volume, not in the repo. Put your own themes, plugins, and must-use plugins into `app/themes/`, `app/plugins/`, and `app/mu-plugins/` yourself. Uploaded media is stored in `app/uploads/`.

## Commands

```bash
make help            # list targets
make PROJECT=<slug>  # configure .env.example and copy to .env
make start           # build and start (first run, and after Dockerfile/entrypoint changes)
make up              # start without rebuilding the image
make upb             # same as start
make stop            # stop containers without removing them
make down            # stop and remove containers
make kill            # down plus remove volumes (database and WordPress core)
make restart         # down + up
make restart-build   # down + build and start
make shell           # bash inside the wordpress container
make logs            # WordPress logs (entrypoint, WP_DEBUG)
make wp-ls           # list /var/www/html
make wp-config-debug # WP_DEBUG / WP_DEBUG_LOG / WP_DEBUG_DISPLAY values
make delete-theme    # remove themes (confirm each; keep index.php)
make delete-plugins  # remove plugins (confirm each; keep index.php)
make delete-uploads  # remove uploads (confirm each; keep .gitkeep and index.php)
make delete-all      # remove all themes and plugins (keep index.php)
```

After editing `php/entrypoint.sh` or `php/Dockerfile`, run `make start` or `make restart-build`.

## Docker autostart and restart

Docker Desktop should **not** autostart when you sign in to Windows. In Docker Desktop → Settings → General, disable **Start Docker Desktop when you sign in to your computer**. Start Docker manually when you need the stack.

All services in `docker-compose.yml` use `restart: unless-stopped`:

| Scenario | Behavior |
| --- | --- |
| Container crashes while Docker is running | Docker restarts it automatically |
| Container stopped manually (`make stop`, `make down`, or `docker stop`) | Does not start when Docker starts again |
| Stack left running, PC rebooted, Docker started manually | Containers come back (they were not manually stopped) |

Before shutting down the PC, run `make stop` or `make down` if you do not want containers to resume on the next manual Docker start. Use `make stop` to pause the stack without removing containers; use `make down` to stop and remove containers (volumes are kept).

## Configuration

Configure hostnames with `make PROJECT=<slug>` or copy `.env.example` to `.env` manually and adjust as needed:

| Variable | Purpose |
| --- | --- |
| `PROJECT_NAME` | container name prefix and site title on install |
| `SITE_HOSTNAME` / `PMA_HOSTNAME` | Traefik hosts |
| `UID` / `GID` | owner of files created by WP-CLI |
| `DB_*`, `MYSQL_VERSION` | MySQL |
| `WP_ADMIN_*` | WordPress admin (first install only) |
| `WP_DEBUG`, `WP_DEBUG_LOG`, `WP_DEBUG_DISPLAY` | debug; log file is `app/logs/debug.log` |

`.env` is not committed to git.

## Stack

- **wordpress** — PHP 8.2-FPM, WP-CLI, Xdebug (`host.docker.internal`)
- **nginx** — HTTP on port 80 inside the network; Traefik terminates TLS
- **db** — MySQL 8
- **phpmyadmin**

Clean reinstall: `make kill`, then `make start`.

## Project Structure

```
wpdocker/
├── app/
│   ├── themes/               # Bind-mounted to wp-content/themes
│   │   └── index.php         # Silence is golden (keeps empty dir in Git)
│   ├── plugins/              # Bind-mounted to wp-content/plugins
│   │   └── index.php
│   ├── mu-plugins/           # Bind-mounted to wp-content/mu-plugins
│   │   └── index.php
│   ├── logs/                 # Bind-mounted to wp-content/debug-logs
│   │   └── .gitkeep
│   └── uploads/              # Bind-mounted to wp-content/uploads
│       └── .gitkeep
├── php/
│   ├── Dockerfile            # PHP 8.2-FPM, WP-CLI, Xdebug, gosu
│   ├── entrypoint.sh         # First-run WP install, languages, WP_DEBUG
│   └── php.ini               # PHP limits and Xdebug (host.docker.internal)
├── nginx/
│   └── default.conf.template # WordPress vhost; HTTPS forwarded from Traefik
├── scripts/
│   └── delete-wp-content.sh  # Clean app/themes, app/plugins, and app/uploads
├── docker-compose.yml        # wordpress, nginx, db, phpmyadmin + Traefik
├── Makefile                  # docker compose wrappers (make help)
├── .env.example
├── .env                      # credentials and hostnames (gitignored)
├── .gitignore
└── README.md
```

WordPress core and the MySQL data directory live in named Docker volumes (`wordpress_core`, `db_data`), not in this tree.

## Changelog

### 1.0.7

- **NEW**: Bind-mount `app/uploads/` for WordPress media files on the host
- **NEW**: `make delete-uploads` — clean `app/uploads/` (confirm each; keep `.gitkeep` and `index.php`)

### 1.0.6

- **TECHNICAL**: Move themes, plugins, mu-plugins, and logs under `app/`

### 1.0.5

- **NEW**: `make delete-theme`, `delete-plugins`, `delete-all` — clean `themes/` and `plugins/` (keep `index.php`); per-item confirm for theme/plugins, bulk delete for `delete-all`
- **FIX**: `delete-theme` and `delete-plugins` accept only `y` or `n`; any other input is rejected with a re-prompt

### 1.0.4

- **FIX**: Admin plugin, theme, and core install/update without FTP credentials prompt
- **TECHNICAL**: PHP-FPM runs as `UID`/`GID` from `.env`; `FS_METHOD` direct applied in `wp-config.php` on every container start

### 1.0.3

- **NEW**: `make stop` — stop all services without removing containers
- **DOCS**: Docker autostart and container restart policy (`unless-stopped`)

### 1.0.2

- **TECHNICAL**: `mu-plugins/` placeholder switched from `.gitkeep` to `index.php` (aligned with `themes/` and `plugins/`)
- **NEW**: Bind-mount for `mu-plugins/` in `docker-compose.yml` (must-use plugins from the host)

### 1.0.1

- **NEW**: `make PROJECT=<slug>` — set `PROJECT_NAME`, `SITE_HOSTNAME`, `PMA_HOSTNAME` in `.env.example`, update the site hint comment, and copy to `.env`

### 1.0.0

- **NEW**: Docker Compose stack — PHP-FPM, Nginx, MySQL 8, phpMyAdmin
- **NEW**: HTTPS via an external Traefik network (`traefik_web`) and `.localhost` hosts
- **NEW**: First start installs stock WordPress with WP-CLI (core download, `wp-config.php`, `wp core install`)
- **NEW**: Language packs on start: `ru_RU`, `de_DE`, `fr_FR`, `es_ES`, `it_IT`
- **NEW**: Bind-mounts for `themes/`, `plugins/`, and `logs/` (debug.log on the host)
- **NEW**: Makefile targets for start, rebuild, logs, WP-CLI debug, and a clean volume wipe
- **NEW**: `WP_DEBUG` / `WP_DEBUG_LOG` / `WP_DEBUG_DISPLAY` applied from `.env` on every container start
- **TECHNICAL**: MySQL 8 instead of MariaDB; skip verification of the local self-signed DB cert
- **TECHNICAL**: Xdebug 3 against `host.docker.internal`; WP-CLI and gosu in the PHP image
- **TECHNICAL**: Entrypoint line endings normalized so the script runs on Linux containers from Windows checkouts
