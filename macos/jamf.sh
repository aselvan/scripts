#/bin/sh

#
# jamf.sh --- enable/disable jamf agent and daemons on demand.
#
# Author:  Arul Selvan
# Version: Dec 21, 2018
#

# works with user login or elevated
user=`who -m | awk '{print $1;}'`

# list of jamf plists
jamf_daemons_plist="\
  /Library/LaunchDaemons/com.jamf.management.daemon.plist \
  /Library/LaunchDaemons/com.jamfsoftware.task.1.plist \
  /Library/LaunchDaemons/com.jamfsoftware.jamf.daemon.plist \
  /Library/LaunchDaemons/com.jamfsoftware.startupItem.plist \
  /Library/LaunchDaemons/com.samanage.SamanageAgent.plist"

jamf_agent_plist="\
  /Library/LaunchAgents/com.jamf.management.agent.plist \
  /Library/LaunchAgents/com.jamfsoftware.jamf.agent.plist"

#
# remove crap that were messed up, specifically preferences that 
# were overriden which breaks crond (i.e. sleep time which breaks crond)
#
disable_misl() {
  echo "[INFO] Cleanup the jamf crap for user $user"
  dscl . -mcxdelete /Users/$user

  echo "[INFO] remove /Library/Managed Preferences ..."
  cd /Library/Managed\ Preferences/ || exit 1
  rm -rf *.plist
  rm -rf $user

  #zap the login hook (read it first to see if there are things we need there)
  defaults delete com.apple.loginwindow LoginHook
  defaults delete com.apple.loginwindow LogoutHook
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit
  fi
}

enable() {
  echo "[INFO] enabling daemons ..."
  for p in $jamf_daemons_plist ; do
    if [ -f $p ] ; then
      echo "[INFO] Enabling: $p"
      launchctl load $p
    fi
  done

  echo "[INFO] enabling launch agents ..."
  for a in $jamf_agent_plist ; do
    if [ -f $a ] ; then
      echo "[INFO] Enabling: $a"
      sudo -u $user launchctl load $a
    fi
  done
}

disable() {
  echo "[INFO] disabling launch daemons ..."
  for p in $jamf_daemons_plist ; do
    if [ -f $p ] ; then
      echo "[INFO} Disabling: $p"
      launchctl unload -w $p
    fi
  done

  echo "[INFO] disabling launch agents for user $user ..."
  for a in $jamf_agent_plist ; do
    if [ -f $a ] ; then
      echo "[INFO] Disabling: $a"
      sudo -u $user launchctl unload -w $a
    fi
  done

  # disable the misl crap
  disable_misl
}

check_root

case $1 in
  enable|disable) "$@"
  ;;
  *) echo "Usage: $0 <enable|disable>"
  ;;
esac

exit 0
