#!/usr/bin/env bash
################################################################################
# macos.sh --- Misl handy system utils for macOS all in one place
#
# Author:  Arul Selvan
# Created: Aug 25, 2024
#
# See Also: process.sh
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
#   Feb 28, 2025 --- Added arch, cputemp etc
#   Mar 6,  2025 --- Remove xpc plist on kill, also added kill list file option
#   Apr 20, 2025 --- Added pids, procinfo commands
#   Jun 22, 2025 --- Added verify (check if code is signed), and log commands
#   Jun 25, 2025 --- Added "spaceused" command
#   Jun 25, 2025 --- Added "disablespotlight" command
#   Jul 9,  2025 --- Added help syntax for each supported commands
#   Jul 22, 2025 --- Added sysext (uses systemextensionsctl list) and lsbom 
################################################################################

# version format YY.MM.DD
version=25.07.22
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Misl tools for macOS all in one place"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="c:l:a:d:r:p:n:kvh?"

arp_entries="/tmp/$(echo $my_name|cut -d. -f1)_arp.txt"
arg=""
command_name=""
supported_commands="mem|vmstat|cpu|disk|version|system|serial|volume|swap|bundle|spotlight|kill|disablespotlight|enablespotlight|arch|cputemp|speed|app|pids|procinfo|verify|log|spaceused|sysext|lsbom"
# if -h argument comes after specifiying a valid command to provide specific command help
command_help=0

volume_level=""
spolight_path="/System/Volumes/Data/.Spotlight-V100"
spotlight_volumes="/System/Volumes/Data/Applications"
xpc_activity_plist="$HOME/Library/Preferences/com.apple.xpc.activity2.plist"
killed_list_file="/tmp/$(echo $my_name|cut -d. -f1)_killed_list.txt"
do_killed_list=0
log_duration="1h"
spaceused_rows=10
spaceused_depth=3
spaceused_path="$HOME"
receipt_path="/var/db/receipts"

# default kill list
#
# Note: these items in the kill list are pigs that we can't get rid of w/ out 
# doing risky things like deleting or moving files in root '/' partition to 
# get rid of the corresponding launchctl plist files. The only thing you can 
# do is kill these hogs every few minutes w/ cron job.
kill_list="mediaanalysisd mediaanalysisd-access photoanalysisd photolibraryd cloudphotod Stocks StocksKitService StocksWidget StocksDetailIntents com.apple.Photos.Migration"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name -c <command> [options]
  -c <command> [-h] ---> command to run [see supported commands below] -h to show command syntax
  -l <number>       ---> volume level [used by 'volume' command range: 1-100]
  -d <number>       ---> used by "log" to filter duration [Default: $log_duration]
  -r <number>       ---> used by "spaceused" to restrict rows to display [Default: $spaceused_rows]
  -n <number>       ---> used by "spaceused" to recurse n-depeth [Default: $spaceused_depth]
  -p <path>         ---> used by "spaceused" to recurse down path [Default: $spaceused_path]
  -a <arg>          ---> arguments for commands like bundle|kill|app|procinfo|codesign|log etc.
  -k                ---> enables writing $killed_list_file showing what was killed 
                         [note: the file may grow to large size]
  -v                ---> enable verbose, otherwise just errors are printed
  -h                ---> print usage/help
NOTE: For commands requiring args add -h after the command to see command specific usage.
Ex: $my_name -c app -h

Supported commands: 
$(echo -e $supported_commands)

See also: process.sh network.sh security.sh

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
  if [ $command_help -eq 1 ] ; then
    log.stat "Usage: $my_name -c volume        # Shows current volume level" $black
    log.stat "Usage: $my_name -c volume -l 25  # sets volume level to 25 [range: 0-100]" $black
    exit 1
  fi

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
  log.stat "`echo $df_output|awk '{print "  Total: ",$2,"\n  Used:  ",$3,"\n  Available: ",$4,"\n  Percent Used:  ",$5}'`"
}

