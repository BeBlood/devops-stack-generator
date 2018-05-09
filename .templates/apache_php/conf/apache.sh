#! /bin/bash

#/usr/sbin/apache2ctl -D FOREGROUND

# Apache gets grumpy about PID files pre-existing
rm -f /var/run/apache2/apache2*.pid

source /etc/apache2/envvars
exec apache2 -DFOREGROUND
