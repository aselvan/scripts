#/bin/sh

#
#  process_mon.sh --- simple wrapper over ps to collect process cpu,mem,rss,vsize in csv file
#
# Author:  Arul Selvan
# Version: Jul 21, 2020
#

# ensure this script runs under cron w/ out having to set full path
export PATH="/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin"

my_name=`basename $0`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
base_path="/root"

# default process to monitor are paloalto traps which tend to suck resources
process_list="pmd authorized dypd analyzerd trapsd"
option=""
csv_header="DateTime, PID, CMD, %MEM, %CPU, RSS (MB), VSZ (MB)"
options_list="ril:h"
crontab_entry="*/5 * * * * /bin/flock -w10 /tmp/$my_name.lock $base_path/$my_name -r >/dev/null 2>&1"

check_root() {
  if [ `id -u` -ne 0 ] ; then
    echo "[ERROR] you must be 'root' to run this script... exiting."
    exit
  fi
}

usage() {
  echo "Usage: $my_name [-r] [-i] [-l <list_of_process>]"
  echo "  -r run once"
  echo "  -i installs as cronjob"
  echo "  -l list of process names. ex: -l 'process_name1 process_name2 ...'"
  exit
}

install() {
  echo "[INFO] Install $my_name as cronjob ..." > $log_file
  # update with latest copy
  cp $0 $base_path/.
  chmod +x $base_path/$my_name

  crontab -l |grep $my_name >/dev/null 2>&1
  if [ $? -eq 0 ] ; then
    echo "[WARN] cron entry already present!, exit" >> $log_file
    return
  fi
  crontab -l > /tmp/crontab.save
  echo "$crontab_entry" >>  /tmp/crontab.save
  crontab /tmp/crontab.save
  echo "[INFO] installed cron entry" >> $log_file
  crontab -l |grep $my_name >> $log_file 2>&1
}

write_process_info() {
  local pname=$1
  local pid=$2
  
  if [ ! -f $base_path/$pname.csv ] ; then
    echo $csv_header >  $base_path/$pname.csv
  fi

  pinfo=`ps -p$pid -ocomm,pmem,pcpu,rss,vsz |awk -v OFS=, 'NR>1 {print $1, $2, $3, $4/1024, $5/1024}'`

  timestamp=`date +'%D %T'`
  echo "$timestamp , $pid , $pinfo" >>  $base_path/$pname.csv
}

run() {
  echo "[INFO] $my_name running..." > $log_file
  for pname in $process_list ; do
    pid_list=`pidof $pname`
    if [ $? -ne 0 ] ; then
      echo "[WARN] unable to get PID of '$pname', continuing w/ rest of the list '$process_list' ..." >> $log_file
      continue
    fi
    # Note: pid_list could be potentially more than one 
    for pid in $pid_list ; do 
      write_process_info $pname $pid
    done
  done
}

check_root
while getopts "$options_list" opt; do
  case $opt in
    i)
      option="install"
      ;;
    r)
      option="run"
      ;;
    l)
      process_list=$OPTARG
      ;;
    h)
      usage
      ;;
   esac
done

if [ "$option" = "run" ] ; then
  run
elif [ "$option" = "install" ] ; then
  install
else
  usage
fi

