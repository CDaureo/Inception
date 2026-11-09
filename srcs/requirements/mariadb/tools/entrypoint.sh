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
    for identifier in "$MYSQL_DATABASE" "$MYSQL_USER"; do
        case "$identifier" in
            *[!a-zA-Z0-9_]*) exit 1 ;;
        esac
    done
    [ "$MYSQL_USER" != root ]
    [ -n "$db_password" ] && [ -n "$root_password" ]
    case "$db_password$root_password" in
        *[!0-9a-fA-F]*) exit 1 ;;
    esac

    # Bootstrap ejecuta SQL sin abrir un servidor de red y termina.
    # No se lanza ningun proceso en segundo plano.
    echo "MariaDB: configurando base y cuentas en modo bootstrap"
    bootstrap_log=$(mktemp /run/mysqld/inception-bootstrap.XXXXXX)
    if mariadbd --bootstrap --user=mysql --datadir="$data" \
        --skip-networking > "$bootstrap_log" 2>&1 <<SQL
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%'
    IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.*
    TO '${MYSQL_USER}'@'%';
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${root_password}');
SQL
    then
        rm -f "$bootstrap_log"
    else
        echo "MariaDB: fallo bootstrap; registro local protegido: $bootstrap_log" >&2
        exit 1
    fi

    # Marcar solo despues de completar el bootstrap correctamente.
    touch "$data/.inception-ready"
    unset db_password root_password
fi

# Ejecutar MariaDB en primer plano como PID 1 del contenedor.
exec mariadbd --user=mysql --socket="$socket"
