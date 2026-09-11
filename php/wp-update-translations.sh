#!/bin/bash
set -euo pipefail

WP_PATH=/var/www/html
ACTIVATE_FIRST=false

if [ "${1:-}" = "--activate-first" ]; then
	ACTIVATE_FIRST=true
fi

if [ ! -f "${WP_PATH}/wp-config.php" ]; then
	echo "WordPress is not configured. Skipping translations."
	exit 0
fi

if [ -z "${WP_LANGUAGE:-}" ]; then
	echo "WP_LANGUAGE is empty. Skipping language packs."
	exit 0
fi

wp_as_user() {
	gosu "${UID}:${GID}" wp "$@" --path="${WP_PATH}"
}

trim_locale() {
	local loc="$1"
	loc="${loc//$'\r'/}"
	loc="${loc#"${loc%%[![:space:]]*}"}"
	loc="${loc%"${loc##*[![:space:]]}"}"
	printf '%s' "$loc"
}

FIRST_LOCALE=""
IFS=',' read -ra LANGS <<< "${WP_LANGUAGE}"

for loc in "${LANGS[@]}"; do
	loc="$(trim_locale "$loc")"
	[ -z "$loc" ] && continue

	if [ -z "$FIRST_LOCALE" ]; then
		FIRST_LOCALE="$loc"
	fi

	if [ "$loc" = "en_US" ]; then
		echo "Skipping en_US (built-in)."
		continue
	fi

	echo "Installing language pack: ${loc}"
	wp_as_user language core install "$loc" || true
	wp_as_user language plugin install --all "$loc" || true
	wp_as_user language theme install --all "$loc" || true
done

if $ACTIVATE_FIRST && [ -n "$FIRST_LOCALE" ] && [ "$FIRST_LOCALE" != "en_US" ]; then
	echo "Activating site language: ${FIRST_LOCALE}"
	wp_as_user language core install "$FIRST_LOCALE" --activate || true
fi

echo "Updating installed translations..."
wp_as_user language core update || true
wp_as_user language plugin update --all || true
wp_as_user language theme update --all || true

echo "Language packs done."
