# Makefile for common project commands

# docker-compose file
COMPOSE_FILE = -f docker-compose.yml

# ==============================================================================
# Docker
# ==============================================================================

# Start containers in the background
up:
	docker-compose $(COMPOSE_FILE) up -d

# Stop containers without removing them (unless-stopped remembers manual stop)
stop:
	docker-compose $(COMPOSE_FILE) stop

# Stop and remove containers, networks, and compose volumes
down:
	docker-compose $(COMPOSE_FILE) down

# Restart (use restart-build after entrypoint/php changes)
restart: down up

# Restart and rebuild the WordPress image (after editing entrypoint.sh or Dockerfile)
restart-build: down
	docker-compose $(COMPOSE_FILE) up --build -d

# Start with a forced rebuild
upb:
	docker-compose $(COMPOSE_FILE) up --build -d

# Stop and remove containers, networks, and all volumes
kill:
	docker-compose $(COMPOSE_FILE) down -v

# Shell in the WordPress (PHP) container
shell:
	docker-compose $(COMPOSE_FILE) exec wordpress bash

# Show WordPress debug config (from /var/www/html in the container)
wp-config-debug:
	@docker-compose $(COMPOSE_FILE) exec wordpress bash -c "cd /var/www/html && echo 'WP_DEBUG=' && (wp config get WP_DEBUG --allow-root 2>/dev/null || echo 'not set') && echo 'WP_DEBUG_LOG=' && (wp config get WP_DEBUG_LOG --allow-root 2>/dev/null || echo 'not set') && echo 'WP_DEBUG_DISPLAY=' && (wp config get WP_DEBUG_DISPLAY --allow-root 2>/dev/null || echo 'not set')"

# List WordPress root in the container (check wp-config.php)
wp-ls:
	docker-compose $(COMPOSE_FILE) exec wordpress ls -la /var/www/html/

# WordPress container logs (entrypoint, WP_DEBUG messages)
.PHONY: logs
logs:
	docker-compose $(COMPOSE_FILE) logs --tail=80 wordpress

# ==============================================================================
# Project setup
# ==============================================================================

# Build and start; WordPress is installed via entrypoint on first run
start:
	docker-compose $(COMPOSE_FILE) up -d --build

# Configure .env.example and copy to .env (run: make PROJECT=<slug>)
.PHONY: project-env
project-env:
	@test -n "$(PROJECT)" || (echo "Error: PROJECT is empty. Usage: make PROJECT=<slug>" >&2; exit 1)
	@case "$(PROJECT)" in \
		*[!a-zA-Z0-9_-]*|""|[-_]*) \
			echo "Error: PROJECT must start with a letter or digit and contain only [a-zA-Z0-9_-]. Got: $(PROJECT)" >&2; \
			exit 1;; \
	esac
	@sed -i 's/^PROJECT_NAME=.*/PROJECT_NAME=$(PROJECT)/' .env.example
	@sed -i 's/^SITE_HOSTNAME=.*/SITE_HOSTNAME=$(PROJECT).localhost/' .env.example
	@sed -i 's/^PMA_HOSTNAME=.*/PMA_HOSTNAME=pma.$(PROJECT).localhost/' .env.example
	@sed -i 's@^# Site:.*@# Site: https://$(PROJECT).localhost/wp-admin | phpMyAdmin: https://pma.$(PROJECT).localhost@' .env.example
	@cp .env.example .env
	@echo "Configured for project: $(PROJECT)"
	@echo "  Site:       https://$(PROJECT).localhost/wp-admin"
	@echo "  phpMyAdmin: https://pma.$(PROJECT).localhost"
	@echo "In wptraefik run: make add-site SLUG=$(PROJECT) DOMAIN=$(PROJECT).localhost"

# ==============================================================================
# Themes and plugins cleanup
# ==============================================================================

.PHONY: delete-theme delete-plugins delete-uploads delete-all
delete-theme:
	@bash scripts/delete-wp-content.sh themes --confirm

delete-plugins:
	@bash scripts/delete-wp-content.sh plugins --confirm

delete-uploads:
	@bash scripts/delete-wp-content.sh uploads --confirm

delete-all:
	@bash scripts/delete-wp-content.sh all

# ==============================================================================
# WordPress translations
# ==============================================================================

.PHONY: wp-update-translations
wp-update-translations:
	docker-compose $(COMPOSE_FILE) exec -T wordpress /usr/local/bin/wp-update-translations.sh

# ==============================================================================
# Help
# ==============================================================================

# Printed by `make` or `make help`
.PHONY: help
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  up             - Start all services in detached mode."
	@echo "  upb            - Build and start all services in detached mode."
	@echo "  stop           - Stop all services without removing containers."
	@echo "  down           - Stop and remove all services."
	@echo "  kill           - Stop and remove all services and volumes."
	@echo "  restart        - Restart all services."
	@echo "  restart-build  - Restart and rebuild WordPress image (after entrypoint/Dockerfile changes)."
	@echo "  shell          - Get a shell inside the WordPress container."
	@echo "  wp-config-debug - Show WP_DEBUG / WP_DEBUG_LOG / WP_DEBUG_DISPLAY values."
	@echo "  wp-ls          - List /var/www/html in container (check wp-config.php)."
	@echo "  logs           - Show WordPress container logs (entrypoint, [WP_DEBUG] messages)."
	@echo "  start          - Build and start all services (standard WordPress install on first run)."
	@echo "  delete-theme   - Remove themes (confirm each; keep index.php)."
	@echo "  delete-plugins - Remove plugins (confirm each; keep index.php)."
	@echo "  delete-uploads - Remove uploads (confirm each; keep .gitkeep and index.php)."
	@echo "  delete-all     - Remove all themes and plugins (keep index.php)."
	@echo "  wp-update-translations - Install/update locale packs from WP_LANGUAGE."
	@echo ""
	@echo "  make PROJECT=<slug> - Configure .env.example and copy to .env."
	@echo ""
	@echo "  help           - Show this help message."

# Default goal is help; when PROJECT is set, configure env instead
ifneq ($(strip $(PROJECT)),)
.DEFAULT_GOAL := project-env
else
.DEFAULT_GOAL := help
endif
