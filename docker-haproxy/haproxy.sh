#!/bin/sh
#
# haproxy.sh
#   Simple wrapper script to run haproxy docker image 
#
# Author:  Arul Selvan
# Version: Sep 5, 2019
#
# create a self signed cert like so
#
#  # create a cert and self sign
#  openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -keyout server.key -out server.crt
#  #get csr (for signing later with a certified authority)
#  openssl req -new -key server.key -out server.csr
#

# The haproxy image (can be a custom image or from stock)
HA_PROXY_IMAGE=haproxy:2.0.5-alpine

# container name
HA_PROXY_NAME=haproxy

# the config
# TODO: install haproxy.cfg to /etc/default on the host server and uncoment the line line below
#HA_PROXY_CFG_PATH=/etc/default
HA_PROXY_CFG_PATH=`pwd`
# TODO: copy ssl cert to  /etc/ssl/certs/ and uncoment the line
#SSL_CERT_PATH=/etc/ssl/certs
SSL_CERT_PATH=`pwd`
HA_PROXY_CFG=haproxy.cfg
HA_PUBLISH_PORTS="-p 443:443"
CONFIG_ARG="-v ${SSL_CERT_PATH}/server.crt:/etc/ssl/certs/server.crt:ro"

start() {
  echo "[INFO] Starting $HA_PROXY_NAME container ..."
  # use external config if provided
  if [ -f  ${HA_PROXY_CFG_PATH}/${HA_PROXY_CFG} ]; then
    echo "[INFO} Using external config (${HA_PROXY_CFG_PATH}/${HA_PROXY_CFG}) ..."
    CONFIG_ARG="${CONFIG_ARG} -v ${HA_PROXY_CFG_PATH}/${HA_PROXY_CFG}:/usr/local/etc/haproxy/${HA_PROXY_CFG}:ro"
  else
    echo "[INFO} Using default config in the image ..."
  fi
  docker run -d --restart=on-failure:6 --name ${HA_PROXY_NAME} ${HA_PUBLISH_PORTS} ${CONFIG_ARG} ${HA_PROXY_IMAGE}
}

stop() {
  echo "[INFO] Stopping $HA_PROXY_NAME container ..."
  docker stop ${HA_PROXY_NAME}
  docker rm ${HA_PROXY_NAME}
}

restart() {
  stop
  echo "[INFO] sleep for 5 sec ..."
  sleep 5
  start
}

status() {
	docker ps --filter "name=${HA_PROXY_NAME}"
}

# ---------- main ----------
case $1 in
  start|stop|restart|status) "$@"
  ;;
  *) echo "Usage: $0 <start|stop|restart|status>"
  ;;
esac

exit 0
