#/bin/bash
#
# jitsi.sh --- simple wrapper to setup directories, settings and start/stop jitsi docker service
#
# Note: change the lines where letsencrypt certs/keys are copied to your own keys
# also change/customize/rename env.selvans.net to suite your needs, otherwise, 
# everything should work, and you'd be running jitsi video conf in your docker host
# in under 10 minutes!
#
# Author:  Arul Selvan
# Version: May 30, 2020

# domain name; used to reference letsencrypt path, env filename etc.
my_domain=selvans.net

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

  # copy you keys to config directory that is mapped as volume inside docker containers
  cp /etc/letsencrypt/live/$my_domain/fullchain.pem configs/web/keys/cert.crt
  cp /etc/letsencrypt/live/$my_domain/privkey.pem configs/web/keys/cert.key

  # copy the environment
  cp env.$my_domain .env

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

