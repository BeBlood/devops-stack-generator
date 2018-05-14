DevOPS stack generator
=============

The stack generator is a tool that create custom stack from existing stacks or from templates

Instructions for project builder
--------------------------------

- Set environnement variables in .env file

- Run the project builder :

```bash
$ bash project.sh
```

- You can also set a new alias in you shell config

```bash
# At the end of your config file
alias create-project="bash path/to/project.sh"
```

- You are now able to use it everywhere with the new command

```bash
$ create-project
```

Project builder for existing stack
------------

/!\ Not available now

Just put the existing stack in the root directory

Existing stacks :

* [X] Apache
* [ ] Laravel
* [X] Nginx
* [ ] Node
* [X] Symfony
* [ ] Wordpress
* [ ] Ruby on Rails
* [ ] Django
* [ ] Elixir

Project builder for custom stack
------------

Existing templates in [.templates](.templates) directory

| Server                                 | Language             | Database                 |    Addon                              |
| --------                               | ---------            | --------                 |    -----                              |
| [Apache for PHP](.templates/apache_php)| [PHP](.templates/php)| [MySQL](.templates/mysql)| [Adminer](.templates/adminer_php)     |
| [Nginx for PHP](.templates/nginx_php)  |                      |                          | [RabbitMQ](.templates/rabbitmq)       |
| [NodeJS](.templates/nodejs)            |                      |                          | [Supervisord](.templates/supervisord) |
|                                        |                      |                          | [NodeJS](.templates/nodejs)           |


- How to define a template ?

	If you want to add a new template to the project builder you just have to create a
new directory in the [.templates](.templates) directory.

	In your custom template directory you can add :

	* A **.env** file that will be merged to your .env.dist file in the builded custom stack

	* A **docker-compose.yml** file that will be added in the same name file in the builded custom stack

	* A **Makefile** that will be merged with the main Makefile in the builded custom stack

	* A **conf** directory that will be the main content of your docker configuration (ex: .docker/nginx/** )

	* A **[.types](.templates/nodejs/.types)** directory used by the project builder to know which type is your template

	* A **[.versions](.templates/mysql/.versions)** file to set the versions which will be asked to choose by the user

	All of these files are **optional**

- How to define the available versions **without** a .versions file ?

	The project builder will search for **Dockerfile** in your conf template with a particular **schema** (ex: Dockerfile-2.0)

- How to configure the template types ?

    To specify the type of a template, create a **.types** directory in your custom template directory and add a new file to precise the type.   

    | Type     | Name of file |
    | ------   | -------      |
    | Server   | .server      |
    | Language | .language    |
    | Database | .database    |
    | Addon    | .addon       |

    The .types directory can contains **multiple** types

- How to manage my **depends** between containers ?

	If in a container you can have a particular depend just add it to the docker-compose.yml template file with
a **depend token**. If a container with the same label exist, the token will be removed to active the depend. As an example :

```yaml
nginx:
  container_name: ${NGINX_CONTAINER_NAME}
  build:
    context: .docker/nginx_php
    dockerfile: Dockerfile-${NGINX_VERSION}
    args:
        - NGINX_PUBLIC_DIR=${NGINX_PUBLIC_DIR}
        - NGINX_PHP_BACKEND_NAME=${PHP_CONTAINER_NAME}
        - NGINX_PHP_BACKEND_PORT=${PHP_PORT}
        - HOST_UID=${HOST_UID}
  environment:
    - VIRTUAL_HOST=${PROJECT_DEV_HOST}
  volumes_from:
    #PHP_DEPEND- php
  depends_on:
    #PHP_DEPEND- php
```

- How to add user input configuartion ?

Create a new **function** in the project builder script with the name "build_[NAME OF TEMPLATE]".
As an example :

```bash
function build_php()
{
  OPTIONS=($(get_available_versions "php"))
  PROJECT["PHP_CONTAINER_NAME"]="${PROJECT["PROJECT_NAME"]}_php"
  PROJECT["PHP_VERSION"]=` echo "${OPTIONS[($(get_choice $OPTIONS "Choose php version")-1)*2+1]}" | grep -o "[0-9.]\+"`
  update_env "PHP_CONTAINER_NAME"
  update_env "PHP_VERSION"
}
```

Todo list
----

- Add user input configuration without modification of the project builder script
- Add more templates
