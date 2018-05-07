ARG PHP_VERSION

FROM php:$PHP_VERSION-fpm

RUN apt-get update \
	    && apt-get install -y supervisor \
	    && rm -rf /var/lib/apt/lists/*

CMD ["/usr/bin/supervisord", "-n"]
