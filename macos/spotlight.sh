#!/bin/sh
#
# spotlight.sh --- simple wrapper to stop/start the annoyning MacOS spotlight
#
# The spotlight is one of MacOS junk that has a bug (see syslog below) that 
# no one knows how to fix. It constantly spews this message flooding syslog
# which is not good for SSD disks and there is no way to stop this madness.
# The only way to remove the service is to undo SIP, remove and turn it back 
# on but then a subsequent OS update will enable back this nonsense. This script 
# allows to enable/disable w/ out removing the service.
#
# NOTE: turning off and turning on will do the full indexing, even if it is
#  up to date! Also, when it is off, macOS outlook native client's search will 
#  not work, no idea why outlook can't implement search and relying on this 
#  stupid thing!
#
#  Dec 31 04:47:37 lion com.apple.xpc.launchd[1] 
#   (com.apple.mdworker.shared.0A000000-0700-0000-0000-000000000000[27780]): 
#   Service exited due to SIGKILL | sent by mds[91]
#
# Author:  Arul Selvan
# Version: Dec 31, 2020
#

my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
spotlight_index_files="/private/var/db/Spotlight /System/Volumes/Data/.Spotlight-V100"

# ensure path for cron runs
export PATH="/usr/bin:/sbin:/usr/local/bin:$PATH"

usage() {
  echo "Usage: $my_name <on|off|reset|status>"
  echo "   on     ---> enable spotlight"
  echo "   off    ---> disable spotlight"
  echo "   status ---> show status"
  echo "   reset  ---> remove index files, note: 'on' will recreate again"
  exit 0
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit 1
  fi
}

on() {
  echo "[INFO] turning on spotlight" | tee -a $log_file
  mdutil -a -i on 2>&1 | tee -a $log_file
}

off() {
  mdutil -a -i off 2>&1 | tee -a $log_file
  echo "[INFO] turning off spotlight" | tee -a $log_file
}

reset() {
  echo "[INFO] remove spotlight index files" | tee -a $log_file
  rm -f $spotlight_index_files 2>&1 | tee -a $log_file
}

status() {
  echo "[INFO] current status of spotlight" | tee -a $log_file
  mdutil -a -s 2>&1 | tee -a $log_file
}


# ---------- main ----------
echo "[INFO] `date`: $my_name starting ..." > $log_file
check_root

case $1 in
  on|off|status|reset) "$@"
  ;;
  *) usage
  ;;
esac

exit 0
