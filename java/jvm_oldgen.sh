#/bin/bash

#
# jvm_oldgen.sh  --- simple wrapper over jstat to read oldgen usage.
#
# This script checks a JVM's use of oldgen space. If oldgen space in use is over a 
# specificed threshold i.e. 75%, it forces a full GC, or optionally does a thread
# dump or terminate alltogether.
# 
# required: jstat, jcmd,jstack (all are part of JDK distro) on the path
# OS: Linux
#
# Note: the script must be run by the same user running the JVM
#
# Author:  Arul Selvan
# Version: Jul 29, 2020
#

my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
base_path="/root"
default_jdk_home="/usr/java/latest"
options_list="p:m:d:rth"
pid=0
oldgen_threshold=50
threaddump_threshold=75
terminate=0
restart_app=0
# interval between start/stop, terminate 
sleep_seconds=15 
# this is passed to catalina.sh to wait for gracefull shutdown before attempt to force kill
tomcat_wait=60

stop_command="/usr/local/tomcat/bin/shutdown.sh $tomcat_wait -force"
start_command="/usr/local/tomcat/bin/start.sh"

usage() {
  echo "Usage: $my_name -p <java_pid> [-t|-d] [-m percent]"
  echo "  -p <java_pid>       ---> is the pid of the java process to check for gc usage"
  echo "  -m <percent>        ---> oldgen max percent to check to take action; $oldgen_threshold% is default"
  echo "  -r                  ---> restart when oldgen usage exceeds threashold of $oldgen_threshold%"
  echo "  -t                  ---> send SIGTERM if oldgen is > $oldgen_threshold% used (can not be used with -r)"
  echo "  -d <percent>        ---> generate threaddump if oldgen usage is > $threaddump_threshold% "
  exit
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit
  fi
}

check_tools() {
  if [ -z "${JDK_HOME}" ] ; then
    echo "[WARN] JDK_HOME is not set, using default path '$default_jdk_home' on RHEL/CentOS"
    JDK_HOME=$default_jdk_home
  fi

  if [ ! -x  ${JDK_HOME}/bin/jstat ] ; then
    echo "[ERROR] jstat is missing!"
    exit
  fi

  if [ ! -x  ${JDK_HOME}/bin/jcmd ] ; then
    echo "[ERROR] jcmd is missing!"
    exit
  fi
  
  if [ ! -x  ${JDK_HOME}/bin/jstack ] ; then
    echo "[ERROR] jstack is missing!"
    exit
  fi
}

terminate() {
  echo "[INFO] sending term signal " || tee -a $log_file
  kill -15 $pid
  # give it some time 
  sleep $sleep_seconds
  
  kill -0 $pid >/dev/null 2>&1
  if [ $? -eq 0 ] ; then
    # not going down gracefully, kill it
    echo "[INFO] not going down gracefully sending kill signal " || tee -a $log_file    
    kill -9 $pid
  fi
}

restart_app() {
  echo "[INFO] restarting ... " || tee -a $log_file
  echo "[INFO] executing $stop_command  " || tee -a $log_file
  $stop_command >> $log_file 2>&1
  echo "[INFO] sleeping $sleep_seconds sec to start the app..." || tee -a $log_file
  sleep $sleep_seconds
  echo "[INFO] executing $start_command  " || tee -a $log_file
  $start_command >> $log_file 2>&1
  echo "[INFO] wait for sometime for app to startup." || tee -a $log_file
}

take_action() {
  echo "[WARN] oldgen is larger than threshold of $oldgen_threshold%, taking action!" || tee -a $log_file

  if [ $terminate -ne 0 ] ; then
    terminate
  elif [ $restart_app -ne 0 ] ; then
    restart_app
  else
    echo "[INFO] forcing a full GC" || tee -a $log_file
    ${JDK_HOME}/bin/jcmd $pid GC.run || tee -a $log_file 2>&1
  fi
}

# ------------- main --------------------
echo "[INFO] `date` $my_name starting" > $log_file
while getopts "$options_list" opt; do
  case $opt in
    p)
      pid=$OPTARG
      ;;
    m)
      oldgen_threshold=$OPTARG
      ;;
    t)
      terminate=1
      ;;
    d)
      threaddump_threshold=$OPTARG
      ;;
    r)
      restart_app=1
      ;;
    \?|:)
      echo "[ERROR] option requires an argument!"
      usage
      ;;
    h)
      usage
      ;;
   esac
done

check_tools

# check pid
if [ $pid -eq 0 ] ; then
  echo "[WARN] JVM pid is not provided, will use running tomcat (assuming just only one is running)" || tee -a $log_file
  pid=`${JDK_HOME}/bin/jcmd -l|grep org.apache.catalina.startup.Bootstrap |awk '{print $1;}'`
  echo "[INFO] found a tomcat pid $pid ... " || tee -a $log_file
fi

if [ ! -d /proc/$pid ] ; then
  echo "[ERROR] $pid is invalid!" || tee -a $log_file
  usage
fi

result=($(${JDK_HOME}/bin/jstat -gcold $pid |awk 'NR > 1 { print $0;}'))
oldgen_max=${result[4]}
oldgen_cur=${result[5]}
num_full_gc=${result[7]}
oldgen_used_percent=$(printf %.0f $(echo "scale=2; ($oldgen_cur/$oldgen_max)*100"|bc))

echo "[INFO] Oldgen MAX size: $oldgen_max KB" || tee -a $log_file
echo "[INFO] Oldgen CUR size: $oldgen_cur KB" || tee -a $log_file
echo "[INFO] Oldgen Used:     $oldgen_used_percent%" || tee -a $log_file
echo "[INFO] Total full GC:   $num_full_gc times" || tee -a $log_file

# generate thread dump only if oldgen_used_percent greater than threaddump_threshold
if [ $oldgen_used_percent -ge $threaddump_threshold ]  ; then
  echo "[INFO] dumping threads..." || tee -a $log_file
  ${JDK_HOME}/bin/jstack -l $pid > /tmp/jvm_stackdump_$pid.txt 2>&1
  echo "[INFO] stack dump for pid $pid is at /tmp/jvm_stackdump_$pid.txt" || tee -a $log_file
fi

# check to see if we need to take action
if [ $oldgen_used_percent -ge $oldgen_threshold ] ; then
  take_action
fi
