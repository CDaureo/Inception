# Inception: guía desde cero, trabajo en casa y traslado a 42

## Mi progreso y dónde continuar

**Última revisión: 3 de noviembre de 2026.** Estado comprobado leyendo los archivos del repositorio. No se ha arrancado Docker ni comprobado la VM en esta revisión.

**Punto de continuación: corregir las exclusiones de Git (sección 8) y comprobar MariaDB (sección 9). Después, empezar WordPress y PHP-FPM (sección 10).**

Leyenda: `[x]` significa que esa tarea concreta está hecha en los archivos; `[ ]` significa pendiente o todavía sin verificar. Tener un servicio escrito no significa que esté probado. Las casillas de la sección 2 siguen siendo la comprobación final de la infraestructura completa.

### Lo que ya tengo hecho

- [x] Repositorio Git independiente de Inception creado.
- [x] Estructura de MariaDB creada con carpetas `conf/` y `tools/`.
- [x] Archivo local `srcs/.env` y cuatro archivos de contraseñas en `secrets/` creados; falta excluirlos de Git.
- [x] Plantilla de variables creada en `srcs/.env.carpeta/example`; falta situarla en `srcs/.env.example` y revisar que solo contenga ejemplos.
- [x] Dockerfile propio de MariaDB escrito con base `debian:bookworm`, instalación del servidor y entrypoint.
- [x] Configuración `50-server.cnf` escrita para escuchar en la red del contenedor en el puerto 3306.
- [x] Script de MariaDB escrito: validación de variables y secretos, inicialización, servidor temporal, creación de base y usuario, marca de inicialización y arranque final con `exec`.
- [x] Compose inicial escrito para construir `mariadb:inception`, pasar variables y montar los dos secretos de base de datos.
- [x] Volumen con nombre `database` y red `inception` declarados y asignados a MariaDB, sin publicar 3306 al host.
- [x] Política `restart: on-failure` declarada para MariaDB.

### Próxima sesión: seguir este orden

1. [ ] **Corregir Git — secciones 8 y 17.** `.gitignore` está vacío y Git ya rastrea `srcs/.env` y los cuatro archivos de `secrets/`. Añadir las exclusiones de la sección 8 y retirar esos archivos del índice conservando las copias locales (`git rm --cached -- srcs/.env secrets/*.txt`). Comprobar con `git ls-files srcs/.env secrets` que ya no aparecen. Esto no elimina versiones anteriores del historial; si las contraseñas se publicaron, cambiarlas y tratar su presencia en el historial.
2. [ ] **Ordenar la plantilla — sección 8.** Colocar la plantilla en `srcs/.env.example`, con valores de ejemplo y sin contraseñas reales.
3. [ ] **Confirmar el entorno — secciones 4 a 6.** Verificar que trabajas dentro de la VM, que Docker y Compose funcionan y que el almacenamiento está bajo `/home/tu_login/data`. No cambiar `data-root` sin revisar primero si ya hay datos.
4. [ ] **Validar y arrancar MariaDB — sección 9.** Desde la raíz del repositorio y dentro de la VM, ejecutar los comandos de abajo. Revisar que el servidor queda listo y no entra en un ciclo de reinicios.
5. [ ] **Comprobar MariaDB antes de avanzar.** Verificar acceso con el usuario SQL a su base, permisos, persistencia tras recrear el contenedor sin borrar el volumen y arranque repetido sin reinicializar datos. Anotar el resultado.
6. [ ] **Empezar WordPress + PHP-FPM — sección 10.** Crear su Dockerfile, configuración y script de instalación; después añadir el servicio y el volumen web a Compose.

Comandos para el paso 4 (todavía no hay Makefile):

```bash
sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml config --quiet
sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml up -d --build mariadb
sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml ps
sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs --tail=100 mariadb
```

### Lo que queda después

- [ ] NGINX, certificado TLS y acceso HTTPS — sección 11.
- [ ] Compose completo con los tres servicios, dos volúmenes y comprobaciones de disponibilidad — sección 12.
- [ ] Makefile — sección 13.
- [ ] Dominio y acceso desde el navegador — sección 14.
- [ ] Arranque de la pila completa y pruebas de usuarios, TLS, persistencia y reinicios — secciones 15 y 16.
- [ ] `README.md`, `USER_DOC.md` y `DEV_DOC.md` — sección 21.
- [ ] Ensayo de traslado, respaldo y restauración; evaluación en 42 — secciones 18 a 20.

**Al terminar cada sesión:** marca solo las tareas comprobadas, actualiza la fecha y el punto de continuación, y anota aquí cualquier error pendiente con el siguiente paso concreto. No guardes contraseñas ni salidas que las contengan.

---

## Resumen

Esta guía explica cómo abordar el enunciado que has compartido, aunque todavía no conozcas Docker, servidores web o bases de datos. Es un plan de construcción y comprobación: los fragmentos ilustran piezas del proyecto, pero no constituyen una implementación completa lista para ejecutar.

Referencia temporal: 13 de octubre de 2026. Antes de empezar, compara siempre esta guía con tu enunciado y hoja de evaluación vigentes. Los permisos y herramientas disponibles en 42 Madrid debes confirmarlos allí; esta guía no presupone que puedas instalar software en los ordenadores del campus.

**Puedes desarrollar y probar el proyecto en casa dentro de una máquina virtual y trasladarlo después.** La opción más reproducible consiste en llevar el repositorio y reconstruir los servicios dentro de una VM de destino. Exportar la VM completa puede servir como alternativa si el hipervisor, la arquitectura y las normas del campus lo permiten.

El proyecto Inception debe tener su propio repositorio. No lo mezcles con los ejercicios de C++: tendrá su propio Makefile, README y entrega.

## Contenido

### 1. Qué estás construyendo

Vas a montar un sitio WordPress cuyos componentes están separados:

