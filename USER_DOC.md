# User documentation

## Available services

The infrastructure provides a WordPress website through three services:

- NGINX receives HTTPS requests on port 443.
- WordPress and PHP-FPM manage and execute the website.
- MariaDB stores accounts, posts and application settings.

Only NGINX is directly accessible from the browser.

## Start and stop the project

Run commands inside the Linux VM, from the repository root:

    cd ~/Inception

Build and start the infrastructure:

    make

Check its status:

    make status

Stop services without removing their containers:

    make stop

Start previously stopped containers:

    make start

Remove the containers and network while preserving website data:

    make down

Rebuild and recreate the infrastructure:

    make re

Docker commands may request the Linux user's sudo password.
This is separate from the WordPress passwords.

## Access the website

Website:

https://cdaureo-.42.fr

Administration panel:

https://cdaureo-.42.fr/wp-admin/

Keep the VM running while using the website.

Inside the VM, /etc/hosts contains:

    127.0.0.1 cdaureo-.42.fr

When browsing from the physical host, configure its hosts file
and the VM network separately. See DEV_DOC.md.

The certificate is self-signed. A certificate warning is expected.
Verify that you are accessing your own local VM before accepting
an exception.

The configured name has been tested locally. Because its first
label ends in a hyphen, confirm the campus naming convention
before submission.

## Accounts and credentials

Two WordPress accounts are configured:

| Account | Role | Purpose |
|---|---|---|
| cdaureo- | Administrator | Manage the website, content and users |
| lector | Subscriber | Access the site as a registered user |

The administrator username does not contain "admin".

Passwords are stored locally in the repository's secrets directory:

| File | Purpose |
|---|---|
| wp_owner_password.txt | WordPress administrator password |
| wp_reader_password.txt | WordPress subscriber password |
| db_password.txt | WordPress database connection password |
| db_root_password.txt | MariaDB administrative password |

The database accounts are separate from the WordPress accounts.

Read a password only on your own terminal when needed. For example:

    cat secrets/wp_owner_password.txt

Do not share terminal output containing passwords or commit these
files to Git.

The srcs/.env file stores site configuration and account names.
It is also excluded from Git.

### Changing passwords

Changing a secret file alone does not update an existing account.

A WordPress password change must update both the WordPress account
and its corresponding local secret file.

Changing the SQL application password requires updating all three:

- The MariaDB account.
- The local database password file.
- WordPress's wp-config.php database connection.

Credential changes should be performed as a coordinated maintenance
operation. Ask the project maintainer if you are unsure.

## Use the administration panel

1. Open /wp-admin/.
2. Sign in as cdaureo- using the owner password.
3. Use Posts to create and publish content.
4. Use Media to upload images.
5. Use Users to inspect accounts and roles.
6. Log out when finished, especially on a shared computer.

The subscriber account does not have administrative permissions.

## Check service availability

Run:

    make status

Expected results:

- mariadb is Up and healthy.
- wordpress is Up and healthy.
- nginx is Up and publishes port 443.

Healthchecks verify database responsiveness and the PHP-FPM listener.
They do not replace checking the website in a browser.

From inside the VM, check HTTPS:

    curl --noproxy '*' -kI https://cdaureo-.42.fr/

The expected response is HTTP 200.

The -k option skips certificate trust verification for this
self-signed local installation. It does not establish that the
certificate is trusted.

## Read logs

Show recent logs from all services:

    make logs

Inspect a specific service:

    sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml logs --tail=80 nginx

Replace nginx with wordpress or mariadb when appropriate.

Do not publish logs without checking for sensitive information.
Earlier project versions printed credentials during initialization.

## If the website does not respond

### Server not found

Check the hosts entry on the machine running the browser.
A hosts entry in Windows does not configure Debian, and vice versa.

### Connection refused or timeout

Check that the VM is running, NGINX is Up, and the VM network
permits access to port 443.

For host access through VirtualBox NAT, check the forwarding rule.

### Certificate warning

The project uses a self-signed certificate. Confirm the address
and inspect the certificate. An unexpected name or certificate
should be investigated.

### 502 Bad Gateway

Check WordPress status and logs. PHP-FPM may be unavailable.

If WordPress was recreated while NGINX stayed running, restarting
NGINX refreshes its upstream name resolution:

    sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml restart nginx

### Database connection error

Check MariaDB status and logs. Verify that the SQL account password,
the mounted secret and wp-config.php agree.

Do not regenerate secrets blindly: existing database accounts retain
their passwords until explicitly changed.

### Login fails

Use the WordPress password for the intended account, not the Linux
or MariaDB password. Do not reinstall the site to reset a login.

## Data preservation and destructive operations

These normal operations preserve named volumes:

- make stop
- make start
- make down
- make re
- VM reboot

Persistent storage contains both:

- The database: accounts, posts and settings.
- Website files: WordPress files, uploads and media.

Deleting either volume can lose part of the site.

Commands such as docker compose down -v, docker volume rm, and
manual deletion of Docker storage are destructive. Do not use them
as routine troubleshooting steps.

Do not delete or change /home/cdaureo-/data/docker while Docker
is using it.

A volume and a VM snapshot are not independent backups.
Before destructive maintenance or transfer, obtain a verified
backup of both the database and website files.

## Shutdown and automatic startup

Containers use the unless-stopped restart policy.

Services that were running are configured to start again when
Docker starts after a VM reboot.

If you deliberately stopped the services with make stop, use
make start to start them again.

After make down, use make to recreate them.

Always shut down Debian normally before closing or exporting
the VM.
