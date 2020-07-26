#/bin/bash
#
# jitsi_user.sh --- simple wrapper to create delete prosody users for jitsi access
#
# Author:  Arul Selvan
# Version: May 30, 2020

jitsi_host=meet.jitsi
my_name=`basename $0`

usage() {
  echo "Usage: $my_name <create|delete|update> <username> [password]"
  exit 0
}

create() {
  user=$1
  password=$2
  if [ -z $user ] || [ -z $password ] ; then
    echo "[ERROR] 'user' and 'password' are required for create"
    usage
  fi
  docker-compose exec -T prosody prosodyctl --config /config/prosody.cfg.lua register $user $jitsi_host $password
}

delete() {
  user=$1
  if [ -z $user ] ; then
    echo "[ERROR] 'user' is a required argument for delete"
    usage
  fi
  docker-compose exec -T prosody prosodyctl --config /config/prosody.cfg.lua unregister $user $jitsi_host
}

update() {
  user=$1
  password=$2
  if [ -z $user ] || [ -z $password ] ; then
    echo "[ERROR] 'user' and 'password' are required for update"
    usage
  fi
  delete $user
  create $user $password
}

# first just do a ps in case stack is not running, it should start the stack
docker ps >/tmp/jitsi_ps.txt 2>&1

# create or delete users
case $1 in
  create|delete|update) "$@"
  ;;
  *) 
  usage 
  ;;
esac

