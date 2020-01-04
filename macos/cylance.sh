#/bin/sh

#
# cylance.sh --- enable/disable cylance 
#
# Author:  Arul Selvan
# Version: Jan 2, 2019
#

# works with user login or elevated
user=`who -m | awk '{print $1;}'`

# list of jamf plists
launch_daemons_plist="\
  /Library/LaunchDaemons/com.cylance.agent_service.plist \
"
launch_agents_plist="\
  /Library/LaunchAgents/com.cylancePROTECT.plist \
"

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit
  fi
}

enable() {
  echo "[INFO] enabling launch daemons for all users ..."
  for p in $launch_daemons_plist ; do
    if [ -f $p ] ; then
      echo "Enabling: $p"
      sudo launchctl load $p
    fi
  done

  echo "[INFO] enabling launch agents for this user ..."
  for p in $launch_agents_plist ; do
    if [ -f $p ] ; then
      echo "Enabling: $p"
      launchctl load $p
    fi
  done
}

disable() {
  echo "[INFO] disabling launch daemons for all users ..."
  for p in $launch_daemons_plist ; do
    if [ -f $p ] ; then
      echo "Disable: $p"
      sudo launchctl unload -w $p
    fi
  done

  echo "[INFO] disabling launch agents for this user ..."
  for p in $launch_agents_plist ; do
    if [ -f $p ] ; then
      echo "Disable: $p"
      launchctl unload -w $p
    fi
  done
}

#check_root

case $1 in
  enable|disable) "$@"
  ;;
  *) echo "Usage: $0 <enable|disable>"
  ;;
esac

exit 0