showbundle () {
  if [ $command_help -eq 1 ] ||  [ -z "$arg" ]  ; then
    log.stat "Usage: $my_name -c bundle -a textedit  # this example shows details of textedit" $black
    exit 1
  fi
  cmd="osascript -e 'id of app \"$arg\"'"
  log.stat "\t`eval $cmd`" $green
}

do_kill() {
  if [ $command_help -eq 1 ] ; then
    log.stat "Usage: $my_name -c kill -a \"photoanalysisd photolibraryd\" # kill the list of apps" $black
    exit 1
  fi

  local klist="$kill_list"
  if [ ! -z "$arg" ] ; then
    klist="$arg"
  fi
  
  # TODO: remove the xpc plist if present. This one drives many unnecessary 
  # background tasks and is written by something often. I am not 100% sure 
  # about this but for now get rid of these and monitor for a while to make 
  # sure nothing is broken.
  if [ -f $xpc_activity_plist ] ; then
    log.stat "Removing $xpc_activity_plist ..."
    rm -rf $xpc_activity_plist
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
      if [ $do_killed_list -ne 0 ] ; then
        echo "`date +"%m/%d/%Y %H:%M"`: killed $pname ($pid)" >> $killed_list_file
      fi
    else
      log.debug "No process running with name: $pname"
    fi
  done
}

showspotlight() {
  check_root  
  log.stat "Spotlight status:" 
  mdutil -as
  if [ -d $spolight_path ] ; then
    log.stat "spotlight space used: $(space_used $spolight_path)"
  fi
}

disablespotlight() {
  log.stat "Disabling Spotlight completely!"
  mdutil -adE -i off >> $my_logfile 2>&1
  log.stat "  ${spolight_path}: reclaimed: $(space_used $spolight_path)"
  rm -rf $spotlight_path
}

enablespotlight() {
  log.stat "Enabling Spotlight for $spotlight_volume"
  mdutil -adE -i off >> $my_logfile 2>&1
  log.stat "  ${spolight_path}: reclaimed: $(space_used $spolight_path)"
  rm -rf $spotlight_path
  mdutil -i on $spotlight_volume >> $my_logfile 2>&1  
}


show_cpu_temp() {
  check_root  
  
  local t=$(macos_arch)
  if [ $t == "Intel" ] ; then
    log.stat "CPU Temp: `sudo powermetrics --samplers smc -n1|grep -i "CPU die"|awk '{print $4,$5}'` (Normal: 40-60 C, High: >80 C)"
  elif [ $t == "Apple" ] ; then
    local tvalue=`sudo powermetrics -s thermal -n1|awk '/Current pressure/ {print $4}'`
    local range="; [Possible values: Nominal, Fair, Moderate, Serious, Critical]"
    case $tvalue in
      Nominal)
        log.stat "CPU Temp: $tvalue $range" $green
        ;;
      Fair)
        log.stat "CPU Temp: $tvalue $range "
        ;;
      Moderate)
        log.stat "CPU Temp: $tvalue $range " $yellow
        ;;
      Serious)
        log.stat "CPU Temp: $tvalue $range " $yellow
        ;;
      Critical)
        log.stat "CPU Temp: $tvalue $range " $red
        ;;
      *)
        log.stat "CPU Temp: Unknown ($tvalue)" $red
        ;;
    esac
  else
    log.stat "CPU Temp: Unknown"
  fi
}

show_version() {
  log.stat "OS Details:" $green
  log.stat "\tName: $os_name"
  log.stat "\tVendor:  $(os_vendor)"
  log.stat "\tCodeName: $(os_code_name)"
  log.stat "\tVersion:  $(os_version)"
}

show_app() {
  if [ $command_help -eq 1 ]  ; then
    log.stat "Usage: $my_name -c app [-a \"Google Chrome\"]  # show information of the specified app" $black
    exit 1
  fi

  # if argument provided just show the specific app info, otherwise list all
  if [ ! -z "$arg" ] ; then
    lsappinfo info "$arg"
  else
    lsappinfo list
  fi

}

