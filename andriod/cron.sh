#
# cron.sh --- start cron 
#
# Author:  Arul Selvan
# Version: Dec 20, 2017
#
# PreReq: see busybox_setup.txt in this directory to setup busybox first

# set timezone here, though crontab has it as well.
TZ=CST6CDT
export TZ
myid=`id -nu`
name="cron.sh"

# busybox location
export BB_HOME="/data/local/tmp"
export PATH="$PATH:$BB_HOME"
CRON_HOME="$BB_HOME/cron.d/crontabs"

function is_cron_running() {
  ps|grep crond >/dev/null 2>&1
  rc=$?
  if [ $rc -gt 0 ] ; then
    return 
  fi
  # if we call it for just checking exit
  if [ -z $1 ] ; then
    log -p i -t $myid "$name: crond is already running ... exiting." 
    exit
  fi
  log -p i -t $myid "$name: crond succesfully started."   
}

# log something
log -p i -t $myid "$name: starting ..."

# start only if it is not running already
log -p i -t $myid "$name: checking to see if crond is already running ..."
is_cron_running

# ensure crond home exists
mkdir -p $CRON_HOME

# start cron
log -p i -t $myid "$name: enabling crond ..."
crond -b -c $CRON_HOME

# check to see if it is running now that we started above
is_cron_running 1

log -p i -t $myid "$name: done"

# mark some variable
setprop selvans.cron.active 1
