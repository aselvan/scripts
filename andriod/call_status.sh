#!/bin/bash
#
# call_status.sh --- simple wrapper over adb to check call status
#
#
# Note: in order for this script to work, you must have paired your phone w/ adb first. If 
# there are multiple devices paried, you need to specifiy device name using -s option.
#
# Author:  Arul Selvan
# Version: Mar 2, 2023 --- initial version
#
# ensure path for utilities
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=23.03.02
my_name=`basename $0`
my_version="$my_name v$version"
options_list="s:l:epch"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
device=""
call_log_count=1

#
# prepare an awk script for parsing call log. The following are some headers 
# we are interested other than the obvious data, name, number fields.
# "type" where the values are ...
#   1=incoming; 2=outgoing; 3=missed;4=voicemail; 5=rejeted; 6=blocked; 
#   7=answered externally
read -d '' parseLogScript << EOF
{
  duration=0;
  for(i=1;i<=NF;i++) {
    split(\$i,a,"="); 
    if (a[1] ==" date") {
      cmd=sprintf("date -r %d",a[2]/1000); 
      system(cmd);
    }
    if (a[1]==" duration") {
      duration=sprintf("%0.2f",a[2]/60);
    }
    if (a[1]==" name") printf "\\\tName: %s\\\n",a[2]; 
    if (a[1]==" normalized_number") printf "\\\tNumber: %s\\\n",a[2];
    if (a[1]==" type") {
      if(a[2]== "1") {
        printf "\\\tCall Type: Incoming\\\n";
      }
      else if (a[2]== "2") {
        printf "\\\tCall Type: Outgoing\\\n";
      }
      else if (a[2]== "3") {
        printf "\\\tCall Type: Missed\\\n";
      }
      else if (a[2]== "4") {
        printf "\\\tCall Type: Rejected\\\n";
      }
      else if (a[2]== "5") {
        printf "\\\tCall Type: Blocked\\\n";
      }
      else {
        printf "\\\tCall Type: Unknown\\\n";
      }
      if (duration != 0) {
        printf "\\\tDuration: %s\\\n",duration;
        duration=0;
      }
    }
  }
}
EOF

usage() {
  echo "Usage: $my_name [-s <device] [-r <value>] [-m <value>] [-a <value>]"
  echo "  -s <device> ---> andrioid device id of your phone paired with adb"
  echo "  -l <count>  ---> show last <count> number of call logs"
  echo "  -e          ---> end/hangup the current call"
  echo "  -p          ---> pickup call"
  echo "  -c          ---> call state"
  echo "  -h help"
  exit
}

check_device() {
  echo "[INFO] check if the device ($device) is connected  ... "| tee -a $log_file
  devices=$(adb devices|awk 'NR>1 {print $1}')
  for d in $devices ; do
    case $d in 
      $device[:.]*)
        # must be a tcp device, attempt to connect
        echo "[INFO] this device ($device) is connected via TCP, attempting to connect ... "| tee -a $log_file
        adb connect $device 2>&1 | tee -a $log_file
        return
        ;;
      $device)
        # matched the full string could be USB or TCP (in case argument contains port)
        # if TCP make connection otherwise do nothing
        if [[ $device == *":"* ]] ; then
          echo "[INFO] this device ($device) is connected via TCP, attempting to connect ... "| tee -a $log_file
          adb connect $device 2>&1 | tee -a $log_file
        else
          echo "[INFO] this device ($device) is connected via USB ... "| tee -a $log_file
        fi
        return
        ;;
    esac
  done
  
  echo "[ERROR] the specified device ($device) does not exist or connected!" | tee -a $log_file
  exit 1
}


call_pickup() {
  echo "[INFO] picking up call on device $device" | tee -a $log_file
  adb $device shell input keyevent 5 | tee -a $log_file
}

call_hangup() {
  echo "[INFO] hanging up call on device $device" | tee -a $log_file
  adb $device shell input keyevent 6 | tee -a $log_file
}

call_state() {
  echo "[INFO] calls state of the $device" | tee -a $log_file
  adb $device shell dumpsys telephony.registry 2>&1 | grep mCallState -A 3 | tee -a $log_file
}

call_log() {
  echo "[INFO] log of last $call_log_count calls on the $device" | tee -a $log_file
  log_lines=$(adb $device shell content query --uri content://call_log/calls|tail -n$call_log_count | tee -a $log_file)
  echo $log_lines|awk -F',' "$parseLogScript"
}

# --------------- main ----------------------
echo "[INFO] $my_version starting ..." | tee $log_file

# first get device count
device_count=`adb devices|awk 'NR>1 {print $1}'|wc -w|tr -d ' '`
# if device count is 0 just exit
if [ $device_count -eq 0 ] ; then
  echo "[ERROR] no devices are connected to adb, try pairing your phone." | tee -a $log_file
  exit 1
fi

# parse commandline
while getopts "$options_list" opt ; do
  case $opt in 
    s)
      device=$OPTARG
      check_device
      device="-s $device"
      ;;
    e)
      action=1
      ;;
    c)
      action=2
      ;;
    p)
      action=3
      ;;
    l)
      call_log_count=$OPTARG
      action=4
      ;;
    h)
      usage
      ;;
  esac
done


# check if adb connected to multiple devices but we don't have -s option
if [ $device_count -gt 1 ] && [ -z "$device" ] ; then
  echo "[ERROR] more than one device connected to adb, please specify device to use with -s option" | tee -a $log_file
  usage
  exit 2
fi

case $action in 
  1)
    call_hangup
    ;;
  2)
    call_state
    ;;
  3)
    call_pickup
    ;;
  4)
    call_log
    ;;
  *)
    echo "[ERROR] no arguments!, see usage below" | tee -a $log_file
    usage
    ;;
esac
exit 0

