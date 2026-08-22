# Makefile for common project commands

# docker-compose file
COMPOSE_FILE = -f docker-compose.yml

# ==============================================================================
# Docker
# ==============================================================================

# Start containers in the background
up:
	docker-compose $(COMPOSE_FILE) up -d

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
	@echo "  down           - Stop and remove all services."
	@echo "  kill           - Stop and remove all services and volumes."
	@echo "  restart        - Restart all services."
	@echo "  restart-build  - Restart and rebuild WordPress image (after entrypoint/Dockerfile changes)."
	@echo "  shell          - Get a shell inside the WordPress container."
	@echo "  wp-config-debug - Show WP_DEBUG / WP_DEBUG_LOG / WP_DEBUG_DISPLAY values."
	@echo "  wp-ls          - List /var/www/html in container (check wp-config.php)."
	@echo "  logs           - Show WordPress container logs (entrypoint, [WP_DEBUG] messages)."
	@echo "  start          - Build and start all services (standard WordPress install on first run)."
	@echo ""
	@echo "  help           - Show this help message."

# Default goal is help
.DEFAULT_GOAL := help
