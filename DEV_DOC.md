# Developer documentation

## Environment

The project runs inside a Linux virtual machine.

Current development environment:

- Physical host: Windows.
- Hypervisor: VirtualBox.
- Guest: Debian 13, linux/amd64.
- Docker Engine: 29.9.2.
- Docker Compose: v5.7.0.
- Container base: debian:bookworm.
- PHP: 8.2.
- WordPress: 7.1.4.

Expected destination:

- Physical host: Ubuntu 22.04.
- Docker and the project still run inside a Linux VM.
- Confirm the available hypervisor, CPU architecture, storage and
  permissions before transferring the project.

The Debian username is cdaureo.
The learner login is cdaureo-.

## Prerequisites

Install Git, Make, curl, OpenSSL and CA certificates inside the VM:

```bash
sudo apt update
sudo apt install git make curl openssl ca-certificates
```

Install Docker Engine and the Compose plugin using Docker's official
Debian installation instructions:

https://docs.docker.com/engine/install/debian/

Enable Docker and inspect the installed versions:

```bash
sudo systemctl enable --now docker
sudo docker version
sudo docker compose version
```

The Makefile uses sudo docker. Administrative access is required.

##Shared Folder
Enter has root 
if there's no mount do : ```sudo mount -t vboxsf "Name of PC folder" "path to the VM"```

## Repository structure

```text
Inception/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore
├── secrets/
└── srcs/
    ├── .env
    ├── docker-compose.yml
    ├── tools/setup.sh
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/50-server.cnf
        │   └── tools/entrypoint.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── conf/www.conf
        │   └── tools/entrypoint.sh
        └── nginx/
            ├── Dockerfile
            ├── conf/default.conf.template
            └── tools/entrypoint.sh
```

The .env file and secrets directory are local configuration.
They must not be tracked by Git.

## Docker storage

Both persistent named volumes must store their data under:

```text
/home/cdaureo-/data
```

The daemon uses this configuration in /etc/docker/daemon.json:

```json
{
  "data-root": "/home/cdaureo-/data/docker"
}
```

Configure this before creating project data on a fresh, dedicated VM.

If daemon.json already exists, preserve its other settings and merge
the data-root option into the existing JSON.

Changing data-root does not migrate existing data. On a populated VM,
stop and prepare a backup and migration plan before changing it.

Verify the active location:

```bash
sudo docker info --format '{{.DockerRootDir}}'
```

The named volumes are:

- inception_database
- inception_website

Delete volumes:

```bash
sudo docker volume rm inception_database inception_website
```
Inspect their actual locations and options:

```bash
sudo docker volume inspect inception_database inception_website \
--format '{{.Name}} | {{.Mountpoint}} | {{json .Options}}'
```

Expected locations:

```text
/home/cdaureo-/data/docker/volumes/inception_database/_data
/home/cdaureo-/data/docker/volumes/inception_website/_data
```

Their driver options should be null, without bind mount options.

Do not assume data-root relocates containerd's separate image store.

Do not change volume ownership using account names shown by the host.
Container numeric user IDs can map to unrelated names in Debian.

## Local environment configuration

Create srcs/.env with the following settings, adapting account names
and email addresses as needed:

```dotenv
DOMAIN_NAME=cdaureo-.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_app
WP_VERSION=7.1.4
WP_TITLE="Inception de cdaureo-"
WP_OWNER_USER=cdaureo-
WP_OWNER_EMAIL=cdaureo-owner@student.42madrid.com
WP_READER_USER=lector
WP_READER_EMAIL=cdaureo-lector@student.42madrid.com
```

The owner username must not contain admin, ignoring case.
The two WordPress usernames must be different.

The domain above has been tested locally. Its first label ends
in a hyphen, which conflicts with standard hostname syntax.
Confirm the campus convention for this learner login before delivery.
The storage path must still retain the learner login.

Do not source .env as a shell script. Compose reads it using --env-file.

## Secrets

For a new installation only, create four different passwords:

```bash
(
    set -eu
    umask 077
    mkdir -p secrets
    chmod 700 secrets

    for name in db_root_password db_password wp_owner_password wp_reader_password; do
        test ! -e "secrets/$name.txt"
    done

    for name in db_root_password db_password wp_owner_password wp_reader_password; do
        openssl rand -hex 24 > "secrets/$name.txt"
    done
)
```

Do not run this to rotate passwords on an initialized installation.

