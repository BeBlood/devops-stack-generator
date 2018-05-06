#!/bin/bash
STACK_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
export $(cat $STACK_PATH/.env | grep -v ^\#)
PROJECTS_REPOSITORY_PATH=${PROJECTS_REPOSITORY_PATH/'$HOME'/$HOME}
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
} # END read

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
} # END get_choice

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
} # END get_choices

# Update variables in .env file
function update_env()
{
  VAR_NAME=$1

  sed -i "s/^$VAR_NAME=.*/$VAR_NAME=${PROJECT[$VAR_NAME]}/" '.env'
} # END update_env

# Build mysql configuration
function build_mysql()
{
  # MYSQL
  OPTIONS=(
    1 "MYSQL 8.4"
    2 "MYSQL 8.0"
    3 "MYSQL 5.6"
  )
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
} # build_mysql

# Build php configuration
function build_php()
{
  OPTIONS=(
    1 "PHP 5.6"
    2 "PHP 7.0"
    3 "PHP 7.1"
  )
  PROJECT["PHP_CONTAINER_NAME"]="${PROJECT["PROJECT_NAME"]}_php"
  PROJECT["PHP_VERSION"]=` echo "${OPTIONS[($(get_choice $OPTIONS "Choisissez la version de PHP")-1)*2+1]}" | grep -o "[0-9.]\+"`
  update_env "PHP_CONTAINER_NAME"
  update_env "PHP_VERSION"
} # build_php

# Build adminer configuration
function build_adminer()
{
  PROJECT["ADMINER_CONTAINER_NAME"]="${PROJECT["PROJECT_NAME"]}_adminer"
  PROJECT["ADMINER_VIRTUAL_HOST"]="adminer.${PROJECT["PROJECT_NAME"]}.docker"
  update_env "ADMINER_CONTAINER_NAME"
  update_env "ADMINER_VIRTUAL_HOST"
} # build_adminer

# Build apache addons configurations
function build_apache_addons()
{
  OPTIONS=(
    1 "Adminer" "Adminer"
    2 "RabbitMQ" "RabbitMQ"
    3 "JEA" "JEA"
  )
  CHOICES=$(get_choices $OPTIONS "Voulez vous une de ces dépendences additionelles")
  for CHOICE in $CHOICES
  do
      case $CHOICE in
              1) # Adminer
                build_adminer
              ;;
      esac
  done
  clear
} # END build_apache_addons

# Build the base of a project
function build_project()
{
  PROJECT["STACK"]=$1
  shopt -s dotglob
  cp -r --copy-contents $STACK_PATH/${PROJECT["STACK"]}/* "."
  update_env "PROJECT_NAME"
  update_env "NETWORK_NAME"
  update_env "PROJECT_DEV_HOST"

  build_$(echo "${PROJECT["STACK"]}" | tr '[:upper:]' '[:lower:]')_project
} # END build_project

# Build apache project
function build_apache_project()
{
  OPTIONS=(
    1 "APACHE 2.2"
    2 "APACHE 2.4"
  )
  PROJECT["APACHE_CONTAINER_NAME"]="${PROJECT["PROJECT_NAME"]}_apache"
  PROJECT["APACHE_VERSION"]=` echo "${OPTIONS[($(get_choice $OPTIONS "Choisissez la version de Apache")-1)*2+1]}" | grep -o "[0-9.]\+"`
  update_env "APACHE_CONTAINER_NAME"
  update_env "APACHE_VERSION"

  # PHP
  build_php
  # MYSQL
  build_mysql
  # ADD-ONS
  build_apache_addons
  clear
} # END build_apache_project

######################
#        MAIN        #
######################

PROJECT["PROJECT_NAME"]=$(read "Veuillez rentrez le nom de votre nouveau projet:")
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

OPTIONS=(
  1 "Apache"
  2 "Nginx"
  3 "Symfony"
)

build_project "${OPTIONS[($(get_choice $OPTIONS "Choisissez une base de projet")-1)*2+1]}"
echo "Le projet a bien été créé avec ce fichier de configuration:"
cat .env
