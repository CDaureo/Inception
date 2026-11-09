#!/bin/sh
set -eu

# Comprobar la configuración necesaria.
: "${DOMAIN_NAME:?Falta DOMAIN_NAME}"
: "${MYSQL_DATABASE:?Falta MYSQL_DATABASE}"
: "${MYSQL_USER:?Falta MYSQL_USER}"
: "${WP_VERSION:?Falta WP_VERSION}"
: "${WP_TITLE:?Falta WP_TITLE}"
: "${WP_OWNER_USER:?Falta WP_OWNER_USER}"
: "${WP_OWNER_EMAIL:?Falta WP_OWNER_EMAIL}"
: "${WP_READER_USER:?Falta WP_READER_USER}"
: "${WP_READER_EMAIL:?Falta WP_READER_EMAIL}"

for secret in db_password wp_owner_password wp_reader_password; do
    if [ ! -s "/run/secrets/$secret" ]; then
        echo "WordPress: falta el secreto $secret" >&2
        exit 1
    fi
done

owner_lower=$(printf '%s' "$WP_OWNER_USER" | tr '[:upper:]' '[:lower:]')

case "$owner_lower" in
    *admin*)
        echo "WordPress: el administrador no puede contener admin" >&2
        exit 1
        ;;
esac

if [ "$WP_OWNER_USER" = "$WP_READER_USER" ]; then
    echo "WordPress: los dos usuarios deben ser distintos" >&2
    exit 1
fi

mkdir -p /run/php /var/www/html
chown -R www-data:www-data /var/www/html
cd /var/www/html

# Ejecutar WP-CLI como el usuario de PHP.
export WP_CLI_CACHE_DIR=/var/www/.wp-cli/cache
mkdir -p "$WP_CLI_CACHE_DIR"
chown -R www-data:www-data /var/www/.wp-cli

wp_cmd() {
    runuser -u www-data -- wp --path=/var/www/html "$@"
}

# Esperar a MariaDB con un máximo de 30 intentos.
echo "WordPress: esperando a MariaDB"
ready=0

for attempt in $(seq 1 30); do
    if php -r '
        mysqli_report(MYSQLI_REPORT_OFF);
        $db = mysqli_init();
        $db->options(MYSQLI_OPT_CONNECT_TIMEOUT, 3);
        $ok = @$db->real_connect(
            "mariadb",
            getenv("MYSQL_USER"),
            rtrim(file_get_contents("/run/secrets/db_password"), "\r\n"),
            getenv("MYSQL_DATABASE"),
            3306
        );
        exit($ok ? 0 : 1);
    '; then
        ready=1
        break
    fi
    sleep 2
done

if [ "$ready" -ne 1 ]; then
    echo "WordPress: no se pudo conectar a MariaDB" >&2
    exit 1
fi

# Descargar WordPress únicamente si sus archivos no existen.
if [ ! -f wp-includes/version.php ]; then
    echo "WordPress: descargando archivos"
    wp_cmd core download --version="$WP_VERSION"
fi

# Crear la configuración sin poner la contraseña en argumentos.
if [ ! -f wp-config.php ]; then
    echo "WordPress: creando configuración"
    wp_cmd config create \
        --dbname="$MYSQL_DATABASE" \
        --dbuser="$MYSQL_USER" \
        --dbhost="mariadb:3306" \
        --dbcharset="utf8mb4" \
        --prompt=dbpass \
        < /run/secrets/db_password
fi

chmod 640 wp-config.php

# Instalar las tablas y el propietario solo la primera vez.
if ! wp_cmd core is-installed; then
    echo "WordPress: instalando sitio"
    wp_cmd core install \
        --url="https://$DOMAIN_NAME" \
        --title="$WP_TITLE" \
        --admin_user="$WP_OWNER_USER" \
        --admin_email="$WP_OWNER_EMAIL" \
        --skip-email \
        --prompt=admin_password \
        < /run/secrets/wp_owner_password
fi

# Crear la segunda cuenta si todavía no existe.
if ! wp_cmd user get "$WP_READER_USER" --field=ID >/dev/null 2>&1; then
    echo "WordPress: creando segundo usuario"
    wp_cmd user create \
        "$WP_READER_USER" "$WP_READER_EMAIL" \
        --role=subscriber \
        --prompt=user_pass \
        < /run/secrets/wp_reader_password
fi

echo "WordPress: arrancando PHP-FPM"
exec php-fpm8.2 -F