Compose mounts the required secrets as files:

```text
/run/secrets/db_root_password
/run/secrets/db_password
/run/secrets/wp_owner_password
/run/secrets/wp_reader_password
```

MariaDB receives its two database secrets.
WordPress receives the SQL application secret and both WordPress
account secrets. NGINX receives no account passwords.

Local Compose secrets do not encrypt the source files.

### Git exclusions

The repository ignores:

```gitignore
srcs/.env
secrets/
backups/
*.sql
*.sql.gz
*.key
*.pem
```

Check exclusions and tracked files before committing:

```bash
git check-ignore srcs/.env secrets/db_password.txt
git ls-files srcs/.env secrets
git status --short
```

The git ls-files command must not list sensitive files.

Ignoring a file does not remove previous commits containing it.
Previously exposed credentials have been rotated during development;
The published history has been rewritten to remove secrets/ and srcs/.env
from reachable commits. Use a fresh clone after this rewrite; do not merge
old local history back into the repository. Previously exposed credentials
must remain revoked. GitHub may retain cached objects or external copies;
contact GitHub Support if sensitive old objects remain accessible.

## Build and lifecycle commands

Run these commands from the repository root:

```bash
make config
make
make status
make logs
```

Other targets:

```bash
make build
make stop
make start
make down
make re
```

make invokes Compose with:

```text
sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml
```

make down preserves named volumes.
make re removes containers and the network, then rebuilds and starts.

Neither target deletes persistent data.

The healthchecks test MariaDB responsiveness and the PHP-FPM TCP
listener. Dependencies use service_healthy during Compose startup.

The restart policy is unless-stopped. Docker is enabled at VM startup.

An unhealthy status alone does not cause Docker to restart a container.
Restart policies respond to process termination.

## Initialization behavior

### MariaDB

The entrypoint:

1. Validates required variables.
2. Prepares directories and ownership.
3. Initializes system tables when absent.
4. Executes initial SQL synchronously with mariadbd --bootstrap,
   without opening a network listener or starting a background process.
5. Creates the WordPress database and SQL application account.
6. Grants permissions on that database.
7. Configures the local root password.
8. Waits for the bootstrap command to complete successfully.
9. Writes /var/lib/mysql/.inception-ready.
10. Executes mariadbd as the final foreground process.

On later starts, the marker prevents repeating account initialization.

Changing a secret does not automatically update existing SQL accounts.
If initialization is interrupted, inspect logs and persisted state
before retrying. Do not blindly delete the volume or readiness marker.

### WordPress

The entrypoint:

1. Validates variables, usernames and secret files.
2. Prepares the website directory and WP-CLI cache.
3. Waits for MariaDB using bounded connection attempts.
4. Downloads the configured WordPress version when files are absent.
5. Creates wp-config.php when absent.
6. Installs the site when the database is not already installed.
7. Creates the subscriber account when absent.
8. Executes PHP-FPM in the foreground.

WP-CLI runs as www-data.

Existing installations and users are preserved on restart.
Changing environment variables does not automatically rename existing
accounts or change stored site URLs.

Changing WP_VERSION does not upgrade an existing installation.
Plan and test upgrades separately.

The password in wp-config.php must agree with the SQL account and
the database password secret.

### NGINX

The entrypoint:

1. Checks DOMAIN_NAME.
2. Generates a self-signed certificate and key when absent.
3. Substitutes only DOMAIN_NAME into the configuration template.
4. Runs nginx -t.
5. Executes NGINX with daemon off.

NGINX variables such as $uri must not be substituted by envsubst.

Certificate files are stored in the container's writable layer.
They can change when the NGINX container is recreated.

## Network and access

Services communicate over the inception Compose network.

Compose service names provide internal discovery:

- mariadb:3306
- wordpress:9000

Only NGINX publishes a host port:

```text
443:443
```

Do not publish 3306 or 9000.

WordPress and NGINX share the website volume at /var/www/html.
NGINX mounts it read-only.

NGINX forwards PHP requests using FastCGI and enables only
TLS 1.2 and TLS 1.3.

### Browser inside the VM

Add the following entry to the VM's /etc/hosts:

```text
127.0.0.1 cdaureo-.42.fr
```

Test name resolution and HTTPS:

```bash
getent hosts cdaureo-.42.fr
curl --noproxy '*' -kI https://cdaureo-.42.fr/
```

### Browser on the physical host

