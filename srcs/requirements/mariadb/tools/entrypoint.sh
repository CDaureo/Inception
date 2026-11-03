#!/bin/sh
set -eu
umask 077

# Comprobar las variables recibidas desde Compose.
: "${MYSQL_DATABASE:?Falta MYSQL_DATABASE}"
: "${MYSQL_USER:?Falta MYSQL_USER}"

data=/var/lib/mysql
socket=/run/mysqld/mysqld.sock

# Preparar los directorios y sus propietarios.
mkdir -p "$data" /run/mysqld
chown mysql:mysql "$data" /run/mysqld

# Inicializar las tablas internas solo si no existen.
if [ ! -d "$data/mysql" ]; then
    mariadb-install-db --user=mysql --datadir="$data" \
        --auth-root-authentication-method=socket --skip-test-db
fi

# Configurar la base y las cuentas solo la primera vez.
if [ ! -f "$data/.inception-ready" ]; then
    db_password=$(cat /run/secrets/db_password)
    root_password=$(cat /run/secrets/db_root_password)

    # Validar los valores antes de introducirlos en SQL.
    case "$MYSQL_DATABASE:$MYSQL_USER" in
        *[!a-zA-Z0-9_:]*) exit 1 ;;
    esac
    [ "$MYSQL_USER" != root ]
    [ -n "$db_password" ] && [ -n "$root_password" ]
    case "$db_password$root_password" in
        *[!0-9a-fA-F]*) exit 1 ;;
    esac

    # Arrancar un servidor temporal sin conexiones de red.
    mariadbd --user=mysql --socket="$socket" --skip-networking &
    pid=$!

    # Detener el servidor temporal si falla la inicialización.
    cleanup() {
        kill -TERM "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    }
    trap cleanup EXIT
    trap 'exit 1' HUP INT TERM

    # Esperar a que responda, con un límite de intentos.
    attempts=0
    until mariadb --socket="$socket" -u root \
        -e 'SELECT 1' >/dev/null 2>&1
    do
        kill -0 "$pid"
        attempts=$((attempts + 1))
        [ "$attempts" -lt 60 ] || exit 1
        sleep 1
    done

    # Crear la base, conceder permisos y configurar root local.
    mariadb --socket="$socket" -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%'
    IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.*
    TO '${MYSQL_USER}'@'%';
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${root_password}');
SQL

    # Detener el servidor temporal y marcar la configuración completada.
    kill -TERM "$pid"
    wait "$pid"
    trap - EXIT HUP INT TERM
    touch "$data/.inception-ready"
    unset db_password root_password
fi

# Ejecutar MariaDB en primer plano como PID 1 del contenedor.
exec mariadbd --user=mysql --socket="$socket"
