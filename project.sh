#!/bin/bash
STACK_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export $(cat "$STACK_PATH/.env" | grep -v ^\#)
PROJECTS_REPOSITORY_PATH=${PROJECTS_REPOSITORY_PATH/'$HOME'/$HOME}
TEMPLATES_PATH="$STACK_PATH/.templates"
RESOURCES_PATH="$STACK_PATH/.resources"
DEFAULT_PROJECT_SOURCE_DIR=$(cat "$TEMPLATES_PATH/.env" | grep -oP "PROJECT_SOURCE_DIR=\K(.*)")
HEIGHT=15
WIDTH=40
TITLE="Création du projet"
declare -A PROJECT

# Read user input text
function read()
{
  SUBTITLE=$1
  INPUT=$(dialog --title "$TITLE" \
          --clear \
          --inputbox "$SUBTITLE" \
          $HEIGHT $WIDTH \
          2>&1 >/dev/tty)

  echo $INPUT
} # read

# Ask user for an action
function ask()
{
  SUBTITLE=$1
  $(dialog --title "$TITLE" \
            --stdout \
            --yesno "$SUBTITLE" \
            $HEIGHT $WIDTH \
            2>&1 >/dev/null)
  echo $?
} # ask

# Read single user choice
function get_choice()
{
  OPTIONS=$1
  SUBTITLE=$2
  NUMBER=$((${#OPTIONS[*]} / 2))

  CHOICE=$(dialog --title "$TITLE" \
		        --menu "$SUBTITLE" \
		        $HEIGHT $WIDTH $NUMBER \
		        "${OPTIONS[@]}" \
		        2>&1 >/dev/tty)
  echo $CHOICE
} # get_choice

# Read multiple user choices
function get_choices()
{
  OPTIONS=$1
  SUBTITLE=$2
  NUMBER=$((${#OPTIONS[*]} / 3))

  CHOICES=$(dialog --title "$TITLE" \
      --separate-output \
      --checklist "$SUBTITLE"\
      $HEIGHT $WIDTH $NUMBER \
      "${OPTIONS[@]}" \
      2>&1 >/dev/tty)
  echo $CHOICES
} # get_choices

########################
#  FILE MANIPULATIONS  #
########################

# Update variables in .env.dist file
function update_env()
{
  VAR_NAME=$1

  sed -i "s/^$VAR_NAME=.*/$VAR_NAME=${PROJECT[$VAR_NAME]}/" '.env.dist'
} # update_env

# Add a volume in docker-compose file
function add_volume_docker_compose()
{
  VOLUME_NAME=$1

  sed -i "/^volumes:/a\\  $VOLUME_NAME:" 'docker-compose.yml'
} # add_volume_docker_compose

# Add container with his configuration in project from .templates dir
function add_template()
{
  TEMPLATE_NAME=$1

  # docker-compose.yml template
  DC_TEMPLATE_PATH="$TEMPLATES_PATH/$TEMPLATE_NAME/docker-compose.yml"
  if [ -f $DC_TEMPLATE_PATH ]; then
    DOCKER_COMPOSE_CONFIGURATION=$(cat "$DC_TEMPLATE_PATH")
    APPEND_BEFORE_LINE=$(grep -n "^volumes:" 'docker-compose.yml' | cut -d : -f 1)
    OUTPUT="$(awk -v "s=$DOCKER_COMPOSE_CONFIGURATION\n" -v "l=$APPEND_BEFORE_LINE" 'NR==l{print s} 1' 'docker-compose.yml')"
    echo "$OUTPUT" > 'docker-compose.yml'
  fi

  # .env template
  ENV_TEMPLATE_PATH="$TEMPLATES_PATH/$TEMPLATE_NAME/.env"
  if [ -f $ENV_TEMPLATE_PATH ]; then
    ENV_CONFIGURATION=$(cat "$ENV_TEMPLATE_PATH")
    printf "\n\n$ENV_CONFIGURATION" >> '.env.dist'
  fi

  # .env template
  MAKEFILE_TEMPLATE_PATH="$TEMPLATES_PATH/$TEMPLATE_NAME/Makefile"
  if [ -f $MAKEFILE_TEMPLATE_PATH ]; then
    MAKEFILE_COMMANDS=$(cat "$MAKEFILE_TEMPLATE_PATH")
    printf "\n\n$MAKEFILE_COMMANDS" >> 'Makefile'
  fi

  # conf template
  ENV_TEMPLATE_PATH="$TEMPLATES_PATH/$TEMPLATE_NAME/conf"
  if [ -d $ENV_TEMPLATE_PATH ]; then
    cp -r "$ENV_TEMPLATE_PATH" "${PROJECT["PATH"]}/.docker/$TEMPLATE_NAME/"
  fi
}

# Add a new depend for specific container
function add_depend()
{
  DEPEND=$(echo $1 | tr '[:lower:]' '[:upper:]')

  sed -i "s/#"$DEPEND"_DEPEND//" 'docker-compose.yml'
}

# Build all the depends in docker-compose file
function build_depends()
{
  DEPENDS=($(sed -E 's/(^  (\S+):)|.*/\2/' 'docker-compose.yml'))

  for DEPEND in ${DEPENDS[@]}
  do
    add_depend $DEPEND
  done
} # build_depends

# Get available versions for a container
function get_available_versions()
{
  CONTAINER=$1

  if [ -f "$TEMPLATES_PATH/$CONTAINER/.versions" ]; then
    VERSIONS=($(cat "$TEMPLATES_PATH/$CONTAINER/.versions" | grep . | cat -n -))
  else
    VERSIONS=($(ls "$TEMPLATES_PATH/$CONTAINER/conf" | grep Dockerfile- | sed "s/Dockerfile-//" | cat -n -))
  fi

  echo ${VERSIONS[@]}
} # get_available_versions

function build_homepage()
{
    mkdir "$DEFAULT_PROJECT_SOURCE_DIR"
    mkdir "$DEFAULT_PROJECT_SOURCE_DIR/public"
    mkdir "$DEFAULT_PROJECT_SOURCE_DIR/public/img"

    if [ "${PROJECT["SERVER"]}" = "nginx" ]; then
        file_extension="php"
    else
        file_extension="html"
    fi

    cp "$RESOURCES_PATH/public/index.html" "$DEFAULT_PROJECT_SOURCE_DIR/public/index.$file_extension"
    sed -i "s/"'$SERVER_NAME'"/${PROJECT["SERVER"]}/" "$DEFAULT_PROJECT_SOURCE_DIR/public/index.$file_extension"
    cp "$RESOURCES_PATH/public/img/${PROJECT["SERVER"]}.png" "$DEFAULT_PROJECT_SOURCE_DIR/public/img/logo.png"
}

##################
#   CONTAINERS   #
##################

# Build apache configuration
function build_apache()
{
    OPTIONS=($(get_available_versions ${PROJECT["SERVER"]}))
    PROJECT["APACHE_CONTAINER_NAME"]="${PROJECT["PROJECT_NAME"]}_apache"
    PROJECT["APACHE_VERSION"]=` echo "${OPTIONS[($(get_choice $OPTIONS "Choisissez la version de Apache")-1)*2+1]}" | grep -o "[0-9.]\+"`
    update_env "APACHE_CONTAINER_NAME"
    update_env "APACHE_VERSION"
} # build_apache

function build_nginx()
{
    OPTIONS=($(get_available_versions ${PROJECT["SERVER"]}))
    PROJECT["NGINX_CONTAINER_NAME"]="${PROJECT["PROJECT_NAME"]}_nginx"
    PROJECT["NGINX_VERSION"]=` echo "${OPTIONS[($(get_choice $OPTIONS "Choisissez la version de Nginx")-1)*2+1]}" | grep -o "[0-9.]\+"`
    update_env "NGINX_CONTAINER_NAME"
    update_env "NGINX_VERSION"
}

# Build nodejs configuration
function build_nodejs()
{
    add_template "nodejs"

    if ! [ -d "$DEFAULT_PROJECT_SOURCE_DIR" ]; then
        mkdir "$DEFAULT_PROJECT_SOURCE_DIR"
    fi

    PROJECT["NODEJS_CONTAINER_NAME"]="${PROJECT["PROJECT_NAME"]}_nodejs"
    update_env "NODEJS_CONTAINER_NAME"

    if [ ${PROJECT["SERVER"]} = "nodejs" ]; then
      PROJECT["NODEJS_DEV_HOST"]="${PROJECT["PROJECT_NAME"]}.docker"
    else
        PROJECT["NODEJS_DEV_HOST"]="nodejs.${PROJECT["PROJECT_NAME"]}.docker"
    fi
    update_env "NODEJS_DEV_HOST"

    cp "$RESOURCES_PATH/nodejs/package.json" "$DEFAULT_PROJECT_SOURCE_DIR"
    sed -i 's/${PROJECT_NAME}/'"${PROJECT["PROJECT_NAME"]}/" "$DEFAULT_PROJECT_SOURCE_DIR/package.json"

    NODEJS_PORT=$(cat "$TEMPLATES_PATH/nodejs/.env" | grep -oP "NODEJS_PORT=\K(.*)")

    cp "$RESOURCES_PATH/nodejs/main.js" "$DEFAULT_PROJECT_SOURCE_DIR"
    sed -i 's/$NODEJS_PORT/'"$NODEJS_PORT"'/' "$DEFAULT_PROJECT_SOURCE_DIR/main.js"
} # build_nodejs

# Build mysql configuration
function build_mysql()
{
  # MYSQL
  OPTIONS=($(get_available_versions "mysql"))
  PROJECT["MYSQL_CONTAINER_NAME"]="${PROJECT["PROJECT_NAME"]}_mysql"
  PROJECT["MYSQL_VERSION"]=` echo "${OPTIONS[($(get_choice $OPTIONS "Choisissez la version de mysql")-1)*2+1]}" | grep -o "[0-9.]\+"`
  PROJECT["MYSQL_USER"]=${PROJECT["PROJECT_NAME"]}
  PROJECT["MYSQL_PASSWORD"]=${PROJECT["PROJECT_NAME"]}
  PROJECT["MYSQL_DATABASE"]=$(read "Le nom de la base de donnée MYSQL")
  update_env "MYSQL_CONTAINER_NAME"
  update_env "MYSQL_VERSION"
  update_env "MYSQL_USER"
  update_env "MYSQL_PASSWORD"
  update_env "MYSQL_DATABASE"

  to_replace=`cat docker-compose.yml | grep "MYSQL_VOLUME"`
  if [ -n "$to_replace" ]; then
    sed -i "s/$to_replace/  ${PROJECT["MYSQL_CONTAINER_NAME"]}:/" 'docker-compose.yml'
  else
    add_volume_docker_compose "${PROJECT["MYSQL_CONTAINER_NAME"]}"
  fi
} # build_mysql

# Build php configuration
function build_php()
{
  OPTIONS=($(get_available_versions "php"))
  PROJECT["PHP_CONTAINER_NAME"]="${PROJECT["PROJECT_NAME"]}_php"
  PROJECT["PHP_VERSION"]=` echo "${OPTIONS[($(get_choice $OPTIONS "Choisissez la version de PHP")-1)*2+1]}" | grep -o "[0-9.]\+"`
  update_env "PHP_CONTAINER_NAME"
  update_env "PHP_VERSION"
} # build_php

# Build adminer configuration
function build_adminer()
{
  add_template "adminer"

  PROJECT["ADMINER_CONTAINER_NAME"]="${PROJECT["PROJECT_NAME"]}_adminer"
  PROJECT["ADMINER_VIRTUAL_HOST"]="adminer.${PROJECT["PROJECT_NAME"]}.docker"
  update_env "ADMINER_CONTAINER_NAME"
  update_env "ADMINER_VIRTUAL_HOST"
} # build_adminer

# Build rabbitmq configuration
function build_rabbitmq()
{
  add_template "rabbitmq"

  PROJECT["RABBITMQ_CONTAINER_NAME"]="${PROJECT["PROJECT_NAME"]}_rabbitmq"
  PROJECT["RABBITMQ_USER"]="${PROJECT["PROJECT_NAME"]}"
  PROJECT["RABBITMQ_PASSWORD"]="${PROJECT["PROJECT_NAME"]}"
  PROJECT["RABBITMQ_VIRTUAL_HOST"]="rabbitmq.${PROJECT["PROJECT_NAME"]}.docker"
  update_env "RABBITMQ_CONTAINER_NAME"
  update_env "RABBITMQ_USER"
  update_env "RABBITMQ_PASSWORD"
  update_env "RABBITMQ_VIRTUAL_HOST"
} # build_rabbitmq

# Build supervisord configuration
function build_supervisord()
{
  add_template "supervisord"

  PROJECT["SUPERVISORD_CONTAINER_NAME"]="${PROJECT["PROJECT_NAME"]}_supervisord"
  update_env "SUPERVISORD_CONTAINER_NAME"

  add_volume_docker_compose "${PROJECT["SUPERVISORD_CONTAINER_NAME"]}"
  sed -i "s/\${SUPERVISORD_VOLUME_NAME}/${PROJECT["SUPERVISORD_CONTAINER_NAME"]}/" 'docker-compose.yml'
} # build_supervisord

# Build apache addons configurations
function build_addons()
{
  OPTIONS=(
    1 "Adminer" "Adminer"
    2 "RabbitMQ" "RabbitMQ"
    3 "Supervisord" "Supervisord"
    4 "NodeJS" "NodeJS"
  )
  CHOICES=$(get_choices $OPTIONS "Voulez vous une de ces dépendences additionelles")

  for CHOICE in $CHOICES
  do
      case $CHOICE in
              1) build_adminer ;;
              2) build_rabbitmq ;;
              3) build_supervisord ;;
              4) build_nodejs ;;

      esac
  done
} # build_addons

###############
#   PROJECTS  #
###############

# Build the base of a project
function build_project()
{
  PROJECT["STACK"]=$1

  if [ -d "$STACK_PATH/${PROJECT["STACK"]}" ]; then
    shopt -s dotglob
    cp -r --copy-contents $STACK_PATH/${PROJECT["STACK"]}/* "."
  else
    mkdir '.docker'
    cp "$TEMPLATES_PATH/$TEMPLATE_NAME/.env" '.env.dist'
    cp "$TEMPLATES_PATH/$TEMPLATE_NAME/docker-compose.yml" 'docker-compose.yml'
    cp "$TEMPLATES_PATH/$TEMPLATE_NAME/Makefile" 'Makefile'
    add_template "proxy"
  fi

  update_env "PROJECT_NAME"
  update_env "NETWORK_NAME"
  update_env "PROJECT_DEV_HOST"

  FUNCTION="build_$(echo "${PROJECT["STACK"]}" | tr '[:upper:]' '[:lower:]')_project"
  type $FUNCTION>/dev/null
  if [ $? -eq 0 ]; then
      $FUNCTION
      #clear
  else
      printf "\033c"
      echo "La configuration pour cette stack n'est pas disponible"
  fi
  build_addons
  build_depends
} # build_project

# Build apache project
function build_apache_project()
{
  PROJECT["SERVER"]="apache_php"
  # APACHE
  build_apache
  # PHP
  build_php
  # MYSQL
  build_mysql
} # build_apache_project

# Build apache project
function build_nginx_project()
{
  PROJECT["SERVER"]="nginx_php"
  # APACHE
  build_nginx
  # PHP
  build_php
  # MYSQL
  build_mysql
} # build_apache_project

# Build custom project
function build_custom_project()
{
    OPTIONS=(
      1 "Apache"
      2 "Nginx"
      3 "NodeJS"
    )
    SERVER=$(echo "${OPTIONS[($(get_choice $OPTIONS "Choisissez votre serveur web")-1)*2+1]}" | tr '[:upper:]' '[:lower:]')

    if [ $SERVER = "nodejs" ]; then
        PROJECT["SERVER"]="$SERVER"
        "build_$SERVER"
    else
        OPTIONS=(
          1 "PHP"
          2 "Ruby"
        )
        LANGUAGE=$(echo "${OPTIONS[($(get_choice $OPTIONS "Choisissez le language interpreté par le serveur")-1)*2+1]}" | tr '[:upper:]' '[:lower:]')

        PROJECT["SERVER"]="$SERVER"_"$LANGUAGE"
        echo "$SERVER"_"$LANGUAGE"
        echo ${PROJECT["SERVER"]}
        add_template "$SERVER"_"$LANGUAGE"
        "build_$SERVER"
        add_template "$LANGUAGE"
        "build_$LANGUAGE"
    fi

    if [ $(ask "Voulez vous utiliser MySQL ?") -eq 0 ]; then # or a database server more generally
        add_template "mysql"
        build_mysql
    fi

    build_homepage
} # END build_custom_project

######################
#        MAIN        #
######################
PROJECT["PROJECT_NAME"]=$(read "Veuillez rentrez le nom de votre nouveau projet:" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
PROJECT["NETWORK_NAME"]="${PROJECT["PROJECT_NAME"]}-dev"
PROJECT["PROJECT_DEV_HOST"]="${PROJECT["PROJECT_NAME"]}.docker"
PROJECT["PATH"]="$PROJECTS_REPOSITORY_PATH/${PROJECT["PROJECT_NAME"]}"

if [ -d "${PROJECT["PATH"]}" ]; then
  clear
  echo "Le nom du dossier/projet est déjà pris"
  exit 1
fi

mkdir "${PROJECT["PATH"]}"
cd "${PROJECT["PATH"]}"

AVAILABLE_STACKS=$(ls -d $STACK_PATH/*/ | nl | tr '\n' ' ')
OPTIONS=($(echo $AVAILABLE_STACKS | sed -r "s~$STACK_PATH~~g" | tr '//' ' '))
OPTIONS_SIZE=${#PROJECT[@]}

OPTIONS[$(($OPTIONS_SIZE*2))]=$(($OPTIONS_SIZE+1))
OPTIONS[$(($OPTIONS_SIZE*2+1))]="Custom"

build_project "${OPTIONS[($(get_choice $OPTIONS "Choisissez une base de projet")-1)*2+1]}"

printf "Le projet a bien été créé avec ces fichiers de configuration:"

printf "\n#############"
printf "\n#    ENV    #"
printf "\n#############\n"
cat '.env.dist'

printf "\n########################"
printf "\n#    DOCKER-COMPOSE    #"
printf "\n########################\n"
cat 'docker-compose.yml'
