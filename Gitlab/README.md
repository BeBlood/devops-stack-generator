Gitlab
============

DESCRIPTION
-----------

This repo contains my gitlab container for dev purposes

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

INFORMATION
-----------

This tool expose the port [3000;3001] for public access  
But to use public ssh access you can use the default port (22)