For VirtualBox NAT, configure TCP forwarding from host port 443
to guest port 443.

Example for the current VM:

```text
Host IP:    127.0.0.1
Host port:  443
Guest IP:   10.0.2.15
Guest port: 443
```

With that rule, map the domain to 127.0.0.1 on the physical host.

Hosts file locations:

- Windows: C:\Windows\System32\drivers\etc\hosts
- Ubuntu: /etc/hosts

The forwarding setup from Windows has not yet been validated.
Access inside the Debian VM has been validated.

For bridged or host-only networking, map the domain to the VM's
reachable address instead. Confirm addresses again after transfer.

## Credential maintenance

Changing password files alone does not change persistent accounts.

### WordPress accounts

Update the account and then its corresponding secret file.
Recreate WordPress after replacing secret files so mounted files
are refreshed.

Use --quiet with WP-CLI password operations. Earlier development
commands using --prompt printed complete commands containing passwords.

The installed WP-CLI version did not accept --prompt=value as a
replacement for the positional value required by wp config set.

The preparation script is srcs/tools/setup.sh. make config and make
automatically call this script through the setup prerequisite. Existing
configuration is preserved; missing secrets with existing project volumes
are treated as an error rather than silently regenerated.

Do not enable shell tracing or paste password-bearing output.

### SQL application account

During a coordinated maintenance window:

1. Stop NGINX.
2. Preserve the current secret privately.
3. Generate a new hexadecimal password in a separate private file.
4. Update wp_app@% using MariaDB administrative access.
5. Update DB_PASSWORD in the website volume's wp-config.php.
6. Update the local database secret.
7. Recreate MariaDB and WordPress to refresh secret mounts.
8. Verify SQL authentication and wp core is-installed.
9. Start NGINX and test the website.

If WordPress is restarting, use a temporary container with its
entrypoint overridden to repair wp-config.php on the shared volume.

Do not regenerate another password midway through a failed rotation.
First identify which account, file and configuration are current.

### MariaDB root account

Root has local socket authentication as well as password access.

SET PASSWORD was used to rotate its password while retaining
the socket authentication method.

To verify password authentication, the test ran the client as
the operating-system mysql user rather than operating-system root.

The root SQL account is not intended for remote application access.

## Backup procedure

Back up both the database and website files.
The website archive includes wp-config.php and is sensitive.

The following procedure is a maintenance recipe to test before relying
on it. A complete backup/restore rehearsal has not yet been performed.

From the repository root, run in Bash:

```bash
(
    set -eu
    umask 077

    dc() {
        sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml "$@"
    }

    backup_dir="backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"

    dc stop nginx wordpress

    dc exec -T mariadb sh -c \
        'exec mariadb-dump --protocol=SOCKET -u root --single-transaction --databases "$MYSQL_DATABASE"' \
        > "$backup_dir/database.sql"

    dc run -T --rm --no-deps --entrypoint tar wordpress \
        -C /var/www/html -czf - . \
        > "$backup_dir/website.tar.gz"

    cp srcs/.env "$backup_dir/environment.env"
    mkdir "$backup_dir/secrets"
    cp secrets/db_root_password.txt secrets/db_password.txt \
       secrets/wp_owner_password.txt secrets/wp_reader_password.txt \
       "$backup_dir/secrets/"

    test -s "$backup_dir/database.sql"
    test -s "$backup_dir/website.tar.gz"
    tar -tzf "$backup_dir/website.tar.gz" >/dev/null

    (
        cd "$backup_dir"
        sha256sum database.sql website.tar.gz environment.env secrets/*.txt \
            > SHA256SUMS
    )

    dc start wordpress
    dc start nginx

    printf 'Backup directory: %s\n' "$backup_dir"
)
```

If a command fails, the procedure stops. Investigate before restarting
services or treating the backup as valid.

Store a copy outside the VM using a private, protected transfer.
File presence and checksums do not prove that restoration works.

## Restore and transfer

Prefer reconstruction from the repository in a compatible VM.

For a faithful restore:

1. Prepare the destination VM, Docker and storage configuration.
2. Clone the repository.
3. Transfer the backup privately.
4. Verify SHA256SUMS from the backup directory.
5. Restore environment.env as srcs/.env and the four active secrets
   into secrets/, with directory mode 700 and file mode 600.
