#!/usr/bin/env bash
################################################################################
# macos.sh --- Misl handy system utils for macOS all in one place
#
# Author:  Arul Selvan
# Created: Aug 25, 2024
################################################################################
#
# Version History:
#   Aug 25, 2024 --- Original version
#   Nov 11, 2024 --- Added showipexternal command, show interface on showip command
#   Nov 26, 2024 --- Moved all network functions related to tools/network.sh script
#   Feb 1,  2025 --- Print swap filename/size, disk usage etc.
#   Feb 20, 2025 --- Added spotlight info
#   Feb 21, 2025 --- Added kill command for macOS cpu hogs we can't get rid of.
#   Feb 22, 2025 --- Added disablespotlight
#   Feb 28, 2025 --- Added type, cputemp etc
################################################################################

# version format YY.MM.DD
version=25.02.28
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Misl tools for macOS all in one place"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="c:l:a:vh?"

arp_entries="/tmp/$(echo $my_name|cut -d. -f1)_arp.txt"
arg=""
command_name=""
supported_commands="mem|vmstat|cpu|disk|version|system|serial|volume|swap|bundle|spotlight|kill|disablespotlight|type|cputemp"
volume_level=""
spolight_path="/System/Volumes/Data/.Spotlight-V100"
spotlight_volumes="/ /System/Volumes/Data"

# default kill list
#
# Note: these items in the kill list are pigs that we can't get rid of w/ out 
# doing risky things like deleting or moving files in root '/' partition to 
# get rid of the corresponding launchctl pllist files. The only thing you can 
# do is kill these hogs every few minutes w/ cron job.
kill_list="mediaanalysisd mediaanalysisd-access photoanalysisd photolibraryd cloudphotod Stocks StocksKitService StocksWidget StocksDetailIntents"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -c <command>   ---> command to run [see supported commands below]
  -l <number>    ---> volume level [used by 'volume' command range: 1-100]
  -a <arg>       ---> arguments for commands like bundle or kill etc.
  -v             ---> enable verbose, otherwise just errors are printed
  -h             ---> print usage/help

Supported commands: $supported_commands
examples(s)
  $my_name -c mem
  $my_name -c bundle -a textedit
  $my_name -c volume -l 25
  $my_name -c kill -a "$kill_list"
  
EOF
  exit 0
}

showmem() {
  hwmemsize=$(sysctl -n hw.memsize)
  ramsize=$(expr $hwmemsize / $((1024**3)))
  free_percent=$(memory_pressure|grep percentage|awk '{print $5;}')
  log.stat "\tPhysical Memory: ${ramsize}GB" $green
  log.stat "\tFree Memory    : ${free_percent}" $green
}

showvmstat() {
  log.stat "`vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages\s+([^:]+)[^\d]+(\d+)/ and printf("%-16s % 16.2f MB\n", "$1:", $2 * $size / 1048576);'`" $green

}

showcpu() {
  log.stat "\t`system_profiler SPHardwareDataType`" $green
  #log.stat "\tVendor: `sysctl -a machdep.cpu.vendor|awk -F: '{print $2}'`"  $green
  #log.stat "\tBrand:  `sysctl -a machdep.cpu.brand_string|awk -F: '{print $2}'`" $green
  #log.stat "\tFamily: `sysctl -a machdep.cpu.extfamily|awk -F: '{print $2}'`" $green
  #log.stat "\tModel:  `sysctl -a machdep.cpu.model|awk -F: '{print $2}'`" $green
  #log.stat "\tCores:  `sysctl -a machdep.cpu.core_count|awk -F: '{print $2}'`" $green
}

volume() {
  # if level is provided use to set (otherwise, just show)
  if [ ! -z $volume_level ] ; then
    log.stat "\tSetting output volume to $volume_level" $green
    osascript -e "set volume output volume $volume_level"
  else
    log.stat "\tCurrent output volume is: `osascript -e "output volume of (get volume settings)"`" $green
  fi
}

