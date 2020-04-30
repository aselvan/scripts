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

script_path="/Library/Application Support/JAMF/ManagementFrameworkScripts"
backup_suffix="backup"
skip_script="skip.sh"

disable_links() {
  cur_dir=`pwd`
  cd "$script_path" || exit

  # create the placeholer and links
  cat <<EOF > $skip_script 
#!/bin/sh
echo "[\`date\`] \$0 starting skip..." >/tmp/$skip_script.log
exit 0
EOF
  chmod +x $skip_script
  scripts=`ls -1 *.sh`
  for script in $scripts ; do
    if [ "$script" = "$skip_script" ] ; then
      continue
    fi
    test -h "$script"
    if [ $? -eq 0 ] ; then
      echo "[ERROR] "$script" is a already a symbolic link, skiping"
      continue
    fi
    mv "$script" "$script".$backup_suffix
    ln -s $skip_script "$script"
  done
}

enable_links() {
  cur_dir=`pwd`
  cd "$script_path" || exit

  scripts=`ls -1 *.sh`
  for script in $scripts ; do
    if [ "$script" = "$skip_script" ] ; then
      continue
    fi
    if [ -f "$script".$backup_suffix ]; then
      rm "$script"
      mv "$script".$backup_suffix "$script"
    else
      echo "[ERROR] missing file: "$script".$backup_suffix, skipping ..."
    fi
  done
}

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
  
  echo "[INFO] Enable jamf scripts for user $user"
  enable_links

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

  # reset links
  echo "[INFO] disabling scripts..."
  disable_links 
}

check_root

case $1 in
  enable|disable) "$@"
  ;;
  *) echo "Usage: $0 <enable|disable>"
  ;;
esac

exit 0
