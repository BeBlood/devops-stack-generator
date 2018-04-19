# Variables

ENVVARS=$(shell cat .env | grep -v ^\#)

php_sources         ?= .
phpcs_ignored_files ?= vendor/*,app/cache/*

mysql_container_name = $(shell docker-compose ps |grep '^[a-Z-]*-mysql' |sed 's/-mysql .*/-mysql/')

# Container
nginx_container_name = $(shell $(ENVVARS) && printf "$$NGINX_CONTAINER_NAME")
php_container_name = $(shell $(ENVVARS) && printf "$$PHP_CONTAINER_NAME")
mysql_container_name =  $(shell $(ENVVARS) && printf "$$MYSQL_CONTAINER_NAME")
node_container_name =  $(shell $(ENVVARS) && printf "$$NODE_CONTAINER_NAME")

# Proxy

reverse_proxy_container_name = $(shell $(ENVVARS) && printf "$$REVERSE_PROXY_CONTAINER_NAME")
reverse_proxy_container_id = $(shell docker ps -q -f name="$(reverse_proxy_container_name)")

network_name = $(shell $(ENVVARS) && printf "$$NETWORK_NAME")
network_id = $(shell docker network ls -q -f name="$(network_name)")
project_hosts= $(shell cat .env | grep -v ^\# | grep -oP "HOST=\K(.*+)" | tr "," " ")

default: pac

# Bash Commands
*: .env

.env: .env.dist
	cp .env.dist .env

.PHONY: command network
command:
	docker-compose run --rm php $(cmd)

.PHONY: bash network
bash:
	docker-compose exec php bash

# Mysql commands

.PHONY: mysql-export network
mysql-export:
	docker exec -i $(mysql_container_name) bash -c 'mysqldump -p$$MYSQL_PASSWORD -u$$MYSQL_USER $$MYSQL_DATABASE' > $(path)

.PHONY: mysql-import network
mysql-import:
	docker exec -i $(mysql_container_name) bash -c 'mysql -p$$MYSQL_PASSWORD -u$$MYSQL_USER $$MYSQL_DATABASE' < $(path)

# PHP commands

.PHONY: composer-add-github-token
composer-add-github-token: network
	docker-compose run --rm php composer config --global github-oauth.github.com $(token)

.PHONY: composer-update
composer-update: network
	docker-compose run --rm php composer update $(options)

.PHONY: composer-install
composer-install: network
	docker-compose run --rm php composer install $(options)

.PHONY: phploc
phploc:
	docker run -i -v `pwd`:/project jolicode/phaudit bash -c "phploc $(php_sources); exit $$?"

.PHONY: phpcs
phpcs:
	docker run -i -v `pwd`:/project jolicode/phaudit bash -c "phpcs $(php_sources) --extensions=php --ignore=$(phpcs_ignored_files) --standard=PSR2; exit $$?"

.PHONY: phpcpd
phpcpd:
	docker run -i -v `pwd`:/project jolicode/phaudit bash -c "phpcpd $(php_sources); exit $$?"

.PHONY: phpdcd
phpdcd:
	docker run -i -v `pwd`:/project jolicode/phaudit bash -c "phpdcd $(php_sources); exit $$?"


# Symfony2.x app commands

.PHONY: pac
pac: network
	docker-compose run --rm php php app/console $(cmd)

.PHONY: phpunit
phpunit: ./vendor/phpunit/phpunit/phpunit.php ./app/phpunit.xml.dist network
	docker-compose run --rm php php ./vendor/phpunit/phpunit/phpunit.php -c app/

# REVERSE PROXY

.PHONY: network
network:
	@if [ -z "$(network_id)" ]; then \
		docker network create $(network_name); \
	fi

.PHONY: start-reverse-proxy
start-reverse-proxy: network
	@if [ -z "$(reverse_proxy_container_id)" ]; then \
		printf "\nCreating and starting '$(reverse_proxy_container_name)'"; \
		docker run -d --rm \
			--name "$(reverse_proxy_container_name)" \
			--publish="80:80" \
			-v "/var/run/docker.sock:/tmp/docker.sock:ro" \
			-v "$(shell pwd)/.docker/nginx/build/proxy.conf:/etc/nginx/conf.d/proxy.conf:ro" \
			jwilder/nginx-proxy \
		; \
	fi

.PHONY: connect-reverse-proxy
connect-reverse-proxy: start-reverse-proxy
	@printf "\nAttaching '$(reverse_proxy_container_name)' to '$(network_name)'";
	docker network connect $(network_name) $(reverse_proxy_container_name) | exit 0

.PHONY: stop-reverse-proxy
stop-reverse-proxy: network
	@if [ -n "$(reverse_proxy_container_id)" ]; then \
		printf "\nStoping '$(reverse_proxy_container_name)'"; \
		docker stop "$(reverse_proxy_container_name)"; \
	fi

.PHONY: root
root:
	@if [ "root" != "$(shell whoami)" ]; then \
		printf "You have to be root"; \
		exit 1; \
	fi

.PHONY: install-hosts
install-hosts: root
	@if [ -z "$(shell grep "$(project_hosts)" /etc/hosts)" ]; then \
		printf "\nInstall hosts"; \
		printf "127.0.0.1\t$(project_hosts)" >> "/etc/hosts"; \
	fi

.PHONY: uninstall-hosts
uninstall-hosts: root
	@to_remove="$(shell grep -P "(\d+\.){3}(\d+)\t$(project_hosts)" "/etc/hosts")"; \
	if [ -n "$$to_remove" ]; then \
		printf "\nUninstall hosts"; \
		ex -s -c "g/$$to_remove/d" -c "wq" "/etc/hosts"; \
	fi

# PROJECT

.PHONY: install
install: composer-update network
	@printf "\nInstalling project";
	make pac cmd="assets:install"
	make pac cmd="theme:assets:install"

.PHONY: start
start: network connect-reverse-proxy
	@printf "\nStarting project";
	@docker-compose up -d

.PHONY: stop
stop: stop-reverse-proxy
	@printf "\nStoping project";
	@docker-compose stop;
	@docker network rm $(network_name)
