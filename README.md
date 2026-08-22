# Local WordPress (Docker)

Local WordPress stack: PHP-FPM, Nginx, MySQL, phpMyAdmin. HTTPS is terminated by an external Traefik instance. The first start installs a stock WordPress (core, default Twenty* themes, default plugins). Themes are not cloned from remote repositories.

## Requirements

- Docker and Docker Compose
- External Traefik network `traefik_web` (Traefik already running)
- GNU Make (for `Makefile` targets)

Create the network if it does not exist yet:

```bash
docker network create traefik_web
```

## Quick start

```bash
cp .env.example .env
make start
```

`make start` builds the PHP image and starts the containers. If `wp-config.php` is missing, the entrypoint downloads WordPress core, creates the config, waits for the database, and runs `wp core install`.

Site: [https://wp.localhost](https://wp.localhost)  
phpMyAdmin: [https://pma.wp.localhost](https://pma.wp.localhost)

Use `.localhost` hostnames because Chrome blocks HTTPS on `.local`. Admin and database credentials live in `.env`.

## Themes and plugins

Host directories are bind-mounted into the container:

| Host | Container |
| --- | --- |
| `themes/` | `/var/www/html/wp-content/themes` |
| `plugins/` | `/var/www/html/wp-content/plugins` |
| `logs/` | `/var/www/html/wp-content/debug-logs` |

WordPress core is stored in the `wordpress_core` Docker volume, not in the repo. Put your own themes and plugins into `themes/` and `plugins/` yourself.

## Commands

```bash
make help            # list targets
make start           # build and start (first run, and after Dockerfile/entrypoint changes)
make up              # start without rebuilding the image
make upb             # same as start
make down            # stop and remove containers
make kill            # down plus remove volumes (database and WordPress core)
make restart         # down + up
make restart-build   # down + build and start
make shell           # bash inside the wordpress container
make logs            # WordPress logs (entrypoint, WP_DEBUG)
make wp-ls           # list /var/www/html
make wp-config-debug # WP_DEBUG / WP_DEBUG_LOG / WP_DEBUG_DISPLAY values
```

After editing `php/entrypoint.sh` or `php/Dockerfile`, run `make start` or `make restart-build`.

## Configuration

Copy `.env.example` to `.env` and adjust as needed:

| Variable | Purpose |
| --- | --- |
| `PROJECT_NAME` | container name prefix and site title on install |
| `SITE_HOSTNAME` / `PMA_HOSTNAME` | Traefik hosts |
| `UID` / `GID` | owner of files created by WP-CLI |
| `DB_*`, `MYSQL_VERSION` | MySQL |
| `WP_ADMIN_*` | WordPress admin (first install only) |
| `WP_DEBUG`, `WP_DEBUG_LOG`, `WP_DEBUG_DISPLAY` | debug; log file is `logs/debug.log` |

`.env` is not committed to git.

## Stack

- **wordpress** — PHP 8.2-FPM, WP-CLI, Xdebug (`host.docker.internal`)
- **nginx** — HTTP on port 80 inside the network; Traefik terminates TLS
- **db** — MySQL 8
- **phpmyadmin**

Clean reinstall: `make kill`, then `make start`.
