#/bin/bash

#
#  service_connection_count.sh --- count remote tcp conncections to specific service port
#
# Author:  Arul Selvan
# Version: Jan 11, 2020
#

# default port oracle (1521)
port=1521
log_file=""
starting=""
starting_state="SYN_SENT"
established=""
established_state="ESTABLISHED"
closing=""
closing_state="CLOSING,CLOSE_WAIT,FIN_WAIT1,FIN_WAIT2,CLOSED,TIME_WAIT,LAST_ACK"

os_name=`uname -s`
options_list="p:f:h?"

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit
  fi
}

usage() {
  echo "Usage: $0 [-p <servicePort>]"
  echo "   servicePort --- remote service port to get total number of connections"
  exit
}

collect_info() {
	# active connections
	starting=`lsof -ti :$port -s TCP:$starting_state |wc -l`
	established=`lsof -ti :$port -s TCP:$established_state |wc -l`
	closing=`lsof -ti :$port -s TCP:$closing_state|wc -l`

  # this not exactly accurate since it is possible for multiple process to connect to same
  # service but it is not very likely so we assume that is not the case.
	pname=`lsof -i :$port -s TCP:$starting_state,$established_state,$closing_state |awk '{if (NR==2) print $1}'`
  if [ -z $pname ] ; then
    pname="N/A"
  fi
}

check_root
if [ $os_name = "Darwin" ]; then
  closing_state="CLOSING,CLOSE_WAIT,FIN_WAIT_1,FIN_WAIT_2,CLOSED,LAST_ACK"  
fi

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

timestamp=`date +'%D %T'`
collect_info

if [ -z $log_file ] ; then
	printf "Timestamp\t\t TCP:starting\t TCP:established\t TCP:closing\t Name\t ServicePort\n"
	printf "$timestamp\t $starting\t\t $established\t\t\t $closing\t\t $pname\t $port\n"
else
	if [ ! -f $log_file ] ; then
	  echo "Timestamp, TCP:starting, TCP:established, TCP:closing, Name, ServicePort" > $log_file
	fi
	echo "$timestamp, $starting, $established, $closing, $pname, $port" >> $log_file
fi

exit 0
