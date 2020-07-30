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
# Author:  Arul Selvan
# Version: Jul 29, 2020
#

my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
base_path="/root"
options_list="p:m:tdh"
pid=0
olgen_limit=75
terminate=0
thread_dump=0

usage() {
  echo "Usage: $my_name -p <java_pid> [-t|-d] [-m percent]"
  echo "  -p <java_pid>       ---> is the pid of the java process to check for gc usage"
  echo "  -m <percent>        ---> oldgen max percent to check to take action; $olgen_limit% is default"
  echo "  -t                  ---> send SIGTERM if oldgen is > $olgen_limit% used"
  echo "  -d                  ---> send SIGQUIT to generate threaddump if oldgen is > $percent% used"
  exit
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit
  fi
}

check_tools() {
  which jstat >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    echo "[ERROR] jstat is not in the path!"
    exit
  fi
  which jcmd >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    echo "[ERROR] jcmd is not in the path!"
    exit
  fi
  which jstack >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    echo "[ERROR] jcmd is not in the path!"
    exit
  fi
}

terminate() {
  echo "[INFO] sending term signal " || tee -a $log_file
  kill -15 $pid
  # give it some time 
  sleep 30
  
  kill -0 $pid
  if [ $? -ne 0 ] ; then
    # not going down gracefully, kill it
    echo "[INFO] not going down gracefully sending kill signal " || tee -a $log_file    
    kill -9 $pid
  fi
}

take_action() {
  echo "[WARN] oldgen is larger than threshold of $olgen_limit%, taking action!" || tee -a $log_file

  if [ $terminate -ne 0 ] ; then
    terminate
  else
    echo "[INFO] forcing a full GC" || tee -a $log_file
    jcmd $pid GC.run || tee -a $log_file 2>&1
  fi
}

echo "[INFO] $my_name: start" > $log_file

check_tools
check_root

while getopts "$options_list" opt; do
  case $opt in
    p)
      pid=$OPTARG
      ;;
    m)
      olgen_limit=$OPTARG
      ;;
    t)
      terminate=1
      ;;
    d)
      thread_dump=1
      ;;
    h)
      usage
      ;;
   esac
done

# check pid
if [ $pid -eq 0 ] ; then
  echo "[ERROR] pid is a required argument" || tee -a $log_file
  usage
fi

if [ ! -d /proc/$pid ] ; then
  echo "[ERROR] $pid is invalid!" || tee -a $log_file
  usage
fi

result=($(jstat -gcoldcapacity $pid |awk 'NR > 1 { print $0;}'))
oldgen_max=${result[1]}
oldgen_cur=${result[2]}
num_full_gc=${result[5]}
oldgen_used_percent=$(printf %.0f $(echo "scale=2; ($oldgen_cur/$oldgen_max)*100"|bc))

echo "[INFO] Oldgen MAX size: $oldgen_max KB" || tee -a $log_file
echo "[INFO] Oldgen CUR size: $oldgen_cur KB" || tee -a $log_file
echo "[INFO] Oldgen Used %:   $oldgen_used_percent" || tee -a $log_file
echo "[INFo] Total full GC:   $num_full_gc times" || tee -a $log_file

# generate thread dump
if [ $thread_dump -ne 0 ] ; then
  echo "[INFO] dumping threads..." || tee -a $log_file
  jstack -l $pid > /tmp/jvm_stackdump_$pid.txt 2>&1
  echo "[INFO] stack dump for pid $pid is at /tmp/jvm_stackdump_$pid.txt" || tee -a $log_file
fi

# check to see if we need to take action
if [ $oldgen_used_percent -gt $olgen_limit ] ; then
  take_action
fi
