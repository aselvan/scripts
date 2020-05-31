#/bin/bash
#
# jitsi.sh --- simple wrapper to setup directories, settings and start/stop jitsi docker service
#
# Author:  Arul Selvan
# Version: May 30, 2020

# letsencrypt domain path on the host
letsencrypt_domain=selvans.net

# stop
stop() {
  docker-compose down
}

# setup environment, password, ssl keys etc for the docker run
setup() {
  # strong passwords for internal services
  JICOFO_COMPONENT_SECRET=`openssl rand -hex 16`
  JICOFO_AUTH_PASSWORD=`openssl rand -hex 16`
  JVB_AUTH_PASSWORD=`openssl rand -hex 16`
  JIGASI_XMPP_PASSWORD=`openssl rand -hex 16`
  JIBRI_RECORDER_PASSWORD=`openssl rand -hex 16`
  JIBRI_XMPP_PASSWORD=`openssl rand -hex 16`

  # cleanup the host configuration
  rm -rf ./configs
  mkdir -p configs/web/keys

  # copy our keys
  cp /etc/letsencrypt/live/$letsencrypt_domain/fullchain.pem configs/web/keys/cert.crt
  cp /etc/letsencrypt/live/$letsencrypt_domain/privkey.pem configs/web/keys/cert.key

  # copy the environment
  cp env.selvans.net .env

  # update the password on .env file
  sed -i.bak \
    -e "s#JICOFO_COMPONENT_SECRET=.*#JICOFO_COMPONENT_SECRET=${JICOFO_COMPONENT_SECRET}#g" \
    -e "s#JICOFO_AUTH_PASSWORD=.*#JICOFO_AUTH_PASSWORD=${JICOFO_AUTH_PASSWORD}#g" \
    -e "s#JVB_AUTH_PASSWORD=.*#JVB_AUTH_PASSWORD=${JVB_AUTH_PASSWORD}#g" \
    -e "s#JIGASI_XMPP_PASSWORD=.*#JIGASI_XMPP_PASSWORD=${JIGASI_XMPP_PASSWORD}#g" \
    -e "s#JIBRI_RECORDER_PASSWORD=.*#JIBRI_RECORDER_PASSWORD=${JIBRI_RECORDER_PASSWORD}#g" \
    -e "s#JIBRI_XMPP_PASSWORD=.*#JIBRI_XMPP_PASSWORD=${JIBRI_XMPP_PASSWORD}#g" \
    "$(dirname "$0")/.env"
}

start() {
  # do the setup
  setup

  # stop just in case if it is running
  stop

  # start docker service
  docker-compose up -d
}

case $1 in
  start|stop) "$@"
  ;;
  *) echo "Usage: $0 <start|stop>"
  ;;
esac