showswap() {
  log.stat "`sysctl vm.compressor_mode vm.swapusage`" $green
  local swapprefix=`sysctl vm.swapfileprefix|awk '{print $2}'`
  ls ${swapprefix}[0-9] 1>/dev/null 2>&1
  if [ $? -eq 0 ] ; then
    log.stat "swap file(s)" $green
    log.stat "`ls -lh ${swapprefix}[0-9]|awk '{print "    ", $9," ",$5}'`" $green
  fi
}

showdisk() {
  local df_output=`df -h /System/Volumes/Data/|tail -1`
  log.stat "`echo $df_output|awk '{print "  Total: ",$2,"\n  Used:  ",$3,"\n  Available: ",$4,"\n  Capacity:  ",$5}'`"
}

showspotlight() {
  log.stat "Spotlight status:" 
  log.stat "  `mdutil -as`"
  local space_used="None"
  if [ -d $spolight_path ] ; then
    space_used=`du -sh $spolight_path |awk '{print $1}'`
  fi
  log.stat "Spotlight storage space: $space_used"
}

do_kill() {
  local klist="$kill_list"
  if [ ! -z "$arg" ] ; then
    klist="$arg"
  fi
  log.debug "Kill list: $klist"
  for pname in $klist ; do
    pid=$(pidof $pname)
    if [ ! -z "$pid" ] ; then
      # be nice first by using SIGINT, if not dying kill with SIGKILL
      kill -2 $pid
      if [ $? -ne 0 ] ; then
        log.warn "Forcing w/ SIGKILL as $pname ($pid) is refusing to die!"
        kill -9 $pid
      else
        log.stat "Killed: $pname ($pid)"
      fi
    else
      log.debug "No process running with name: $pname"
    fi
  done
}

do_disablespotlight() {
  log.stat "Disabling Spotlight completely!"
  mdutil -adE -i off
}

show_cpu_temp() {
  local t=$(macos_type)
  if [ $t == "Intel" ] ; then
    log.stat "CPU Temp: `sudo powermetrics --samplers smc -n1|grep -i "CPU die"|awk '{print $4,$5}'`"
  elif [ $t == "Apple" ] ; then
    local tvalue=`sudo powermetrics -s thermal -n1|awk '/Current pressure/ {print $4}'`
    case $tvalue in
      Nominal)
        log.stat "CPU Temp: $tvalue" $green
        ;;
      Fair)
        log.stat "CPU Temp: $tvalue"
        ;;
      Serious)
        log.stat "CPU Temp: $tvalue" $yellow
        ;;
      Critical)
        log.stat "CPU Temp: $tvalue" $red
        ;;
      *)
        log.stat "CPU Temp: Unknown" $red
        ;;
    esac
  else
    log.stat "CPU Temp: Unknown"
  fi
}


# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  echo "See INSTALL instructions at: https://github.com/aselvan/scripts?tab=readme-ov-file#setup"
  exit 1
fi
# init logs
log.init $my_logfile

# parse commandline options
while getopts $options opt ; do
  case $opt in
    c)
      command_name="$OPTARG"
      ;;
    l)
      volume_level="$OPTARG"
      ;;
    a)
      arg="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check for any commands
if [ -z "$command_name" ] ; then
  log.error "Missing arguments, see usage below"
  usage
fi

case $command_name in 
  mem)
    showmem
    ;;
  cpu)
    showcpu
    ;;
  vmstat)
    showvmstat   
    ;;
  version)
    sw_vers   
    ;;
  system)
    system_profiler SPSoftwareDataType   
    ;;
  serial)
    ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}'  
    ;;
  volume)
    volume  
    ;;
  swap)
    showswap
    ;;
  disk)
    showdisk
    ;;
  bundle)
    if [ -z "$arg" ] ; then
      log.error "bundle requires argumement... see usage"
      usage
    fi
    cmd="osascript -e 'id of app \"$arg\"'"
    log.stat "\t`eval $cmd`" $green
    ;;
  spotlight)
    check_root
    showspotlight
    ;;
  disablespotlight)
    do_disablespotlight
    ;;
  kill)
    do_kill
    ;;
  type)
    log.stat "MacOS type: `get_macos_type`"
    ;;
  cputemp)
    # need root access
    check_root
    show_cpu_temp
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac
