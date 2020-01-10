#/bin/sh

#
#  process_info.sh --- find process details given port the process listens to
#
# Author:  Arul Selvan
# Version: Jan 10, 2020
#

# default port for obc 8045 (or) 9403
port=8045
options_list="p:"

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit
  fi
}

usage() {
  echo "Usage: $0 [-p <listeningPort>]"
  echo "    listeningPort -- port the process listens to locate the process"
  exit
}

check_root

while getopts "$options_list" opt; do
  case $opt in
    p)
      port=$OPTARG
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

# get pid
pid=`lsof -ti :$port`
if [ -z $pid ] ; then
  echo "[ERROR] no process is listening on $port"
  exit
fi

# find number of open fd's which includes sockets
fd_count=`ls -l /proc/$pid/fd|wc -l`
if [ -z $fd_count ] ; then
  echo "[ERROR] something wrong, the process $pid apparently had no open fd"
  exit
fi

# get process rss size
rss=`ps --no-header -vp $pid | grep -v grep | awk '{print $8;}'`
if [ -z $rss ] ; then
  echo "[ERROR] something wrong, cant find RSS!"
  exit
fi
rss_mb=$(echo "scale=2; $rss/1024"|bc -l)

echo "Timestamp            Open FDs   RSS"
echo "`date +'%D %T'`    $fd_count         $rss_mb"

exit 0
