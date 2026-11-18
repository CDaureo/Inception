#!/bin/sh
set -eu
umask 077

project_dir=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
cd "$project_dir"

fail() {
    echo "ERROR: $*" >&2
    exit 1
}

command -v openssl >/dev/null 2>&1 ||
    fail "Instala openssl dentro de la VM."

command -v docker >/dev/null 2>&1 ||
    fail "Instala Docker dentro de la VM."

#command -v git >/dev/null 2>&1 ||
#    fail "Instala Git."

[ -f srcs/.env.example ] ||
    fail "No existe srcs/.env.example."

# No preparar credenciales si Git sigue rastreando secretos.
#tracked=$(git ls-files -- srcs/.env secrets)
#[ -z "$tracked" ] ||
#    fail "Git sigue rastreando .env o secrets/. Corrige sus exclusiones."

#git check-ignore -q --no-index srcs/.env ||
#    fail "Falta excluir srcs/.env en .gitignore."

#git check-ignore -q --no-index secrets/db_password.txt ||
#   fail "Falta excluir secrets/ en .gitignore."

docker_root=$(sudo docker info --format '{{.DockerRootDir}}') ||
    fail "Docker no esta disponible."

[ "$docker_root" = "/home/cdaureo-/data/docker" ] ||
    fail "Configura Docker data-root como /home/cdaureo-/data/docker. Revisa DEV_DOC.md antes de modificar almacenamiento existente."

sudo docker compose version >/dev/null ||
    fail "Instala el plugin de Docker Compose."

# Si falta configuracion pero existen volumenes, no inventar
# contrasenas para una instalacion que puede contener datos.
missing=0
[ -f srcs/.env ] || missing=1

for name in db_root_password db_password wp_owner_password wp_reader_password; do
    [ -s "secrets/$name.txt" ] || missing=1
done

if [ "$missing" -eq 1 ]; then
    for volume in inception_database inception_website; do
        if sudo docker volume inspect "$volume" >/dev/null 2>&1; then
            fail "Existe el volumen $volume y falta configuracion local. Restaura los archivos originales; no generes otros sobre esos datos."
        fi
    done
fi

# Comprobar archivos vacios antes de crear nada.
for name in db_root_password db_password wp_owner_password wp_reader_password; do
    file="secrets/$name.txt"
    if [ -e "$file" ] && [ ! -s "$file" ]; then
        fail "$file existe pero esta vacio. Revisalo."
    fi
done

if [ ! -e srcs/.env ]; then
    cp srcs/.env.example srcs/.env
    echo "Creado srcs/.env desde la plantilla."
else
    echo "Conservado srcs/.env."
fi

chmod 600 srcs/.env
mkdir -p secrets
chmod 700 secrets

for name in db_root_password db_password wp_owner_password wp_reader_password; do
    file="secrets/$name.txt"

    if [ -e "$file" ]; then
        echo "Conservado $file."
    else
        temporary=$(mktemp "secrets/.password.XXXXXX")
        if ! openssl rand -hex 24 > "$temporary"; then
            fail "No se pudo generar $file."
        fi
        mv "$temporary" "$file"
        echo "Creado $file."
    fi

    chmod 600 "$file"
done

sudo docker compose --env-file srcs/.env \
    -f srcs/docker-compose.yml config --quiet

echo "Preparacion terminada."
echo "Revisa srcs/.env antes del primer arranque."
echo "Despues ejecuta: make"
