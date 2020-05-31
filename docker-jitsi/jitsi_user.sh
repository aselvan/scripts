#/bin/bash
#
# jitsi_user.sh --- simple wrapper to create delete prosody users for jitsi access
#
# Author:  Arul Selvan
# Version: May 30, 2020

jitsi_host=meet.jitsi

create() {
  user=$1
  password=$2
  docker-compose exec prosody prosodyctl --config /config/prosody.cfg.lua register $user $jitsi_host $password
}

delete() {
  user=$1
  docker-compose exec prosody prosodyctl --config /config/prosody.cfg.lua unregister $user $jitsi_host
}

# create or delete users
case $1 in
  create|delete) "$@"
  ;;
  *) echo "Usage: $0 <create|delete> <username> [password]"
  ;;
esac