```text
Ordenador físico: casa o 42
└── Máquina virtual Linux: aquí se ejecuta Docker
    ├── NGINX: recibe HTTPS por el puerto 443
    │   └── envía peticiones PHP a wordpress:9000
    ├── WordPress + PHP-FPM: ejecuta la aplicación
    │   └── consulta la base de datos en mariadb:3306
    ├── MariaDB: guarda usuarios, entradas y configuración
    ├── red Docker: comunica los tres contenedores
    └── dos volúmenes con nombre: base de datos y archivos web
```

| Concepto | Explicación sencilla |
|---|---|
| Máquina virtual, VM | Un ordenador simulado con su propio sistema operativo y kernel. |
| Host de Docker | El sistema donde funciona Docker Engine. En este proyecto es la VM, no necesariamente el ordenador físico. |
| Imagen | Plantilla con paquetes, archivos y configuración para crear contenedores. |
| Dockerfile | Receta con la que construyes una imagen. |
| Contenedor | Ejecución aislada de un servicio; comparte el kernel del host de Docker. |
| Docker Compose | Describe y coordina servicios, redes, volúmenes y secretos en YAML. |
| Volumen | Almacenamiento que puede sobrevivir a la eliminación del contenedor. |
| NGINX | Servidor que recibe las conexiones web y sirve archivos o delega PHP. |
| PHP-FPM | Procesos que ejecutan el código PHP de WordPress. No es un servidor HTTP para el navegador. |
| MariaDB | Servidor de base de datos utilizado por WordPress. |
| TLS | Cifra la comunicación HTTPS entre navegador y NGINX. |
| DNS / hosts | Traduce un nombre como `tu_login.42.fr` a una dirección IP. |
| PID 1 | Proceso principal del contenedor, responsable de recibir señales y finalizar correctamente. |

El navegador nunca debe conectarse directamente a MariaDB o PHP-FPM. Los puertos internos 3306 y 9000 pueden utilizarse entre contenedores sin publicarlos hacia fuera.

### 2. Requisitos que debes convertir en una lista de comprobación

- [ ] Todo se monta y demuestra en una VM.
- [ ] Tres servicios separados: `nginx`, `wordpress` y `mariadb`.
- [ ] Un Dockerfile propio por servicio, construido desde Compose mediante Makefile.
- [ ] Imágenes propias con el nombre del servicio y una etiqueta explícita, por ejemplo `nginx:inception`.
- [ ] Base Alpine o Debian de la penúltima versión estable; nunca `latest`.
- [ ] Ninguna imagen prefabricada de NGINX, WordPress o MariaDB.
- [ ] NGINX es la única entrada a la infraestructura, por 443 y TLS 1.2/1.3.
- [ ] WordPress tiene PHP-FPM y no tiene NGINX; MariaDB tampoco tiene NGINX.
- [ ] Dos volúmenes con nombre, sin bind mounts para esos datos, almacenados bajo `/home/tu_login/data` en el host de Docker.
- [ ] Red declarada en Compose y asignada a los servicios; sin host network, `links` ni `--link`.
- [ ] Política de reinicio ante caídas.
- [ ] Procesos reales en primer plano, sin trucos para mantener vivo el contenedor.
- [ ] Dos usuarios de WordPress; uno administrador cuyo nombre no contiene `admin` en ninguna combinación de mayúsculas y minúsculas.
- [ ] Dominio `tu_login.42.fr` apuntando a la IP accesible correcta.
- [ ] `.env` local, variables de entorno y secretos fuera de Git.
- [ ] `README.md`, `USER_DOC.md` y `DEV_DOC.md` en la raíz del repositorio.

Los dos usuarios exigidos son cuentas de WordPress guardadas en su base de datos. No debes confundirlos con la cuenta SQL que WordPress utiliza para conectarse a MariaDB.

### 3. Qué puedes hacer en casa y qué se hace en destino

| Trabajo | En casa | Al llegar a 42 |
|---|---|---|
| Aprender, escribir Dockerfiles y scripts | Sí | Revisar y explicar |
| Crear y probar la VM | Sí | Importar o crear una compatible |
| Desarrollar Compose y Makefile | Sí | Reconstruir y ejecutar |
| Documentación y Git | Sí | Clonar la versión entregable |
| Secretos y `.env` | Crear localmente | Transferir de forma privada o recrear |
| Entradas y archivos de WordPress | Crear datos de prueba | Restaurarlos si quieres conservarlos |
| Resolución del dominio y red | Configurar para casa | Adaptar a la nueva IP y red |
| Pruebas finales | Hacerlas todas | Repetirlas en el entorno real de evaluación |

Antes de invertir tiempo en una VM grande, confirma en el campus: hipervisor disponible, arquitectura de CPU, espacio persistente, permisos, acceso a Internet y procedimiento de evaluación. El enunciado proporcionado no confirma estas condiciones locales.

### 4. Preparar una máquina virtual en casa

1. Comprueba la arquitectura de tu equipo y, si puedes, la del destino: `x86_64/amd64` o `aarch64/arm64`.
2. Usa un hipervisor compatible con tu equipo y con las condiciones del campus. Una VM ARM no se importa como VM x86 sin más; emular otra arquitectura es una decisión distinta.
3. Descarga una ISO oficial de Debian y crea una VM. Como punto de partida orientativo: 2 CPU, 4 GB de RAM y 25–30 GB de disco dinámico, si tu equipo dispone de esos recursos. No son requisitos oficiales del proyecto.
4. Instala Linux, crea tu usuario y configura acceso administrativo con `sudo`.
5. Mantén la VM dedicada a Inception, especialmente porque ajustarás dónde guarda los datos Docker.
6. Instala utilidades básicas dentro de la VM:

```bash
sudo apt update
sudo apt install git make curl ca-certificates openssl nano
```

7. Trabaja desde una terminal de la VM. Puedes editar con VS Code conectado por SSH a ella; lo importante es que compilación, Docker y pruebas se ejecuten allí.
8. Haz una instantánea con el sistema apagado después de la instalación básica. Una instantánea facilita volver atrás, pero no sustituye una copia fuera del disco de la VM.