6. Validate Compose and build the images.
7. Start only MariaDB and wait until healthy.
8. Restore the SQL dump.
9. Restore the website archive.
10. Start WordPress, then NGINX.
11. Adapt name resolution and VM networking.
12. Repeat functional, persistence and TLS tests.

Restore only into a new destination installation with no valuable data,
or after a separate verified backup. Import and extraction can overwrite
existing data.

Example commands after preparing the destination configuration:

```bash
make config
make build

sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml up -d mariadb
```

Wait for MariaDB to become healthy before importing.

Set the actual backup directory:

```bash
backup_dir="backups/REPLACE_WITH_BACKUP_DIRECTORY"
```

Import the database:

```bash
sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec -T mariadb \
    mariadb --protocol=SOCKET -u root \
    < "$backup_dir/database.sql"
```

Restore website files, preserving archive ownership and permissions:

```bash
sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml run -T \
    --rm --no-deps --entrypoint tar wordpress \
    -C /var/www/html -xzf - \
    < "$backup_dir/website.tar.gz"
```

Start the application:

```bash
sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml up -d wordpress nginx
```

Restoring the original secrets keeps the SQL account, wp-config.php
and stored user credentials coherent.

Do not copy a live MariaDB data directory as a substitute for a
consistent backup.

If exporting the entire VM instead, shut down Debian cleanly first
and confirm hypervisor and architecture compatibility.

## Inspection and troubleshooting

Service status:

```bash
make status
```

Recent service logs:

```bash
sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs --tail=80 wordpress
```

NGINX configuration:

```bash
sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec nginx nginx -t
```

Processes:

```bash
sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml top
```

WordPress installation and accounts:

```bash
sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec \
    --user www-data wordpress wp core is-installed

sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml exec \
    --user www-data wordpress wp user list --fields=ID,user_login,roles
```

After recreating WordPress independently, restart NGINX if its cached
upstream address no longer reaches the service.

Do not use down -v, volume removal or storage deletion as routine fixes.

## Validation record

The following behavior was checked during development:

- HTTP 200 for the website and login page over HTTPS.
- Administrator login after password rotation.
- Administrator and subscriber account roles.
- Database data surviving container recreation.
- Published post and uploaded image surviving down/up.
- Correct named volume locations without bind driver options.
- Actual server processes running in the containers.
- Automatic service startup after a VM reboot.
- NGINX running with RestartCount=1 after the failure test and
  the website returning HTTP 200 afterward.
- Successful TLS 1.2 and TLS 1.3 negotiation.
- Server protocol-version alerts rejecting TLS 1.0 and TLS 1.1.
- MariaDB and PHP-FPM healthchecks reaching healthy status.

Remaining validation includes:

- A complete backup/restore rehearsal.
- Reconstruction in a separate clean VM.
- Transfer to the environment hosted on Ubuntu 22.04.
- Final review of Git history and repository contents.
- Final campus confirmation of the domain naming convention.

Additional regression checks were run in isolated Docker containers on
Ubuntu/WSL using separate volumes and generated test secrets:

- Fresh MariaDB bootstrap completes without a background server.
- SQL application and root password authentication succeed.
- Fresh WordPress installation creates both accounts with passwords
  matching the generated secrets.
- Captured initialization logs do not contain generated passwords.
- Recreating the containers preserves SQL data and the WordPress site
  without repeating MariaDB bootstrap.

These checks do not replace validation in the destination VM.

## Fresh installation from Git

This creates a new website. Existing posts and uploads are not restored.

1. Create the Linux VM.
2. Install Docker Engine, the Compose plugin, Git, Make and OpenSSL.
3. Configure Docker storage under /home/cdaureo-/data/docker
   before creating project volumes.
4. Clone the repository:

       git clone https://github.com/CDaureo/Inception.git
       cd Inception

5. Prepare local configuration:

       make setup

6. Review srcs/.env and configure name resolution.
7. Build and start:

       make
       make status

8. Read the locally generated administrator password when needed:

       cat secrets/wp_owner_password.txt

Never commit the generated .env or secrets directory.

## References

- https://docs.docker.com/engine/install/debian/
- https://docs.docker.com/engine/daemon/
- https://docs.docker.com/compose/
- https://docs.docker.com/engine/containers/start-containers-automatically/
- https://nginx.org/en/docs/http/configuring_https_servers.html
- https://www.php.net/manual/en/install.fpm.configuration.php
- https://developer.wordpress.org/cli/commands/
- https://mariadb.com/docs/
