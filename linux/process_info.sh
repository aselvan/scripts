#/bin/sh

#
#  process_info.sh --- find process details given port the process listens to
#
# Author:  Arul Selvan
# Version: Jan 11, 2020
#

# default port for obc 8045 (or) 9403
port=8045
log_file=""
pid=""
pname=""
rss_mb=""
options_list="p:f:h?"

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

collect_info() {
	# get pid and name
	pid=`lsof -ti :$port -s TCP:LISTEN`
	if [ -z $pid ] ; then
  	echo "[ERROR] no process is listening on $port"
  	exit
	fi
	pname=`lsof -i :$port -s TCP:LISTEN|awk '{if(NR>1)print $1}'`

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
}

while getopts "$options_list" opt; do
  case $opt in
    p)
      port=$OPTARG
      ;;
    f)
      log_file=$OPTARG
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

check_root
timestamp=`date +'%D %T'`
collect_info

if [ -z $log_file ] ; then
	echo "Timestamp            Open FDs   RSS (MB)   Name   PID"
	echo "$timestamp     $fd_count         $rss_mb       $pname   $pid"
else
	if [ ! -f $log_file ] ; then
		echo "Timestamp, Open FDs, RSS (MB), Name, PID" > $log_file
	fi
  echo "$timestamp, $fd_count, $rss_mb, $pname, $pid" >> $log_file
fi

exit 0
