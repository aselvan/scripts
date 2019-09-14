#/bin/sh

#
# crashplan.sh --- enable/disable crashplan (code42) agent and daemon on MacOS
# 
# Allows to manually start and stop the service on a 'as needed' basis since
# this service spins and chews up resources all day long even when set to 
# backup during midnight!
# 
# Usage: Setup two cronjobs (one to enable, one to disable) night time to allow
# backup to occur. Also, setup the backup schedule on the code42 UI for serveral
# hours between start/stop of cron to have backup occur.
#
# Author:  Arul Selvan
# Version: Dec 21, 2018
#

# make sure to change this to your username crashplan is licensed to
#user_name="aselvan"
# should provide effective username on normal and elevated runs
user_name=`who -m | awk '{print $1;}'`
log_file="/tmp/crashplan.log"

# plists
crashplan_daemons_plist="/Library/LaunchDaemons/com.crashplan.engine.plist"
crashplan_agent_plist="/Users/${user_name}/Library/LaunchAgents/com.code42.menubar.plist"

# crashplan ui
cp_ui="/Applications/CrashPlan.app/Contents/MacOS/CrashPlanWeb"

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting." | tee -a $log_file
    exit
  fi
}

enable() {
  echo "[INFO] enabling daemons ..." | tee -a $log_file
  for p in $crashplan_daemons_plist ; do
    if [ -f $p ] ; then
      echo "\tEnabling: $p" | tee -a $log_file
      launchctl load -w $p >>$log_file 2>&1
    fi
  done

  echo "[INFO] enabling launch agents ..." | tee -a $log_file
  for a in $crashplan_agent_plist ; do
    if [ -f $a.disabled ] ; then
      echo "\tEnabling: $a" | tee -a $log_file
      mv $a.disabled $a >> $log_file 2>&1
    fi
  done

  echo "[INFO] starting the UI ..." |tee -a $log_file
  # start the UI
  cd /Users/$user_name
  sudo -u $user_name $cp_ui >>$log_file 2>&1 &
}

disable() {
  echo "[INFO] disabling launch daemons ..." | tee -a $log_file
  for p in $crashplan_daemons_plist ; do
    if [ -f $p ] ; then
      echo "\tDisabling: $p" | tee -a $log_file
      launchctl unload -w $p >>$log_file 2>&1
    fi
  done

  echo "[INFO] disabling launch agents ..." | tee -a $log_file
  for a in $crashplan_agent_plist ; do
    if [ -f $a ] ; then
      echo "\tDisabling: $a" | tee -a $logfile
      mv $a $a.disabled >> $log_file 2>&1
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
