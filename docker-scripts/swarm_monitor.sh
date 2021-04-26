#!/bin/bash
#
# swarm_monitor.sh
#
# Script to do simple monitoring of swarm cluster and stack components deployed in them.
# The script does returns exit codes (see below) which can be used in automated scripts 
# to determine & send alerts.
#
# code  reason
# ----  ------
# 0     success
# 1     incorrect usage; this should not happen in automated scripts
# 2     one or more nodes in cluster with swarm status not in 'ready' status
# 3     one or more nodes in cluster are not in 'active' state
# 4     one or more manager nodes in cluster are not in 'reachable' state
# 5     one or more required services are not running in the stack specified.
# 6     stack is not running
#
# Author:  Arul Selvan
# Version: Jul 25, 2018
#

log_file=/tmp/swarm_monitor.log
scriptPath=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
root="$scriptPath/.."
options_list="cs:hq"
stack=""
quiet=0
first_log=1

usage() {
  echo "Usage: $0 [options]"
  echo "  -s <stack> [check specified stack's health]"
  echo "  -c         [check cluster health]"
  echo "  -q         [quiet, all output suppressed to be used with automated scripts]"
  echo "  -h         [help syntax]"
  exit 1
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit 1
  fi
}

log() {
  m=$1

  if [ $quiet -eq 1 ] ; then
    return
  fi
  
  if [ $first_log -eq 1 ]; then
    first_log=0
    echo $m | tee $log_file
    return
  fi

  echo -e $m | tee -a $log_file
}

check_swarm() {
  log "[INFO] checking health of all swarm cluster nodes..."
  nodes=`docker node ls -q`
  for node in $nodes ; do 
    log "[INFO] checking node '$node'"
    status=`docker node inspect $node --format "{{ .Status.State }}"`
    if [ "$status" != "ready" ] ; then
      log "[ERROR] \t $node is not in 'ready' state!"
      exit 2
    fi
   
    status=`docker node inspect $node --format "{{ .Spec.Availability }}"`
    if [ "$status" != "active" ] ; then
      log "[ERROR] \t $node is not in 'active' state!"
      exit 3
    fi
    log "[INFO] \t node is in active state"

    # see if this is manager, if so check for reachability.
    status=`docker node inspect $node --format "{{ .Spec.Role }}"`
    if [ "$status" = "manager" ] ; then 
      log "[INFO] \t This node is a manager node, checking for reachability"
      status=`docker node inspect $node --format "{{ .ManagerStatus.Reachability }}"`
      if [ "$status" != "reachable" ] ; then
        log "[ERROR] \t $node is not in 'reachable' state!"
        exit 4
      fi
      log "[INFO] \t node is in reachable state"
    fi
  done
  
  log "[INFO] All swarm nodes are good"
}

check_stack() {
  log "[INFO] checking health of stack '$stack' ..."
  services=`docker stack ps $stack -q 2>&1`
  if [ $? -ne 0 ] ; then
    log "[ERROR] The stack '$stack' is not running!"
    exit 6
  fi
  for service in $services ; do 
    log "[INFO] checking service '$service'"
    state=`docker inspect $service --format "{{ .Status.State }}"`
    case "$state" in 
      new|pending|assigned|accepted|preparing|starting|running)
        log "[INFO] \t $service is in normal ($state) state" 
        ;;
      complete|remove|orphaned)
        # just write a warn to GC this later.
        log "[WARN] \t $service needs to be cleaned up, its in '$state' state"
        ;;
      failed|rejected)
        log "[ERROR] \t $service is in abnormal ($state) state!"
        exit 5
        ;;
    esac
  done
  log "[INFO] All services in stack are good"
}

# ------------------ main ------------------
check_root
request=""

while getopts "$options_list" opt; do
  case $opt in
    q)
      quiet=1
      ;;
    c)
      request="check_swarm"
      ;;
    s)
      stack=$OPTARG
      request="check_stack"
      ;;
    h)
      usage
      ;;
    \?)
     usage
     ;;
    :)
     usage
     ;;
   esac
done

case "${request}" in 
  check_swarm)
    log "[INFO] $0 checking swarm status..."
    check_swarm
    ;;
  check_stack)
    log "[INFO] $0 checking stack '$stack' status..."
    check_stack
    ;;
  *)
    usage
    ;;
esac

# no error
exit 0
