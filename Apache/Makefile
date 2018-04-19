ENVVARS=$(shell cat .env | grep -v ^\#)

reverse_proxy_container_name = $(shell $(ENVVARS) && echo "$$REVERSE_PROXY_CONTAINER_NAME")
reverse_proxy_container_id = $(shell docker ps -q -f name="$(reverse_proxy_container_name)")
network_name = $(shell $(ENVVARS) && echo "$$NETWORK_NAME")
network_id = $(shell docker network ls -q -f name="$(network_name)")
project_hosts= $(shell cat .env | grep -v ^\# | grep -oP "HOST=\K(.*+)" | tr "," " ")

# REVERSE PROXY

.PHONY: network
network:
	@if [ -z "$(network_id)" ]; then \
		docker network create $(network_name); \
	fi

.PHONY: start-reverse-proxy
start-reverse-proxy: network
	@if [ -z "$(reverse_proxy_container_id)" ]; then \
		echo "\nCreating and starting '$(reverse_proxy_container_name)'"; \
		docker run -d --rm \
			--name "$(reverse_proxy_container_name)" \
			--publish="80:80" \
			-v "/var/run/docker.sock:/tmp/docker.sock:ro" \
			jwilder/nginx-proxy \
		; \
	fi

.PHONY: connect-reverse-proxy
connect-reverse-proxy: start-reverse-proxy
	@echo  "\nAttaching '$(reverse_proxy_container_name)' to '$(network_name)'";
	@docker network connect $(network_name) $(reverse_proxy_container_name) | exit 0

.PHONY: stop-reverse-proxy
stop-reverse-proxy:
	@if [ -n "$(reverse_proxy_container_id)" ]; then \
		echo -"\nStoping '$(reverse_proxy_container_name)'"; \
		docker stop "$(reverse_proxy_container_name)"; \
	fi

.PHONY: root
root:
	@if [ "root" != "$(shell whoami)" ]; then \
		echo "You have to be root"; \
		exit 1; \
	fi

.PHONY: install-hosts
install-hosts: root
	@if [ -z "$(shell grep "$(project_hosts)" /etc/hosts)" ]; then \
		echo "Install hosts"; \
		echo "127.0.0.1\t$(project_hosts)" >> "/etc/hosts"; \
	fi

.PHONY: uninstall-hosts
uninstall-hosts: root
	@to_remove="$(shell grep -P "(\d+\.){3}(\d+)\t$(project_hosts)" "/etc/hosts")"; \
	if [ -n "$$to_remove" ]; then \
		echo "Uninstall hosts"; \
		ex -s -c "g/$$to_remove/d" -c "wq" "/etc/hosts"; \
	fi

# MYSQL

.PHONY: mysql_import
mysql_import:
	$(ENVVARS) && docker exec -i "$${MYSQL_CONTAINER_NAME}" mysql -u"$${MYSQL_USER}" -p"$${MYSQL_PASSWORD}" "$${MYSQL_DATABASE}" < "$${MYSQL_DUMP_DIR}$${MYSQL_DUMP_FILENAME}"

.PHONY: mysql_export
mysql_export:
	$(ENVVARS) && docker exec -i "$${MYSQL_CONTAINER_NAME}" mysqldump -u"$${MYSQL_USER}" -p"$${MYSQL_PASSWORD}" "$${MYSQL_DATABASE}" > "$${MYSQL_DUMP_DIR}`date +%Y%m%d`-$${MYSQL_DUMP_FILENAME}"

# PHP command
.PHONY: composer-update
composer-update: network
	docker-compose run --rm php composer update

.PHONY: composer-install
composer-install: network
	docker-compose run --rm php composer install

.PHONY: composer-require
composer-require: network
	docker-compose run --rm php composer require $(package)

.PHONY: composer-autoload
composer-autoload: network
	docker-compose run --rm php composer dump-autoload


# PROJECT

.PHONY: install
install: composer-update network
	@echo "\nInstalling project"

.PHONY: start
start: network connect-reverse-proxy
	@echo "\nStarting project";
	@docker-compose up -d

.PHONY: stop
stop: stop-reverse-proxy
	@echo "\nStoping project";
	@docker-compose stop;
	@docker network rm $(network_name)
