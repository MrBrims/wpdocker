#!/bin/bash
set -e

# This script must be run as root
if [ "$(id -u)" != '0' ]; then
    echo "This script must be run as root. Exiting."
    exit 1
fi

# Create the user and group if they don't exist.
if ! getent group "${GID}" > /dev/null; then
    addgroup --gid "${GID}" "user"
fi
if ! id "${UID}" > /dev/null 2>&1; then
    adduser --disabled-password --gecos "" --uid "${UID}" --gid "${GID}" "user"
fi

# Chown the volume so the target user can write to it
chown "${UID}":"${GID}" /var/www/html

# Grant write access for wp-content and create a writable backup folder
if [ -d "/var/www/html/wp-content" ]; then
    chmod 777 /var/www/html/wp-content
    mkdir -p /var/www/html/wp-content/ai1wm-backups
    chmod -R 777 /var/www/html/wp-content/ai1wm-backups
fi
for dir in plugins themes mu-plugins uploads; do
    if [ -d "/var/www/html/wp-content/${dir}" ]; then
        chmod 777 "/var/www/html/wp-content/${dir}"
    fi
done
# Ensure debug-logs mount is writable by php-fpm so WP_DEBUG_LOG can write
if [ -d "/var/www/html/wp-content/debug-logs" ]; then
    chmod 777 /var/www/html/wp-content/debug-logs
fi

# If WordPress is not installed, run the installation as the target user
if [ ! -f "/var/www/html/wp-config.php" ]; then
    echo "WordPress not configured. Starting installation as user ${UID}:${GID}..."
    
    # Run WP-CLI via gosu so files get the correct ownership.
    
    if [ ! -f "/var/www/html/wp-includes/version.php" ]; then
        echo "Downloading WordPress core..."
        gosu "${UID}":"${GID}" wp core download --path=/var/www/html
    else
        echo "WordPress core files already present, skipping download."
    fi
    
    echo "Creating wp-config.php..."
    gosu "${UID}":"${GID}" wp config create --path=/var/www/html --dbname="${WORDPRESS_DB_NAME}" \
                     --dbuser="${WORDPRESS_DB_USER}" \
                     --dbpass="${WORDPRESS_DB_PASSWORD}" \
                     --dbhost="${WORDPRESS_DB_HOST}" \
                     --extra-php <<'PHP'
