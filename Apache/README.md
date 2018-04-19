Stack Apache
============

DESCRIPTION
-----------

This stack contains:

* Apache [version(s)=2.4]
* PHP-FPM [version(s)=5.6]
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
