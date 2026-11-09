#!/bin/sh
set -eu

: "${DOMAIN_NAME:?Falta DOMAIN_NAME}"

mkdir -p /etc/nginx/ssl

if [ ! -s /etc/nginx/ssl/inception.crt ] ||
   [ ! -s /etc/nginx/ssl/inception.key ]; then
    echo "NGINX: generando certificado autofirmado"
    (
        umask 077
        openssl req -x509 -nodes -newkey rsa:2048 \
            -days 365 \
            -keyout /etc/nginx/ssl/inception.key \
            -out /etc/nginx/ssl/inception.crt \
            -subj "/CN=$DOMAIN_NAME" \
            -addext "subjectAltName=DNS:$DOMAIN_NAME"
    )
fi

envsubst '${DOMAIN_NAME}' \
    < /etc/nginx/templates/default.conf.template \
    > /etc/nginx/conf.d/default.conf

nginx -t

echo "NGINX: arrancando servidor HTTPS"
exec nginx -g 'daemon off;'