// Local Docker MySQL presents a self-signed cert; skip verification.
if ( ! defined( 'MYSQL_CLIENT_FLAGS' ) ) {
	define( 'MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL_DONT_VERIFY_SERVER_CERT );
}
define( 'FS_METHOD', 'direct' );
PHP

    echo "Waiting for database..."
    # Avoid `wp db check` / mariadb-check: they fail on MySQL 8 self-signed TLS.
    until php -r '
$mysqli = mysqli_init();
$mysqli->options(MYSQLI_OPT_SSL_VERIFY_SERVER_CERT, false);
@$mysqli->real_connect(
    getenv("WORDPRESS_DB_HOST"),
    getenv("WORDPRESS_DB_USER"),
    getenv("WORDPRESS_DB_PASSWORD"),
    getenv("WORDPRESS_DB_NAME"),
    3306,
    null,
    MYSQLI_CLIENT_SSL_DONT_VERIFY_SERVER_CERT
);
exit(($mysqli && !$mysqli->connect_errno) ? 0 : 1);
'; do
        echo "Database is not ready yet. Retrying in 1 second..."
        sleep 1
    done
    echo "Database is ready."
    
    echo "Installing WordPress..."
    gosu "${UID}":"${GID}" wp core install --path=/var/www/html --url="https://${SITE_HOSTNAME}" \
                    --title="${PROJECT_NAME}" \
                    --admin_user="${WP_ADMIN_USER}" \
                    --admin_password="${WP_ADMIN_PASSWORD}" \
                    --admin_email="${WP_ADMIN_EMAIL}" \
                    --skip-email

    echo "Installing additional language packs..."
    # Install popular language packs so they appear in the admin dropdown
    gosu "${UID}":"${GID}" wp language core install ru_RU --path=/var/www/html
    gosu "${UID}":"${GID}" wp language core install de_DE --path=/var/www/html
    gosu "${UID}":"${GID}" wp language core install fr_FR --path=/var/www/html
    gosu "${UID}":"${GID}" wp language core install es_ES --path=/var/www/html
    gosu "${UID}":"${GID}" wp language core install it_IT --path=/var/www/html

    echo "WordPress installation complete."

else
    echo "WordPress is already configured."
    echo "Installing additional language packs..."
    # Install popular language packs so they appear in the admin dropdown
    gosu "${UID}":"${GID}" wp language core install ru_RU --path=/var/www/html
    gosu "${UID}":"${GID}" wp language core install de_DE --path=/var/www/html
    gosu "${UID}":"${GID}" wp language core install fr_FR --path=/var/www/html
    gosu "${UID}":"${GID}" wp language core install es_ES --path=/var/www/html
    gosu "${UID}":"${GID}" wp language core install it_IT --path=/var/www/html
fi

# Apply WordPress debug settings from environment (every container start)
# Insert constants by line number so we don't depend on sed pattern matching
if [ -f "/var/www/html/wp-config.php" ]; then
    WPCONFIG="/var/www/html/wp-config.php"
    echo "[WP_DEBUG] Env: WP_DEBUG=${WP_DEBUG} WP_DEBUG_LOG=${WP_DEBUG_LOG} WP_DEBUG_DISPLAY=${WP_DEBUG_DISPLAY}"
    # Line number of require_once wp-settings (insertion anchor)
    INSERT_LINE=$(grep -n "require_once" "${WPCONFIG}" | grep "wp-settings" | head -1 | cut -d: -f1)
    if [ -z "${INSERT_LINE}" ]; then
        echo "[WP_DEBUG] WARN: could not find require_once wp-settings in wp-config.php, skipping debug constants"
    else
        echo "[WP_DEBUG] Inserting constants before line ${INSERT_LINE}"
        # Remove existing debug and filesystem constants
        sed -i "/define *([[:space:]]*'WP_DEBUG' *,/d" "${WPCONFIG}"
        sed -i "/define *([[:space:]]*'WP_DEBUG_LOG' *,/d" "${WPCONFIG}"
        sed -i "/define *([[:space:]]*'WP_DEBUG_DISPLAY' *,/d" "${WPCONFIG}"
        sed -i "/define *([[:space:]]*'FS_METHOD' *,/d" "${WPCONFIG}"
        # Line number after removals
        INSERT_LINE=$(grep -n "require_once" "${WPCONFIG}" | grep "wp-settings" | head -1 | cut -d: -f1)
        DEBUG_VAL="false"; [ "${WP_DEBUG}" = "true" ] && DEBUG_VAL="true"
        DISPLAY_VAL="false"; [ "${WP_DEBUG_DISPLAY}" = "true" ] && DISPLAY_VAL="true"
        if [ "${WP_DEBUG_LOG}" = "true" ]; then
            WP_DEBUG_LOG_PATH="/var/www/html/wp-content/debug-logs/debug.log"
            LOG_LINE="define( 'WP_DEBUG_LOG', '${WP_DEBUG_LOG_PATH}' );"
            touch "${WP_DEBUG_LOG_PATH}"
            chown "${UID}:${GID}" "${WP_DEBUG_LOG_PATH}" 2>/dev/null || true
            chmod 666 "${WP_DEBUG_LOG_PATH}"
        else
            LOG_LINE="define( 'WP_DEBUG_LOG', false );"
        fi
        # Rebuild the file (head + constants + tail) — more reliable than sed -i ... i
        HEAD_LINES=$((INSERT_LINE - 1))
        head -n "${HEAD_LINES}" "${WPCONFIG}" > "${WPCONFIG}.debug.tmp"
        echo "define( 'WP_DEBUG', ${DEBUG_VAL} );" >> "${WPCONFIG}.debug.tmp"
        echo "${LOG_LINE}" >> "${WPCONFIG}.debug.tmp"
        echo "define( 'WP_DEBUG_DISPLAY', ${DISPLAY_VAL} );" >> "${WPCONFIG}.debug.tmp"
        echo "define( 'FS_METHOD', 'direct' );" >> "${WPCONFIG}.debug.tmp"
        tail -n +${INSERT_LINE} "${WPCONFIG}" >> "${WPCONFIG}.debug.tmp"
        mv "${WPCONFIG}.debug.tmp" "${WPCONFIG}"
        echo "[WP_DEBUG] Done. Constants in file: $(grep -c "WP_DEBUG" "${WPCONFIG}" || echo 0)"
    fi
fi

# After install (or if already installed), start php-fpm as root.
# php-fpm workers run as UID:GID (same owner as WordPress files and WP-CLI).
sed -i 's/^user = www-data/user = user/' /usr/local/etc/php-fpm.d/www.conf
sed -i 's/^group = www-data/group = user/' /usr/local/etc/php-fpm.d/www.conf
echo "Starting php-fpm as root..."
exec "$@"
