Stack Symfony
============

DESCRIPTION
-----------

This stack contains:

* Symfony [version=2.4]
* NGINX [version(s)=1.10]
* PHP-FPM [version(s)=5.4, 5.6, 7.0]
* MYSQL [version(s)=\*]
* Adminer
* Composer

REQUIREMENTS
------------

* [Docker](https://www.docker.com/)
* [Docker compose](https://github.com/docker/compose)

INSTALL
-------

- Git clone the project

- Configure environnement variables in .env file

- Install containers

```bash
$ make install
```

- Run containers

```bash
$ make start
```

- Install hosts

```bash
$ sudo make install-hosts
```

- Import DB schema as declared in .env file

```bash
$ make mysql_import
```
