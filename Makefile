COMPOSE = sudo docker compose --env-file srcs/.env -f srcs/docker-compose.yml

all: up

config:
	$(COMPOSE) config --quiet

build: config
	$(COMPOSE) build

up: config
	$(COMPOSE) up -d --build

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

down:
	$(COMPOSE) down
setup:
	sh tools/setup.sh
status:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs --tail=100

re: down
	$(MAKE) up

.PHONY: all config build up stop start down status logs re setup