**Versión del sistema y versión de la imagen son cosas distintas.** Según las páginas oficiales consultadas, Debian 13 es estable y Debian 12 es la anterior; para las imágenes, `FROM debian:bookworm` es una elección coherente con ese estado. Vuelve a comprobarlo al comenzar y antes de entregar. No utilices `debian:stable` u `oldstable` para esconder qué versión has elegido. [Versiones de Debian](https://www.debian.org/releases/).

### 5. Instalar Docker dentro de la VM

Sigue el procedimiento oficial para Debian: añade la clave y repositorio APT de Docker, actualiza índices e instala Docker Engine y el plugin de Compose. No mezcles instrucciones de Docker Desktop, paquetes de otras distribuciones y el repositorio oficial. [Instalación en Debian](https://docs.docker.com/engine/install/debian/).

Una vez configurado ese repositorio, los paquetes que necesitas son:

```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker version
sudo docker compose version
```

`docker compose` es el comando moderno con espacio. No hace falta descargar imágenes de demostración ajenas al proyecto para comprobar la instalación.

Los comandos de esta guía usan `sudo docker`. Si configuras tu usuario para usar Docker sin sudo, hazlo conscientemente: ese acceso permite operaciones con privilegios elevados sobre la VM. Escoge una modalidad y úsala de forma consistente.

### 6. Resolver los volúmenes antes de programar

Tu enunciado exige a la vez:

1. Dos volúmenes Docker con nombre.
2. Que estén almacenados bajo `/home/tu_login/data`.
3. Que esos almacenamientos no usen bind mounts.

No copies una receta antigua con `driver_opts`, `type: none`, `o: bind` y `device: /home/...`: ponerle nombre no elimina el bind que hay debajo.

**Propuesta para una VM nueva y dedicada:** configurar el `data-root` de Docker dentro de `/home/tu_login/data/docker`. Así Docker administra volúmenes normales bajo esa carpeta. Esto cumple técnicamente las condiciones citadas; revisa además cualquier precisión adicional de tu hoja de evaluación sobre la estructura exacta de carpetas. [Configuración del daemon](https://docs.docker.com/engine/daemon/).

Antes de crear imágenes o datos del proyecto:

```bash
sudo systemctl stop docker.service docker.socket
sudo mkdir -p /home/tu_login/data/docker
sudo mkdir -p /etc/docker
sudo nano /etc/docker/daemon.json
```

Sustituye `tu_login` por tu login real. Si el archivo ya existe, integra la opción en su JSON; no borres otras opciones. En una instalación sin configuración previa:

```json
{
  "data-root": "/home/tu_login/data/docker"
}
```

Después:

```bash
sudo systemctl start docker
sudo docker info --format '{{.DockerRootDir}}'
```

El resultado debe ser la ruta elegida. Los volúmenes estarán normalmente en `.../volumes/NOMBRE/_data`; compruébalo con `docker volume inspect` tras crearlos. No presupongas que todos los componentes de Docker, incluidas imágenes gestionadas por containerd, se trasladan mediante esa única opción.

**Si ya había datos Docker, para aquí antes de cambiar la ruta:** cambiar `data-root` no migra lo que existía. Necesitarás un plan de respaldo y migración o una VM nueva. No apliques esta configuración global a una máquina compartida del campus.

### 7. Crear el repositorio independiente

Dentro de la VM, crea una carpeta de trabajo, por ejemplo `~/Inception`:

```bash
mkdir -p ~/Inception
cd ~/Inception
git init
mkdir -p secrets srcs/requirements/{nginx,wordpress,mariadb}/{conf,tools}
```

Estructura propuesta:

```text
Inception/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore
├── secrets/                       # archivos reales ignorados por Git
└── srcs/
    ├── .env                       # local, ignorado por Git
    ├── .env.example               # plantilla sin credenciales reales
    ├── docker-compose.yml
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   ├── conf/
        │   └── tools/
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   ├── conf/
        │   └── tools/
        └── mariadb/
            ├── Dockerfile
            ├── .dockerignore
            ├── conf/
            └── tools/
```

No necesitas implementar bonus para completar la parte obligatoria. Empieza por los tres servicios y deja los extras para después.

### 8. Variables y secretos sin publicar contraseñas

Antes de generar secretos, crea `.gitignore`:

```gitignore
srcs/.env
secrets/
backups/
*.sql
*.sql.gz
*.key
*.pem
```

Revisa manualmente también certificados privados, copias de VM, capturas y otros archivos: estas reglas no detectan todos los secretos posibles.

Plantilla `srcs/.env.example`, con datos de ejemplo que debes personalizar:

```dotenv
DOMAIN_NAME=tu_login.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_app
WP_TITLE=Mi sitio Inception
WP_OWNER_USER=site_owner
WP_OWNER_EMAIL=owner@example.invalid
WP_READER_USER=reader
WP_READER_EMAIL=reader@example.invalid
```

Cópiala a `.env` y configura allí tus valores locales. Los nombres de variables son una propuesta, no una interfaz automática de Docker o WordPress: tus scripts deben leerlos. `.env` permite interpolar Compose; no introduce por sí solo todas sus variables en cada contenedor.

Genera cuatro contraseñas diferentes **solo cuando todavía no existan estos archivos**:

```bash
umask 077
openssl rand -hex 24 > secrets/db_root_password.txt
openssl rand -hex 24 > secrets/db_password.txt
openssl rand -hex 24 > secrets/wp_owner_password.txt
openssl rand -hex 24 > secrets/wp_reader_password.txt
chmod 700 secrets
chmod 600 secrets/*.txt
```

No vuelvas a ejecutar esas redirecciones sobre un proyecto inicializado: reemplazarían los secretos sin cambiar las contraseñas ya guardadas en MariaDB o WordPress.

Declara secretos en Compose y concede a cada servicio únicamente los que necesite. Se leen como archivos bajo `/run/secrets/`. Esto evita incluirlos en la imagen; en Compose local, los archivos originales siguen necesitando protección en el disco. No asumas cifrado automático. Si el proceso lector no es root, revisa sus permisos de acceso. [Secretos en Compose](https://docs.docker.com/compose/how-tos/use-secrets/).

Nunca copies el directorio `secrets` dentro de un Dockerfile ni uses contraseñas como `ARG`, `ENV` o valores literales en SQL versionado. Evita imprimirlas en logs o activar `set -x` en scripts de inicialización.

### 9. Construir primero MariaDB

Objetivo de esta fase: una base de datos accesible desde la red Docker y persistente, sin WordPress todavía.

Escribe su Dockerfile para:

1. Partir de la versión Debian elegida.
2. Instalar MariaDB mediante `apt-get`.
3. Copiar configuración y script de arranque propios.
4. Dar permisos de ejecución al script.
5. Usar el script como `ENTRYPOINT` con sintaxis JSON.

Configura MariaDB para escuchar en la interfaz del contenedor, no solamente en `127.0.0.1`. No publiques 3306 hacia el host. Monta el volumen de base de datos en `/var/lib/mysql`.

El script de arranque debe:

1. Validar variables y leer los secretos requeridos.
2. Preparar directorios y propietario adecuados para el usuario `mysql`.
3. Inicializar las tablas del sistema con `mariadb-install-db` únicamente si todavía no existen.
4. Iniciar temporalmente el servidor sin acceso de red para configurar las cuentas mediante su socket local.
5. Esperar disponibilidad con un número limitado de intentos y fallar claramente si no arranca.
6. Crear la base y usuario SQL de WordPress; conceder permisos solo sobre esa base. Preparar la cuenta root según la política elegida, sin acceso remoto innecesario.
7. Detener limpiamente ese servidor temporal y esperar su terminación.
8. Arrancar el proceso definitivo en primer plano, por ejemplo con `exec mariadbd --user=mysql` y la configuración necesaria.

Escapa y valida los valores introducidos en SQL: concatenar variables arbitrarias puede romper la consulta. Diseña el arranque para que un reinicio no borre la base ni sustituya cuentas existentes; una inicialización interrumpida debe poder detectarse y recuperarse.

Una espera limitada mientras arranca un servicio es diferente de un bucle infinito usado para mantener vivo el contenedor. El proceso permanente debe ser MariaDB.

### 10. Añadir WordPress y PHP-FPM

Objetivo: instalar WordPress automáticamente y ejecutar PHP-FPM, sin NGINX dentro de esta imagen.

En el Dockerfile instala PHP-FPM, el controlador de MariaDB/MySQL para PHP y las extensiones que necesite WordPress. Añade un cliente de base de datos si tus comprobaciones o WP-CLI lo requieren. Descarga WordPress y WP-CLI de sus fuentes oficiales con versiones explícitas, verificando sus artefactos cuando el proveedor lo permita. No uses una imagen prefabricada de WordPress.

Para evitar que un volumen oculte archivos necesarios, puedes conservar la distribución inicial en una ruta de la imagen, como `/usr/src/wordpress`, y copiarla a `/var/www/html` solo cuando sea necesario. El volumen web se monta en `/var/www/html`.

El script de inicialización debe:

1. Comprobar disponibilidad real de MariaDB.
2. Preparar los archivos del sitio sin sobrescribir contenido persistente.
3. Crear `wp-config.php` de forma segura con `DB_HOST=mariadb`, nombre de base, usuario y secreto.
4. Instalar WordPress si no está instalado: `wp core is-installed` permite distinguir el estado.
5. Crear el propietario administrador con un nombre como `site_owner`, sin `admin` dentro del nombre.
6. Crear la segunda cuenta con un rol diferente, por ejemplo `subscriber`.
7. Configurar la URL como `https://tu_login.42.fr` desde el principio.
8. Ejecutar finalmente PHP-FPM en primer plano con `exec`; en Debian Bookworm el binario habitual es `php-fpm8.2 -F`, pero comprueba la versión instalada.

WP-CLI ofrece `wp core install` para la instalación y `wp user create` para crear cuentas. No escribas contraseñas reales en comandos que vayas a guardar en documentación o historial; pásalas desde los archivos secretos dentro del proceso de instalación. [Instalación con WP-CLI](https://developer.wordpress.org/cli/commands/core/install/) y [creación de usuarios](https://developer.wordpress.org/cli/commands/user/create/).

Configura el pool de PHP-FPM para escuchar en `9000` por la red del contenedor y ejecutar trabajadores con el usuario adecuado. Un socket Unix aislado dentro de WordPress no es accesible desde NGINX sin compartirlo. Si PHP debe consultar variables de entorno, ten en cuenta `clear_env`; alternativamente prepara la configuración antes de arrancar FPM. [Configuración de PHP-FPM](https://www.php.net/manual/en/install.fpm.configuration.php).

No recurras a `chmod -R 777`. Ajusta propietarios y permisos según quién deba leer o escribir. Recuerda que un `wp-config.php` generado con contraseña también es sensible y estará dentro de la copia de los archivos web.

### 11. Añadir NGINX y TLS

Objetivo: servir el sitio exclusivamente por HTTPS y enviar PHP a WordPress.

Construye otra imagen Debian que instale NGINX y, si generarás el certificado en el arranque, OpenSSL. Elimina o deshabilita el sitio predeterminado que escuche en 80.

Fragmento orientativo de configuración; debes integrarlo en un archivo de servidor completo:

```nginx
server {
    listen 443 ssl;
    server_name tu_login.42.fr;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_certificate /etc/nginx/tls/site.crt;
    ssl_certificate_key /etc/nginx/tls/site.key;

    root /var/www/html;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        try_files $uri =404;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param HTTPS on;
        fastcgi_pass wordpress:9000;
    }

    location ~ /\. {
        deny all;
    }
}
```

NGINX debe ver los mismos archivos y rutas web que PHP-FPM. Monta el volumen web en modo solo lectura en NGINX. Sustituye el dominio mediante una plantilla controlada: si usas `envsubst`, limita la sustitución a tu variable de dominio para no borrar variables de NGINX como `$uri`.

Genera localmente un certificado autofirmado con SAN `DNS:tu_login.42.fr` y protege su clave privada. No incorpores una clave compartida al repositorio ni a la imagen. Un navegador puede advertir que no confía en el certificado: eso es distinto de un fallo de cifrado. Comprueba el nombre y certificado antes de aceptar la excepción local.

La configuración debe admitir únicamente TLS 1.2 y 1.3. Termina el entrypoint con `exec nginx -g 'daemon off;'`, tras validar con `nginx -t`. [Directivas TLS de NGINX](https://nginx.org/en/docs/http/ngx_http_ssl_module.html).

### 12. Unir los servicios con Compose

Escribe `srcs/docker-compose.yml`. Este ejemplo muestra la estructura; debes completarlo con variables, secretos y healthchecks acordes a tus scripts antes de ejecutarlo:

```yaml
name: inception

services:
  mariadb:
    build: ./requirements/mariadb
    image: mariadb:inception
    pull_policy: build
    restart: unless-stopped
    networks:
      - inception
    volumes:
      - database:/var/lib/mysql
    environment:
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
    secrets:
      - db_password
      - db_root_password

  wordpress:
    build: ./requirements/wordpress
    image: wordpress:inception
    pull_policy: build
    restart: unless-stopped
    networks:
      - inception
    volumes:
      - website:/var/www/html
    environment:
      DOMAIN_NAME: ${DOMAIN_NAME}
      MYSQL_DATABASE: ${MYSQL_DATABASE}
      MYSQL_USER: ${MYSQL_USER}
      WP_TITLE: ${WP_TITLE}
      WP_OWNER_USER: ${WP_OWNER_USER}
      WP_OWNER_EMAIL: ${WP_OWNER_EMAIL}
      WP_READER_USER: ${WP_READER_USER}
      WP_READER_EMAIL: ${WP_READER_EMAIL}
    secrets:
      - db_password
      - wp_owner_password
      - wp_reader_password

  nginx:
    build: ./requirements/nginx
    image: nginx:inception
    pull_policy: build
    restart: unless-stopped
    ports:
      - "443:443"
    networks:
      - inception
    volumes:
      - website:/var/www/html:ro
    environment:
      DOMAIN_NAME: ${DOMAIN_NAME}

networks:
  inception:
    driver: bridge

volumes:
  database:
  website:

secrets:
  db_password:
    file: ../secrets/db_password.txt
  db_root_password:
    file: ../secrets/db_root_password.txt
  wp_owner_password:
    file: ../secrets/wp_owner_password.txt
  wp_reader_password:
    file: ../secrets/wp_reader_password.txt
```

Las etiquetas `:inception` no son `latest`; cada repositorio de imagen conserva el nombre de su servicio. La política de construcción impide depender de imágenes de servicios preconstruidas; las imágenes base Debian sí se descargan.

Añade healthchecks reales y dependencias: WordPress debe esperar a MariaDB saludable, y NGINX a PHP-FPM y archivos preparados. Un `depends_on` simple solo ordena el arranque; usa `condition: service_healthy` cuando hayas definido la comprobación correspondiente. No declares salud únicamente porque existe un PID. [Orden de arranque en Compose](https://docs.docker.com/compose/how-tos/startup-order/).

La política de reinicio actúa cuando termina el proceso; un contenedor marcado `unhealthy` no se reinicia automáticamente solo por esa marca. Tu aplicación también debe gestionar fallos de conexión posteriores al arranque.

### 13. Crear el Makefile

El Makefile debe ser la puerta de entrada habitual al proyecto. Este ejemplo se ejecuta desde la raíz del repositorio; las líneas de receta llevan una tabulación real:

```makefile
COMPOSE = sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml

all: up

build:
	$(COMPOSE) build

up:
	$(COMPOSE) up -d --build

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

down:
	$(COMPOSE) down

status:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs --tail=100

config:
	$(COMPOSE) config --quiet

re: down
	$(MAKE) up

.PHONY: all build up stop start down status logs config re
```

`down` debe conservar los datos por defecto. No escondas `down -v`, `docker system prune --volumes` o un borrado de `/home/tu_login/data` dentro de un objetivo cotidiano. Si implementas un reinicio destructivo, sepáralo, avisa y requiere una decisión explícita.

Antes de arrancar, valida que `.env` y secretos existen. Un script propio de comprobación puede hacerlo sin imprimir sus contenidos.

### 14. Configurar el dominio y la red de la VM

Dentro de la VM, consulta las direcciones:

```bash
ip -br address
```

La IP correcta es la interfaz accesible desde el ordenador que abrirá el navegador; no uses una IP interna de contenedor obtenida de una red Docker.

En el equipo donde utilices el navegador, añade a su archivo `hosts` una línea equivalente a:

```text
192.168.56.10 tu_login.42.fr
```

La IP es solo un ejemplo. En Linux y macOS el archivo suele ser `/etc/hosts`; en Windows, `C:\Windows\System32\drivers\etc\hosts`. Editarlo requiere permisos. Si no los tienes en el campus, consulta el procedimiento permitido antes de la evaluación.

Hay varias topologías de VM:

- **Red puente:** la VM obtiene una dirección en la red local; puede no estar permitida en el campus.
- **Host-only más NAT:** el ordenador físico puede acceder a la VM por una red privada, mientras NAT ofrece salida a Internet.
- **NAT con redirección:** necesitas una regla del hipervisor desde el host a la VM. Para conservar la URL sin puerto adicional, el acceso final debe llegar al 443; no presentes 8443 como sustituto sin comprobar el criterio de evaluación.

Estas opciones pertenecen al hipervisor. Ninguna justifica usar `network_mode: host` en Compose.

Abre `https://tu_login.42.fr` para el sitio y `https://tu_login.42.fr/wp-admin/` para administración. No necesitas comprar un dominio ni publicar tu router hacia Internet. Dentro de la VM puedes probar el 443 publicado utilizando `127.0.0.1` con resolución temporal mediante curl.

### 15. Primer arranque y diagnóstico

Desde la raíz de Inception, cuando las piezas estén implementadas:

```bash
make config
make
make status
make logs
```

Comprueba de abajo arriba: MariaDB lista, WordPress instalado y PHP-FPM disponible, NGINX con configuración y certificado válidos, navegador funcionando.

Para no repetir una orden larga, puedes definir esta función en la terminal Bash de la VM; solo dura en esa sesión y se usa desde la raíz del proyecto:

```bash
dc() {
    sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml "$@"
}
```

Entonces:

```bash
dc ps
dc logs --tail=100 mariadb
dc logs --tail=100 wordpress
dc logs --tail=100 nginx
dc exec nginx nginx -t
dc images
```

`exec` ejecuta una orden dentro de un contenedor que ya está arrancado. Si se cae continuamente, consulta primero logs y configuración; no intentes resolverlo añadiendo un `tail -f`.

### 16. Pruebas que debes hacer antes de trasladarlo

#### Acceso y protocolos

Desde dentro de la VM, sustituye el dominio:

```bash
curl -kI --resolve tu_login.42.fr:443:127.0.0.1 https://tu_login.42.fr
openssl s_client -connect 127.0.0.1:443 -servername tu_login.42.fr -tls1_2 </dev/null
openssl s_client -connect 127.0.0.1:443 -servername tu_login.42.fr -tls1_3 </dev/null
```

`-k` omite la validación de confianza para diagnosticar un certificado autofirmado; no prueba que el certificado sea confiable. Comprueba también SAN, fechas y nombre con OpenSSL. TLS 1.2 y 1.3 deben negociar correctamente. TLS 1.0/1.1 deben rechazarse; un cliente moderno que los deshabilita por su cuenta no demuestra por sí solo que el servidor los rechace. Revisa además la configuración efectiva con `nginx -T`.

#### Usuarios y aplicación

1. Inicia sesión con el propietario administrador.
2. Comprueba que su nombre no contiene `admin`.
3. Comprueba la segunda cuenta y su rol.
4. Crea una entrada y sube una imagen pequeña.
5. Verifica que no aparece otra vez el asistente de instalación tras reiniciar.

#### Persistencia y aislamiento

1. Ejecuta `make down` y `make`.
2. Confirma que entrada, usuarios e imagen siguen presentes.
3. Reinicia la VM y comprueba Docker y los servicios.
4. Ejecuta `sudo docker volume inspect inception_database inception_website`; esos son los nombres esperados con el ejemplo Compose.
5. Comprueba que los `Mountpoint` están bajo `/home/tu_login/data` y que no hay opciones `o: bind` para esos volúmenes.
6. Revisa `dc ps`: únicamente NGINX debe publicar 443. Ver un puerto interno listado sin mapeo no equivale a publicarlo.
7. Revisa `dc top`: los procesos definitivos deben ser los servicios reales, no comandos de espera.
8. Comprueba que los logs no contienen contraseñas.

#### Reinicio por caída

En una instalación de prueba con respaldo, provoca la terminación inesperada del proceso principal de un servicio y observa la política de reinicio y sus logs. No uses una parada administrativa como prueba equivalente: Docker puede tratar `stop` y `kill` explícitos de forma diferente a una caída del proceso. Documenta exactamente cómo realizaste la prueba.

#### Reconstrucción independiente

Prueba a clonar el repositorio en otra VM o entorno limpio, crear sus secretos y ejecutar el Makefile. Debe funcionar sin archivos olvidados en tu primera VM. No borres tus datos principales para hacer este ensayo.

### 17. Guardar el trabajo en Git

Sí se versionan:

- Dockerfiles, scripts, configuraciones y `.dockerignore`.
- Compose y Makefile.
- `.env.example` sin datos sensibles.
- README, USER_DOC y DEV_DOC.

No se versionan:

- `.env` real y archivos secretos.
- Dumps SQL, archivos web persistentes y directorio de datos Docker.
- Claves privadas TLS, discos de VM y respaldos.

Antes de cada commit:

```bash
git status --short
git diff --cached
git check-ignore srcs/.env secrets/db_password.txt
git ls-files srcs/.env secrets
```

El último comando no debe enumerar archivos sensibles rastreados. `.gitignore` no borra lo que ya se haya subido ni limpia el historial. Si publicaste un secreto, revócalo o cámbialo y trata también su presencia en el historial; eliminar solo el archivo actual no basta.

### 18. Trasladarlo a 42: opción A, reconstrucción desde Git

Esta es la ruta principal propuesta:

1. En casa, deja una versión probada y subida al repositorio de entrega correspondiente.
2. Anota versiones de VM, base Debian, Docker, Compose, WordPress y WP-CLI.
3. Guarda un respaldo privado si quieres conservar el contenido del sitio.
4. En 42, crea una VM compatible con las herramientas y permisos disponibles.
5. Instala Docker y configura el almacenamiento antes de crear los volúmenes.
6. Clona el repositorio dentro de la VM.
7. Crea `.env` a partir de la plantilla y transfiere o genera secretos.
8. Ejecuta `make config` y `make`.
9. Adapta la resolución de `tu_login.42.fr` a la nueva IP.
10. Restaura el sitio si procede y repite las pruebas de la sección 16.

Si quieres empezar con una instalación nueva, puedes generar credenciales nuevas. Si restauras una base de datos existente, sus contraseñas y usuarios no cambian al editar secretos: coordina ambos estados. Para un traslado fiel, conserva los secretos originales de forma privada.

No necesitas copiar contenedores; se recrean desde las recetas. El código puede reconstruirse para otra arquitectura siempre que las bases y dependencias la soporten, pero debes probarlo en el destino.

### 19. Trasladarlo a 42: opción B, exportar la VM

1. Ejecuta una parada limpia de la pila.
2. Apaga completamente la VM; no copies un disco mientras sigue escribiendo.
3. Exporta usando el formato admitido por tu hipervisor y el de destino.
4. Transfiere el archivo mediante un medio privado y, si es posible, cifrado: contiene usuarios, secretos y bases de datos.
5. Importa en el destino si la arquitectura, versión del hipervisor y permisos son compatibles.
6. Ajusta tarjetas de red e IP; verifica que no haya conflictos de identidad de red.
7. Comprueba que existen los datos y secretos, arranca y repite las pruebas.

Conserva también el repositorio y la capacidad de reconstruirlo: una exportación que funciona en casa puede no poder importarse en el campus. No incluyas la VM en Git. Confirma si el procedimiento de evaluación exige reconstrucción desde cero.

### 20. Trasladar los datos sin llevar la VM completa

Tienes dos estados distintos que guardar: la base de datos y los archivos web. Guardar solo uno no conserva todo el sitio.

Para una copia portátil de MariaDB, prepara un dump lógico con `mariadb-dump`, verificando su código de salida; para tablas transaccionales, `--single-transaction` evita bloquearlas durante la lectura, pero no protege operaciones DDL concurrentes ni tablas no transaccionales. Para este proyecto, detén escrituras web durante la copia. [mariadb-dump](https://mariadb.com/docs/server/clients-and-utilities/backup-restore-and-import-clients/mariadb-dump).

Procedimiento propuesto, a implementar y ensayar en tus scripts:

1. Crea una carpeta privada de backups y una marca temporal; no reutilices un archivo de respaldo sin querer.
2. Detén NGINX y WordPress, dejando MariaDB funcionando para exportar.
3. Exporta la base de WordPress con autenticación mediante un archivo de opciones temporal protegido o un mecanismo de autenticación local ya configurado. No pongas la contraseña en la línea de comandos.
4. Guarda todos los archivos del volumen web, incluidos ocultos, preservando propietarios y permisos. Puedes usar un contenedor auxiliar efímero creado desde una imagen propia, con el volumen fuente solo lectura y salida del archivo tar por stdout; no necesita un servicio permanente adicional.
5. Verifica que ambos respaldos son completos y calcula sus sumas SHA-256.
6. Protege la copia: puede contener contraseñas, hashes, datos personales y claves de aplicación.
7. Vuelve a arrancar los servicios si sigues trabajando en casa.

En destino, crea los volúmenes y MariaDB con la misma configuración, mantén WordPress/NGINX parados, importa la base y restaura archivos en un volumen web preparado. Comprueba permisos y credenciales antes de arrancar WordPress. Una restauración sobrescribe datos: pruébala sobre una instalación nueva o después de otro respaldo.

Un dump de la base WordPress no incluye necesariamente las cuentas SQL del servidor; créalas mediante el bootstrap con secretos coherentes. No copies directamente `/var/lib/mysql` mientras MariaDB está escribiendo, ni mezcles archivos de datos binarios de versiones incompatibles.

Docker documenta la copia y restauración de volúmenes; adapta sus ejemplos para no descargar imágenes auxiliares prefabricadas prohibidas por tu enunciado. [Volúmenes Docker](https://docs.docker.com/engine/storage/volumes/).

### 21. Documentación obligatoria de la entrega

Esta guía personal no sustituye los tres documentos dentro de tu repositorio Inception.

#### README.md, en inglés

La primera línea debe ser exactamente la frase requerida, en cursiva y con tu login:

```markdown
*This project has been created as part of the 42 curriculum by tu_login.*
```

Incluye como mínimo estas secciones:

- **Description:** finalidad, arquitectura y resumen de servicios.
- **Project description:** cómo usas Docker, qué fuentes y archivos incluyes y por qué tomaste esas decisiones.
- **Instructions:** requisitos, preparación de variables/secretos, construcción y ejecución.
- **Resources:** enlaces oficiales y descripción honesta de qué tareas hiciste con IA y qué revisaste o probaste tú.

En Project description compara explícitamente:

| Comparación | Idea que debes explicar con tus palabras |
|---|---|
| Virtual Machines vs Docker | VM con kernel propio frente a procesos aislados que comparten el kernel; en este proyecto Docker vive dentro de la VM. |
| Secrets vs Environment Variables | Configuración ordinaria frente a archivos de acceso limitado para valores sensibles; las variables pueden quedar expuestas en inspecciones o logs. |
| Docker Network vs Host Network | Red propia con aislamiento y descubrimiento por nombre frente a compartir la red del host; el segundo modo está prohibido aquí. |
| Docker Volumes vs Bind Mounts | Almacenamiento gestionado por Docker frente a montar una ruta concreta del host; explica tu elección de volúmenes y `data-root`. |

No afirmes que los secrets de Compose local cifran mágicamente los archivos. No inventes pruebas que no has realizado.

#### USER_DOC.md

Escribe instrucciones para alguien que solo quiere utilizar o administrar el sitio:

- Servicios disponibles y para qué sirven.
- Cómo iniciar, parar y consultar el estado usando Makefile.
- URL del sitio y de `/wp-admin/`.
- Dónde se gestionan las credenciales, sin publicar sus valores.
- Cómo distinguir el propietario administrador del segundo usuario.
- Cómo comprobar salud y leer logs, y qué hacer si el sitio no responde.
- Qué operaciones conservan datos y cuáles los destruyen.

#### DEV_DOC.md

Explica cómo reconstruirlo sin tu ayuda:

- VM, arquitectura, versiones y dependencias.
- Estructura del repositorio y función de cada script.
- Instalación de Docker, `.env`, secretos y configuración del almacenamiento.
- Construcción, arranque, parada y reconstrucción.
- Inicialización idempotente: qué pasa la primera vez y qué pasa al reiniciar.
- Red, puertos, TLS, volúmenes y permisos.
- Copias, restauración y traslado entre equipos.
- Comandos de inspección y solución de problemas.

El texto proporcionado exige inglés para el README; no especifica el idioma de USER_DOC y DEV_DOC. Escribir los tres en inglés da coherencia y facilita su lectura por evaluadores; comprueba si tu rúbrica añade algo.

### 22. Problemas frecuentes

| Síntoma | Qué revisar primero |
|---|---|
| `permission denied` al usar Docker | Modalidad sudo o permisos de acceso al daemon. |
| Docker no arranca tras cambiar data-root | JSON válido, ruta, permisos y logs de `systemctl status docker`. |
| El dominio no resuelve | Archivo hosts del equipo del navegador, no solamente el de la VM. |
| Timeout | IP, topología de VM, publicación 443 y reglas de red. |
| Aviso de certificado | Confianza, SAN, nombre usado y fecha; no confundirlo con falta de TLS. |
| `502 Bad Gateway` | PHP-FPM parado, puerto equivocado o nombre `wordpress` no resoluble en la red. |
| `Primary script unknown` | NGINX y PHP-FPM no comparten ruta/archivos o SCRIPT_FILENAME es incorrecto. |
| Error de conexión a la base | MariaDB no lista, host incorrecto, permisos SQL o secretos incoherentes. |
| El sitio vuelve al instalador | Inicialización incompleta, base equivocada o volúmenes que no son los anteriores. |
| Cambiaste `.env` y no cambia nada | Recreación necesaria para variables del contenedor; los usuarios persistentes no se reconfiguran solos. |
| Se perdieron datos tras `down` | Revisa uso de `-v`, nombres/proyecto de Compose y scripts de limpieza. |
| Funciona en casa pero no en 42 | IP, arquitectura, permisos, secretos ausentes y archivos que no estaban en Git. |

### 23. Preguntas que deberías saber responder en la defensa

1. ¿Qué hace cada servicio y por qué no están juntos?
2. ¿Qué diferencia hay entre imagen, contenedor y VM?
3. ¿Qué proceso es PID 1 y cómo recibe la señal de parada?
4. ¿Por qué `exec` al final del entrypoint?
5. ¿Qué significa primer plano y por qué no usar `tail -f`?
6. ¿Cómo llega una petición HTTPS hasta PHP y después a MariaDB?
7. ¿Por qué `localhost` dentro de WordPress no apunta al contenedor MariaDB?
8. ¿Qué se conserva cuando eliminas un contenedor?
9. ¿Dónde están físicamente los dos volúmenes y cómo demuestras que no son bind mounts?
10. ¿Qué diferencia hay entre crear usuarios WordPress y usuarios SQL?
11. ¿Qué hace tu instalación si se ejecuta por segunda vez o se interrumpe a mitad?
12. ¿Por qué no guardas contraseñas en Dockerfiles o Git?
13. ¿Cómo verificas TLS y la publicación exclusiva del 443?
14. ¿Cómo reconstruirías todo en otro equipo y cómo recuperarías sus datos?

### 24. Orden de trabajo sugerido

El estado detallado y el punto de continuación están al principio de esta guía. Esta lista resume las fases completas; una fase iniciada sigue sin marcar hasta terminar sus comprobaciones.

- [ ] Entender arquitectura y confirmar condiciones del campus — por confirmar.
- [ ] Crear VM e instalar herramientas — por verificar en la VM.
- [ ] Resolver almacenamiento y configurar Docker — por verificar en la VM.
- [ ] Crear repositorio, exclusiones y variables — iniciado: repositorio y archivos creados; falta corregir Git y ordenar la plantilla.
- [ ] Construir y comprobar MariaDB — implementación escrita; construcción y pruebas pendientes de verificar.
- [ ] Añadir WordPress y PHP-FPM.
- [ ] Añadir NGINX, TLS y dominio.
- [ ] Completar Compose, Makefile y healthchecks — Compose de MariaDB ya escrito.
- [ ] Probar persistencia, fallos y arranques repetidos.
- [ ] Documentar lo que realmente funciona.
- [ ] Ensayar un traslado y una restauración.
- [ ] Repetir la evaluación completa en el entorno de 42.

No pases a la siguiente capa si no puedes explicar y comprobar la anterior. Haber conseguido una página en el navegador no demuestra todavía todos los requisitos.

## Referencias

El enunciado aportado por el usuario es la fuente de las restricciones de entrega. Las decisiones de rutas, nombres de variables, Makefile y orden de trabajo de esta guía son propuestas de implementación, no requisitos adicionales de 42.

- [Versiones oficiales de Debian](https://www.debian.org/releases/).
- [Instalación de Docker Engine en Debian](https://docs.docker.com/engine/install/debian/).
- [Configuración del daemon y data-root](https://docs.docker.com/engine/daemon/).
- [Volúmenes Docker](https://docs.docker.com/engine/storage/volumes/).
- [Docker Compose](https://docs.docker.com/compose/).
- [Secretos en Compose](https://docs.docker.com/compose/how-tos/use-secrets/).
- [Orden de arranque](https://docs.docker.com/compose/how-tos/startup-order/).
- [Referencia de Dockerfile](https://docs.docker.com/reference/dockerfile/).
- [TLS en NGINX](https://nginx.org/en/docs/http/ngx_http_ssl_module.html).
- [Configuración de PHP-FPM](https://www.php.net/manual/en/install.fpm.configuration.php).
- [WP-CLI: instalación de WordPress](https://developer.wordpress.org/cli/commands/core/install/).
- [WP-CLI: creación de usuarios](https://developer.wordpress.org/cli/commands/user/create/).
- [MariaDB: mariadb-dump](https://mariadb.com/docs/server/clients-and-utilities/backup-restore-and-import-clients/mariadb-dump).

Esta guía se ha preparado con ayuda de IA para interpretar el enunciado, ordenar el aprendizaje, consultar documentación y proponer procedimientos. No se ha creado ni ejecutado una infraestructura Inception como parte de su redacción; debes implementar, probar y comprender cada componente antes de declarar el proyecto terminado.
