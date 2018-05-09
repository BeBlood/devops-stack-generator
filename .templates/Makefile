#############
# Variables #
#############
ENVVARS=$(shell cat .env | grep -v ^\#)

# Reverse proxy
reverse_proxy_container_name = $(shell $(ENVVARS) && echo "$$REVERSE_PROXY_CONTAINER_NAME")
reverse_proxy_container_id = $(shell docker ps -q -f name="$(reverse_proxy_container_name)")

# Network
network_name = $(shell $(ENVVARS) && echo "$$NETWORK_NAME")
network_id = $(shell docker network ls -q -f name="^$(network_name)$$")

# Hosts
project_hosts= $(shell cat .env | grep -v ^\# | grep -oP "HOST=\K(.*+)" | tr "," " ")

*: .env

# Bash Commands

.env:
	cp .env.dist .env

.PHONY: command
command:
	docker-compose run --rm $(target) $(cmd)

.PHONY: bash
bash:
	docker-compose exec '$(target)' bash

.PHONY: root
root:
	@if [ "root" != "$(shell whoami)" ]; then \
		echo "You have to be root !"; \
		exit 1; \
	fi

# NETWORK

.PHONY: network
network:
	@if [ -z "$(network_id)" ]; then \
		docker network create $(network_name); \
	fi

# PROXY

.PHONY: start-reverse-proxy
start-reverse-proxy: network
	if [ -z "$(reverse_proxy_container_id)" ]; then \
		printf "\nCreating and starting '$(reverse_proxy_container_name)'"; \
		docker run -d --rm \
			--name "$(reverse_proxy_container_name)" \
			--publish="80:80" \
			-v "/var/run/docker.sock:/tmp/docker.sock:ro" \
			-v "$(shell pwd)/.docker/proxy/proxy.conf:/etc/nginx/conf.d/proxy.conf:ro" \
			jwilder/nginx-proxy \
		; \
       	fi

.PHONY: attaching-reverse-proxy-network
attaching-reverse-proxy-network: start-reverse-proxy
	@printf "\nAttaching '$(reverse_proxy_container_name)' to '$(network_name)'";
	docker network connect $(network_name) $(reverse_proxy_container_name) | exit 0

.PHONY: stop-reverse-proxy
stop-reverse-proxy:
	@if [ -n "$(reverse_proxy_container_id)" ]; then \
		printf "\nStoping '$(reverse_proxy_container_name)'"; \
		docker stop "$(reverse_proxy_container_name)"; \
   	fi


.PHONY: install-hosts
install-hosts: root
	@if [ -z "$(shell grep "$(project_hosts)" /etc/hosts)" ]; then \
		echo "Install hosts"; \
		printf "127.0.0.1\t$(project_hosts)" >> "/etc/hosts"; \
	fi

.PHONY: uninstall-hosts
uninstall-hosts: root
	@to_remove="$(shell grep -P "(\d+\.){3}(\d+)\t$(project_hosts)" "/etc/hosts")"; \
	if [ -n "$$to_remove" ]; then \
		echo "Uninstall hosts"; \
		ex -s -c "g/$$to_remove/d" -c "wq" "/etc/hosts"; \
	fi

# PROJECT

.PHONY: install
install: network
	@printf "\nInstalling project ...\n"
	@docker-compose up -d
	@printf "\nProject installed !\n"

.PHONY: start
start: attaching-reverse-proxy-network network
	@printf "\nStarting project ...\n"
	@docker-compose up -d
	@printf "\nProject started !\n"

.PHONY: stop
stop: stop-reverse-proxy
	@printf "\nStoping project\n"
	@docker-compose stop
	@printf "\nProject stoped !\n"
