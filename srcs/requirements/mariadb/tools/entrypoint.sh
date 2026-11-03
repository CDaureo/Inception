#!/bin/sh
set -eu
umask 077

fail() {
    echo "MariaDB: $*" >&2
    exit 1
}

# Validar nombres antes de introducirlos en SQL.
: "${MYSQL_DATABASE:?Falta MYSQL_DATABASE}"
: "${MYSQL_USER:?Falta MYSQL_USER}"

case "$MYSQL_DATABASE" in
    [0-9]*|*[!a-zA-Z0-9_]*)
        fail "MYSQL_DATABASE debe empezar por una letra o _ y usar letras, números o _"
        ;;
esac

case "$MYSQL_USER" in
    *[!a-zA-Z0-9_]*)
        fail "MYSQL_USER solo puede contener letras, números o _"
        ;;
    root|mysql|mariadb.sys)
        fail "Usa un usuario SQL propio para WordPress"
        ;;
esac

[ "${#MYSQL_DATABASE}" -le 64 ] || fail "Nombre de base demasiado largo"
[ "${#MYSQL_USER}" -le 80 ] || fail "Nombre de usuario demasiado largo"

# Este script acepta las contraseñas hexadecimales del paso 8.
read_secret() {
    [ -r "$1" ] || fail "No se puede leer el secreto $1"
    value=$(cat "$1")

    case "$value" in
        ""|*[!0-9a-fA-F]*)
            fail "El secreto $1 debe ser hexadecimal"
            ;;
    esac

    [ "${#value}" -eq 48 ] || fail "El secreto $1 debe tener 48 caracteres"
    printf '%s' "$value"
}

db_password=$(read_secret /run/secrets/db_password)
root_password=$(read_secret /run/secrets/db_root_password)

data=/var/lib/mysql
socket=/run/mysqld/mysqld.sock

mkdir -p "$data" /run/mysqld
chown mysql:mysql "$data" /run/mysqld
chmod 750 "$data" /run/mysqld

# Detectar una instalación de tablas interrumpida.
if [ -e "$data/.initializing" ]; then
    fail "La instalación de tablas se interrumpió. Revisa el volumen antes de continuar."
fi

if [ ! -d "$data/mysql" ]; then
    # No inicializar encima de archivos desconocidos.
    if [ -n "$(find "$data" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
        fail "El directorio de datos no está vacío y no contiene las tablas del sistema."
    fi

    echo "MariaDB: inicializando tablas del sistema"
    touch "$data/.initializing"

    mariadb-install-db \
        --user=mysql \
        --datadir="$data" \
        --auth-root-authentication-method=socket \
        --skip-test-db

    rm "$data/.initializing"
fi

# Solo configurar cuentas mientras falte la marca de finalización.
if [ ! -f "$data/.inception-ready" ]; then
    echo "MariaDB: preparando base de datos y cuentas"

    mariadbd \
        --user=mysql \
        --datadir="$data" \
        --socket="$socket" \
        --skip-networking &
    temporary_pid=$!

    cleanup() {
        kill -TERM "$temporary_pid" 2>/dev/null || true
        wait "$temporary_pid" 2>/dev/null || true
    }

    trap cleanup EXIT
    trap 'exit 1' HUP INT TERM

    attempts=0
    until mariadb --protocol=socket --socket="$socket" \
        -u root -e "SELECT 1" >/dev/null 2>&1
    do
        kill -0 "$temporary_pid" 2>/dev/null \
            || fail "El servidor temporal terminó antes de estar disponible"

        attempts=$((attempts + 1))
        [ "$attempts" -lt 60 ] \
            || fail "El servidor temporal no respondió en 60 segundos"

        sleep 1
    done

    mariadb --protocol=socket --socket="$socket" -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%'
    IDENTIFIED BY '${db_password}';

GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.*
    TO '${MYSQL_USER}'@'%';

SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${root_password}');
SQL

    kill -TERM "$temporary_pid"
    wait "$temporary_pid"
    trap - EXIT HUP INT TERM

    touch "$data/.inception-ready"
fi

unset db_password root_password

echo "MariaDB: arrancando servidor definitivo"
exec mariadbd --user=mysql --datadir="$data" --socket="$socket"