show_pids() {
  check_root  
  sudo launchctl list | awk '{if ($1 ~ /^[0-9]+$/) print $3,"("$1")"}'  
}

show_procinfo() {
  if [ $command_help -eq 1 ] ||  [ -z "$arg" ]  ; then
    log.stat "Usage: $my_name -c procinfo -a pid  # show general process for pid" $black
    log.stat "See also: process.sh -cinfo -p pid  # show detailed process info for pid" $black
    exit 1
  fi
  check_root  
  sudo launchctl procinfo $arg 
}

verify_code() {
  if [ $command_help -eq 1 ] ||  [ -z "$arg" ]  ; then
    log.stat "Usage: $my_name -c verify -a /sbin/disklabel  # check code sign details or error if not signed" $black
    exit 1
  fi

  codesign -d --verbose=2 $arg
  if [ $? -ne 0 ]; then
    log.error "${arg}: is not signed"
  fi
}

show_log() {
  if [ $command_help -eq 1 ] ||  [ -z "$arg" ]  ; then
    log.stat "Usage: $my_name -c log -a \"string\"       # search system log for string" $black
    log.stat "Usage: $my_name -c log -a \"string\" -d $log_duration # -d can be #mhd [min,hour,day]" $black
    exit 1
  fi

  local filter='eventMessage contains "'"$arg"'"'
  log show --predicate "$filter" --style syslog --last $log_duration
}

show_spaceused() {
  if [ $command_help -eq 1 ] ||  [ -z "$arg" ]  ; then
    log.stat "Usage: $my_name -c spaceused            # show space used under $spaceused_path" $black
    log.stat "Usage: $my_name -c spaceused -r10 -p ~/ # show space used with top 10 max space under ~/ß" $black
    exit 1
  fi

  check_root  
  sudo du -I private -xh -d $spaceused_depth $spaceused_path 2>/dev/null | sort -hr|head -n$spaceused_rows
}

do_lsbom() {
  if [ $command_help -eq 1 ] ||  [ -z "$arg" ]  ; then
    log.stat "Usage: $my_name -c $command_name -a \"string\"  # list $arg installed files"
    log.stat "Example: $my_name -c $command_name -a \"com.nordvpn\" "
    exit 1
  fi
  log.stat "Installed Path of app: $arg"
  # get prefix
  local prefix=`plutil -p  ${receipt_path}/*${arg}*.plist|awk '/InstallPrefixPath/ {print $3}'|tr -d \"`
  log.stat "Prefix: /$prefix"
  lsbom -ds ${receipt_path}/*${arg}*.bom |awk -F/ '{print $2}'|sort -u
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
    k)
      do_killed_list=1
      ;;
    d)
      log_duration="$OPTARG"
      ;;
    r)
      spaceused_rows="$OPTARG"
      ;;
    p)
      spaceused_path="$OPTARG"
      ;;
    n)
      spaceused_depth="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      if [[ -n "$command_name" ]] && valid_command "$command_name" "$supported_commands" ; then
        command_help=1
      else
        usage
      fi
      ;;
  esac
done

# check for any commands
if [ -z "$command_name" ] ; then
  log.error "Missing command, see usage below"
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
    show_version 
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
    showbundle
    ;;
  spotlight)
    showspotlight
    ;;
  disablespotlight)
    disablespotlight
    ;;
  enablespotlight)
    enablespotlight
    ;;
  kill)
    do_kill
    ;;
  arch)
    log.stat "MacOS CPU Architecture: `macos_arch`"
    ;;
  cputemp)
    show_cpu_temp
    ;;
  speed)
    networkquality -s
    ;;
  app)
    show_app
    ;;
  pids)
    show_pids
    ;;
  procinfo)
    show_procinfo
    ;;
  verify)
    verify_code
    ;;
  log)
    show_log
    ;;
  spaceused)
    show_spaceused
    ;;
  sysext)
    log.stat "System Extentions List"
    systemextensionsctl list   
    ;;
  lsbom)
    do_lsbom
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac
