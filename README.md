*This project has been created as part of the 42 curriculum by cdaureo-.*

# Inception

## Description

Inception is a small WordPress infrastructure running inside a Linux
virtual machine. Docker Compose manages three services:

- NGINX provides HTTPS access through port 443 using TLS 1.2 and TLS 1.3.
- WordPress and PHP-FPM execute the website application.
- MariaDB stores the application database.

Each service has its own Dockerfile and container. Images are built
from debian:bookworm rather than prebuilt application images.

## Project description

### Architecture

Browser -> NGINX:443 -> WordPress/PHP-FPM:9000 -> MariaDB:3306

Only NGINX publishes a host port. The services communicate through
the inception Docker network.

Two named volumes provide persistent storage:

- database: MariaDB data, mounted at /var/lib/mysql.
- website: WordPress files, mounted at /var/www/html.
  NGINX mounts this volume read-only.

Docker's data-root is configured as:

/home/cdaureo-/data/docker

The VM's Linux username is cdaureo, while the learner login used
for the project data path is cdaureo-.

### Included files

- Makefile: builds and manages the infrastructure through Compose.
- srcs/docker-compose.yml: services, network, volumes and secrets.
- srcs/requirements/: Dockerfiles, configuration and entrypoint scripts.
- srcs/.env: local configuration, excluded from Git.
- secrets/: local password files, excluded from Git.
- USER_DOC.md: instructions for website users and administrators.
- DEV_DOC.md: environment setup and maintenance instructions.

### Design choices

MariaDB initializes its database and accounts on first startup.
WordPress checks whether its files, configuration and database
installation already exist before installing them.

The entrypoint scripts finish by executing the actual server
processes in the foreground.

MariaDB and PHP-FPM have healthchecks. Compose waits for these
checks when starting dependent services. Restart policies use
unless-stopped.

The TLS certificate is self-signed and generated locally at
NGINX startup when absent.

### Virtual Machines vs Docker

A virtual machine runs its own kernel and operating system.
Containers isolate processes while sharing the Docker host's kernel.
In this project, Docker runs inside the Linux VM.

### Secrets vs Environment Variables

Environment variables contain ordinary configuration, such as database
names and site settings. Passwords are supplied through Compose
secrets mounted as files under /run/secrets.

Local Compose secrets do not automatically encrypt their source files.
Those files require appropriate permissions and must stay outside Git.

### Docker Network vs Host Network

A dedicated Docker network provides communication and service-name
resolution between containers. Host networking shares the host's
network namespace and is not used in this project.

### Docker Volumes vs Bind Mounts

Named volumes are managed by Docker. Bind mounts expose specific
host paths directly inside containers.

The two persistent data stores use ordinary named volumes without
bind driver options. Their location follows the Docker data-root
configuration.

## Instructions

### Prerequisites

- A Linux virtual machine.
- Docker Engine and the Docker Compose plugin.
- Make.
- Local environment configuration and password files.
- Docker storage configured before creating the project volumes.

See DEV_DOC.md for the complete setup procedure.

### Local configuration

Configure srcs/.env and provide these local password files:

- secrets/db_root_password.txt
- secrets/db_password.txt
- secrets/wp_owner_password.txt
- secrets/wp_reader_password.txt

Do not publish credentials. For an existing installation, changing a
password file alone does not change the corresponding database account.

### Build and run

From the repository root:

    make config
    make
    make status

Other commands:

    make logs
    make stop
    make start
    make down
    make re

make down preserves the named volumes. Do not add the -v option
unless you explicitly intend to delete persistent data.

### Website access

The currently configured local URL is:

https://cdaureo-.42.fr

The administration panel is:

https://cdaureo-.42.fr/wp-admin/

Configure name resolution on the machine running the browser.
Inside the VM, the local hosts entry points to 127.0.0.1.

For access from the physical host, configure VM networking and
name resolution as described in DEV_DOC.md.

The current domain contains a label ending in a hyphen. It has been
tested locally, but the campus convention for this learner login
must be confirmed before submission.

A browser warning is expected for the self-signed certificate.

### Validation performed

- Website and login page return HTTP 200 over HTTPS.
- Administrator login works.
- WordPress accounts have administrator and subscriber roles.
- A published post and uploaded image survive down/up.
- The infrastructure starts automatically after a VM reboot.
- NGINX recovers after its main process is terminated unexpectedly.
- TLS 1.2 and 1.3 connections succeed.
- TLS 1.0 and 1.1 connections are rejected by the server.
- Both named volumes reside under /home/cdaureo-/data.

Backup restoration, reconstruction in a separate clean VM and
final Git history cleanup remain to be completed.

## Resources

- Docker documentation: https://docs.docker.com/
- Debian releases: https://www.debian.org/releases/
- NGINX HTTPS: https://nginx.org/en/docs/http/configuring_https_servers.html
- PHP-FPM: https://www.php.net/manual/en/install.fpm.configuration.php
- WP-CLI: https://developer.wordpress.org/cli/commands/
- MariaDB documentation: https://mariadb.com/docs/

### AI usage

AI assisted with interpreting requirements, explaining Docker concepts,
drafting configuration files and scripts, troubleshooting, proposing
validation commands and preparing documentation.

The learner executed the commands and checked the reported behavior
inside the VM. AI-generated instructions required corrections during
testing, including storage-path interpretation and password updates.
The learner must understand and be able to explain the submitted files.
