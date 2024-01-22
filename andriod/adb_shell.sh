#!/usr/bin/env bash
#
# adb_shell.sh --- Wrapper over adb shell to ask specifc data.
#
# As the title says, this is a wrapper over "adb shell" to query specific
# things like temperature, battery level, usage and more to be added later 
# as needed. This can ofcourse be done straight call to adb but advantage
# is that you don't need to know the command name etc.
#
# See also:
#   adb_wifi.sh
#   adb_rm.sh
#   adb_ls.sh
#   adb_push.sh
#
# Author:  Arul Selvan
# Version History:
#   Jan 22, 2024 --- Original version
#


# version format YY.MM.DD
version=24.01.22
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Wrapper over adb shell to ask specifc data"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options_list="s:c:p:tblvh"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

device=""
device_count=0
package=""
cmd=""

usage() {
  cat << EOF
$my_name --- simple wrapper over adb to delete files/directory from phone.
Usage: $my_name -s <device> [options] 
  -s <device>   ---> device id of your phone paired (if present must be the first one)
  -p <package>  ---> consumption of power of a specific package
  -c <cmd>      ---> execute arbitary "adb shell" command passed ex: batterystats
  -t            ---> shows battery temp(Celsious) not necessarily phone temp but gives an idea
  -b            ---> battery full stats
  -l            ---> current level i.e. percent of battery left
  -v            ---> enable verbose, otherwise just errors/warnings are printed.    
  -h help
  
  Examples: 
    $my_name -s pixel:5555 -l
EOF
  exit
}

get_device_count() {
  device_count=`adb devices|awk 'NR>1 {print $1}'|wc -w|tr -d ' '`
  # if device count is 0 just exit
  if [ $device_count -eq 0 ] ; then
    log.error "no devices are connected to adb, try pairing your phone (see adb_wifi.sh)."
    exit 1
  fi
}

check_device_count() {
  # check if adb connected to multiple devices but we don't have -s option
  if [ $device_count -gt 1 ] && [ -z "$device" ] ; then
    log.error "More than one device connected to adb, please specify device to use with -s option"
    usage
    exit 2
  fi
}

check_device() {
  log.info "Check if the device ($device) is connected  ... "
  devices=$(adb devices|awk 'NR>1 {print $1}')
  for d in $devices ; do
    case $d in 
      $device[:.]*)
        # must be a tcp device, attempt to connect
        log.info "This device ($device) is connected via TCP, attempting to connect ... "
        adb connect $device 2>&1 | tee -a $my_logfile
        return
        ;;
      $device)
        # matched the full string could be USB or TCP (in case argument contains port)
        # if TCP make connection otherwise do nothing
        if [[ $device == *":"* ]] ; then
          log.info "This device ($device) is connected via TCP, attempting to connect ... "
          adb connect $device 2>&1 | tee -a $my_logfile
        else
          log.info "This device ($device) is connected via USB ... "
        fi
        return
        ;;
    esac
  done
  
  log.error "The specified device ($device) does not exist or connected!"
  exit 1
}

package_poweruse() {
  check_device_count
  log.stat "Package ($package) power usage..."
  adb $device shell dumpsys batterystats --history --charged $package |grep TOTAL
  exit 0
}

shell_command() {
  check_device_count
  log.stat "Executing shell command $cmd ..."
  adb $device shell $cmd
  exit 0
}

battery_temp() {
  check_device_count
  log.stat "Battery temperature (celscious) ..."
  adb $device shell dumpsys battery get temp
  exit 0
}

battery_stats() {
  check_device_count
  log.stat "Battery stats ..."
  adb $device shell dumpsys battery
  exit 0
}

battery_level() {
  check_device_count
  log.stat "Battery level (percent) ..."
  adb $device shell dumpsys battery get level
  exit 0
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile


# parse commandline
while getopts "$options_list" opt ; do
  case $opt in 
    s)
      device="$OPTARG"
      # check the device
      check_device
      device="-s $device"
      ;;
    p)
      get_device_count
      package="$OPTARG"
      package_poweruse
      ;;
    c)
      cmd="$OPTARG"
      get_device_count
      shell_command
      ;;
    t)
      get_device_count
      battery_temp
      ;;
    b)
      get_device_count
      battery_stats
      ;;
    l)
      get_device_count
      battery_level
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

exit 0

