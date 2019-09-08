#/bin/sh

#
# freestyle_libre.sh --- enable/disable freeStyle Libre glucometer support service on MacOS
# 
# Allows to manually start and stop the service on a 'as needed' basis since
# this service spins and chews up resources all day long for no reason
# 
# Cant remove Libre FreeStyle blood glucometer helper/opener app because 
# it also does other crap needed for ther reader app, so disable it
# so we can enable when using the app.
#
# Author:  Arul Selvan
# Version: Sep 8, 2019
#


log_file="/tmp/freestyle_libre.log"

# plists
libre_daemons_plist="/Library/LaunchDaemons/com.abbott.FreeStyleLibreMAS.plist"

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting." | tee -a $log_file
    exit
  fi
}

enable() {
  echo "[INFO] enabling libre helper ..." | tee -a $log_file
  for p in $libre_daemons_plist ; do
    if [ -f $p ] ; then
      echo "\tEnabling: $p" | tee -a $log_file
      launchctl load -w $p >>$log_file 2>&1
    else
      echo "\tDamon plist: $p not found"
    fi
  done
}

disable() {
  echo "[INFO] disabling libre helper ..." | tee -a $log_file
  for p in $libre_daemons_plist ; do
    if [ -f $p ] ; then
      echo "\tDisabling: $p" | tee -a $log_file
      launchctl unload -w $p >>$log_file 2>&1
    else
      echo "\tDamon plist: $p not found"
    fi
  done
}

echo "$0 starting..." > $log_file
check_root

case $1 in
  enable|disable) "$@"
  ;;
  *) echo "Usage: $0 <enable|disable>"
  ;;
esac

exit 0
