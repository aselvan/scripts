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
# Version History: (original & last 3)
#   Aug 25, 2024 --- Original version
#   Jan 21, 2026 --- Added orphan command to check container space to cleanup
#   Jan 29, 2026 --- Added command to list Launch[Agents|Daemons] services
#   Feb 02, 2026 --- Added mdm command
################################################################################

# version format YY.MM.DD
version=26.02.05
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Misl tools for macOS all in one place"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="c:l:a:d:r:p:n:kvh?M"

arp_entries="/tmp/$(echo $my_name|cut -d. -f1)_arp.txt"
arg=""
command_name=""
supported_commands="mem|vmstat|cpu|disk|version|system|serial|volume|swap|bundle|sl|kill|disablesl|enablesl|arch|cputemp|speed|app|pids|procinfo|verify|log|spaceused|sysext|lsbom|user|users|kext|kmutil|power|cleanup|usb|btc|bta|hw|system|wifi|monitor|battery|airplay|fan|orphan|la|ld|mdm|ftype|showmounts"
# if -h argument comes after specifiying a valid command to provide specific command help
command_help=0

volume_level=""
spotlight_volume="/System/Volumes/Data"
spotlight_data_path="${spotlight_volume}/.Spotlight-V100"
xpc_activity_plist="$HOME/Library/Preferences/com.apple.xpc.activity2.plist"
killed_list_file="/tmp/$(echo $my_name|cut -d. -f1)_killed_list.txt"
do_killed_list=0
log_duration="1h"
spaceused_rows=10
spaceused_depth=3
spaceused_path="$HOME"
receipt_path="/var/db/receipts"
power_sample_secs=30
cache_path="/Library/Caches"
logs_path="/Library/Logs"
doc_revision_path="/System/Volumes/Data/.DocumentRevisions-V100"
aul_p1="/var/db/diagnostics/"
aul_p2="/var/db/uuidtext"
ld_path="/Library/LaunchDaemons"
la_path="/Library/LaunchAgents"
launchctl_domains="system user/`id -u` gui/`id -u`"

# default kill list
#
# Note: these items in the kill list are pigs that we can't get rid of w/ out 
# doing risky things like deleting or moving files in root '/' partition to 
# get rid of the corresponding launchctl plist files. The only thing you can 
# do is kill these hogs every few minutes w/ cron job.
kill_list="mediaanalysisd mediaanalysisd-access photoanalysisd photolibraryd cloudphotod Stocks StocksKitService StocksWidget StocksDetailIntents com.apple.Photos.Migration siriactionsd sirittsd ShortcutsViewService"

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
  -a <arg>          ---> arguments for commands like bundle|kill|app|procinfo|verify|log|kext|user etc.
  -k                ---> enables writing $killed_list_file showing what was killed 
                         [note: the file may grow to large size]
  -v                ---> enable verbose, otherwise just errors are printed
  -h                ---> print usage/help
  -M                ---> info on all commands, somewhat like unix manpage
NOTE: For commands requiring args add -h after the command to see command specific usage.

Examples: 
  $my_name -c app -h
  $my_name -c mem,vmstat,cpu
  $my_name -c "user,disk"

Supported commands: 
$(echo -e $supported_commands)

See also: process.sh network.sh security.sh

EOF
  exit 0
}

man_page() {
  log.stat "---------- Summary of all supported commands ---------- "
  log.stat "Command     Description" $cyan
  cat << EOF
airplay     Show airplay devices
app         Show all running app with great details
arch        Show system architecture i.e. Intel or Apple Silion
battery     Show battery status, charging, status, how long on battery etc
bta         Lists everything about blutooth and devices connected
btc         Lists bluetooth macaddress, chipset, status etc
bundle      Show the bundle name of an Apple distributed application
cleanup     Removes unneded logs, cache etc to reclaim space
cpu         Show hardware info, model, make, processor, firmware version etc.
cputemp     Shows cpu temperature
disk        Show disk size, usage, automount volume etc
fan         Show fanspeed in rpm
ftype       Show file type
hw          Show mac model,processor serial memory etc
kext        Show all kernel Extention stats (excluding OS built-in)
kill        Kill applications (default list) or specific apps.
kmutil      Show kernel extenstions loaded and/or failed
la          List LaunchAgent task details
labom       list macOS distributed apps BOM list app location
ld          List LaunchDaemons task details
log         Search for string in system log
mdm         Show MDM enrollment
mem         Show physical memory, free memory, memory slots, size etc.
monitor     Monitor netowrk,fs, disk, file desc etc continually (ctrl+c to stop)
orphan      Check orphaned container space to cleanup after app is deleted.
pids        Show all running app/bundle name and corresponding pids
power       Show top 10 power hungry apps in a duration of 30secs
procinfo    Show detailed process context given a pid
serial      Show serial number
sl          Show spotlight status
disablesl   disable spotlight
enablesl    enable spotlight
showmounts  show all the external drives mounted under /Volume and their size
spaceused   Show space usage of top 10 directory (takes a while to run)
speed       Runs a internet speed test using macos provided testing tool
swap        Show current swap mode, usage etc
sysext      Show availabe system extenstions installed/activated etc
system      Show similar to version also user, SIP status, uptime etc.
usb         Lists all the USB hub, devices, controllers etc
user        Show current user details
users       Show all user details
verify      Verify if the app is macOS distributed, signed etc
version     Show OS version, product codename, build etc.
vmstat      Show free, active inactive, speculative, wired, and many other memory stats
volume      Display/set speaker volumen level
wifi        Show all wifi device information, channel, mode etc

NOTE: Many commands take additional arg with '-a'. To get the syntax of how 
it works, run wit a -h which will show details on what to pass for arg.
  example: sudo macos.sh -cmonitor -h
EOF
  exit 0
}

showmem() {
  hwmemsize=$(sysctl -n hw.memsize)
  ramsize=$(expr $hwmemsize / $((1024**3)))
  free_percent=$(memory_pressure|grep percentage|awk '{print $5;}')
  log.stat "  Physical Memory: ${ramsize}GB" $green
  log.stat "  Free Memory    : ${free_percent}" $green
  system_profiler SPMemoryDataType |awk '!/Memory:|Memory Slots:/'
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

do_volume() {
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
  log.stat "Storage type details:"
  system_profiler SPStorageDataType SPNetworkVolumeDataType
  local df_output=`df -h /System/Volumes/Data/|tail -1`
  
  log.stat "Overall Disk Usage:"
  log.stat "`echo $df_output|awk '{print "  Total: ",$2,"\n  Used:  ",$3,"(",$5,")","\n  Free:  ",$4,"\n  Inode: ",$8, "(metadata)"}'`"
  log.stat "\nNote: If inode usage reaches 100% you can't create files even if you have ton of free space."
  log.stat "      If it is large, typically, it is indicative of millions of tiny files."
}

showbundle () {
  if [ $command_help -eq 1 ] ||  [ -z "$arg" ]  ; then
    log.stat "Usage: $my_name -c bundle -a textedit  # this example shows details of textedit" $black
    exit 1
  fi
  local cmd="osascript -e 'id of app \"$arg\"'"
  log.stat "  Bundle ID: `eval $cmd`" $green
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
  log.stat "Spotlight status:" 
  mdutil -as
  if [ -d "$spotlight_data_path" ] ; then
    log.stat "Spotlight system space: $(space_used $spotlight_data_path)"
  fi
  if [ -d "${HOME}/Library/Metadata/CoreSpotlight" ] ; then
    log.stat "Spotlight user space: $(space_used ${HOME}/Library/Metadata/CoreSpotlight)"
  fi
}

disablespotlight() {
  check_root  
  log.stat "Disabling Spotlight completely!"
  log.stat "  Spotlight system space reclaimed: $(space_used $spotlight_data_path)"
  log.stat "  Spotlight user space reclaimed:   $(space_used ${HOME}/Library/Metadata/CoreSpotlight)"
  mdutil -adE -i off >> $my_logfile 2>&1
  # on reboot this gets enabled on reboot though the -a above should disable all... so force again
  mdutil -i off $spotlight_volume >> $my_logfile 2>&1
  rm -rf $spotlight_data_path
  rm -rf "${HOME}/Library/Metadata/CoreSpotlight"
}

enablespotlight() {
  check_root  
  log.stat "Enabling Spotlight for $spotlight_volume"
  mdutil -adE -i off >> $my_logfile 2>&1
  rm -rf $spotlight_data_path
  rm -rf "${HOME}/Library/Metadata/CoreSpotlight"
  mdutil -i on $spotlight_volume >> $my_logfile 2>&1
  log.stat "mds will now start indexing, be paitent for it to complete"
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
  log.stat "\tName:     $os_name"
  log.stat "\tVendor:   $(os_vendor)"
  log.stat "\tCodeName: $(os_code_name)"
  log.stat "\tVersion:  $(os_version)"
  log.stat "\tKernel:   $(os_kernel)"
  log.stat "\tBuild:    $(os_build)"
}

id2model() {
  local id="$1"

  case "$id" in
    # iMac
    iMac4,* ) echo "Intel Core Duo | 2006" ;;
    iMac5,* ) echo "Core 2 Duo | 2006-2007" ;;
    iMac7,* ) echo "Aluminum (Santa Rosa) | 2007" ;;
    iMac8,* ) echo "Penryn | 2008" ;;
    iMac9,* ) echo "Early Nehalem | 2009" ;;
    iMac10,* ) echo "Late 2009 | 2009" ;;
    iMac11,* ) echo "Nehalem/Westmere | 2010" ;;
    iMac12,* ) echo "Sandy Bridge | 2011" ;;
    iMac13,* ) echo "Ivy Bridge | 2012-2013" ;;
    iMac14,* ) echo "Haswell | 2013-2014" ;;
    iMac15,* ) echo "Broadwell (Retina 5K) | 2014-2015" ;;
    iMac16,* ) echo "Skylake | 2015" ;;
    iMac17,1 ) echo "Skylake (5K) | 2015" ;;
    iMac18,* ) echo "Kaby Lake | 2017" ;;
    iMac19,* ) echo "Coffee Lake | 2019" ;;
    iMac20,* ) echo "Comet Lake | 2020" ;;
    iMac21,* ) echo "Apple M1 | 2021" ;;
    iMac22,* ) echo "Apple M3 | 2023" ;;

    # MacBook Pro
    MacBookPro1,* ) echo "Core Duo | 2006" ;;
    MacBookPro2,* ) echo "Core 2 Duo | 2006" ;;
    MacBookPro3,* ) echo "Santa Rosa | 2007" ;;
    MacBookPro4,* ) echo "Penryn | 2008" ;;
    MacBookPro5,* ) echo "Unibody | 2008-2009" ;;
    MacBookPro6,* ) echo "Arrandale | 2010" ;;
    MacBookPro8,* ) echo "Sandy Bridge | 2011" ;;
    MacBookPro9,* ) echo "Ivy Bridge | 2012" ;;
    MacBookPro10,* ) echo "Retina (Ivy/Haswell) | 2012-2013" ;;
    MacBookPro11,* ) echo "Haswell | 2013-2014" ;;
    MacBookPro12,1 ) echo "Broadwell | 2015" ;;
    MacBookPro13,* ) echo "Skylake/Kaby Lake (Touch Bar) | 2016" ;;
    MacBookPro14,* ) echo "Kaby Lake | 2017" ;;
    MacBookPro15,* ) echo "Coffee Lake | 2018-2019" ;;
    MacBookPro16,* ) echo "Coffee Lake/Comet Lake | 2019" ;;
    MacBookPro17,1 ) echo "Apple M1 | 2020" ;;
    MacBookPro18,* ) echo "Apple M1 Pro/Max | 2021" ;;
    Mac14,8 ) echo "Apple M3 | 2023" ;;
    Mac14,9 ) echo "Apple M3 Pro | 2023" ;;
    Mac14,10 ) echo "Apple M3 Max | 2023" ;;
    Mac15,* ) echo "Apple M4 family | 2024-2025" ;;

    # MacBook Air
    MacBookAir1,1 ) echo "Core 2 Duo | 2008" ;;
    MacBookAir2,1 ) echo "Core 2 Duo | 2009" ;;
    MacBookAir3,* ) echo "Arrandale | 2010" ;;
    MacBookAir4,* ) echo "Sandy Bridge | 2011" ;;
    MacBookAir5,* ) echo "Ivy Bridge | 2012" ;;
    MacBookAir6,* ) echo "Haswell | 2013-2014" ;;
    MacBookAir7,* ) echo "Broadwell | 2015-2017" ;;
    MacBookAir8,1 ) echo "Retina (Amber Lake) | 2018" ;;
    MacBookAir9,1 ) echo "Ice Lake | 2020" ;;
    MacBookAir10,1 ) echo "Apple M1 | 2020" ;;
    MacBookAir15,2 ) echo "Apple M2 | 2022" ;;
    Mac14,7 ) echo "Apple M2 (15-inch) | 2023" ;;
    Mac15,* ) echo "Apple M3/M4 | 2024-2025" ;;

    # Mac mini
    Macmini1,1 ) echo "Core Duo | 2006" ;;
    Macmini2,1 ) echo "Core 2 Duo | 2007" ;;
    Macmini3,1 ) echo "Core 2 Duo | 2009" ;;
    Macmini4,1 ) echo "Core 2 Duo | 2010" ;;
    Macmini5,* ) echo "Sandy Bridge | 2011" ;;
    Macmini6,* ) echo "Ivy Bridge | 2012" ;;
    Macmini7,1 ) echo "Haswell | 2014" ;;
    Macmini8,1 ) echo "Coffee Lake | 2018" ;;
    Macmini9,1 ) echo "Apple M1 | 2020" ;;
    Mac14,1 ) echo "Apple M2 | 2023" ;;
    Mac14,2 ) echo "Apple M2 Pro | 2023" ;;
    Mac14,3 ) echo "Apple M2 Pro (alt) | 2023" ;;
    Mac15,* ) echo "Apple M3/M4 | 2024-2025" ;;

    # Mac Studio
    Mac13,1 ) echo "Apple M1 Max | 2022" ;;
    Mac13,2 ) echo "Apple M1 Ultra | 2022" ;;
    Mac14,5 ) echo "Apple M2 Max | 2023" ;;
    Mac14,6 ) echo "Apple M2 Ultra | 2023" ;;
    Mac15,* ) echo "Apple M3/M4 | 2024-2025" ;;

    # Mac Pro
    MacPro1,1 ) echo "Xeon Woodcrest | 2006" ;;
    MacPro2,1 ) echo "Xeon Clovertown | 2007" ;;
    MacPro3,1 ) echo "Xeon Harpertown | 2008" ;;
    MacPro4,1 ) echo "Xeon Nehalem | 2009" ;;
    MacPro5,1 ) echo "Xeon Westmere | 2010-2012" ;;
    MacPro6,1 ) echo "Xeon Ivy Bridge (trash can) | 2013" ;;
    MacPro7,1 ) echo "Xeon W Cascade Lake | 2019" ;;
    MacPro8,1 ) echo "Apple M2 Ultra | 2023" ;;

    # MacBook (non‑Air/Pro)
    MacBook1,1 ) echo "Core Duo | 2006" ;;
    MacBook2,1 ) echo "Core 2 Duo | 2006-2007" ;;
    MacBook3,1 ) echo "Santa Rosa | 2007" ;;
    MacBook4,1 ) echo "Penryn | 2008" ;;
    MacBook5,* ) echo "Unibody | 2008-2009" ;;
    MacBook6,1 ) echo "Core 2 Duo | 2009" ;;
    MacBook7,1 ) echo "Core 2 Duo | 2010" ;;
    MacBook8,1 ) echo "12-inch Retina (Broadwell) | 2015" ;;
    MacBook9,1 ) echo "12-inch Retina (Skylake) | 2016" ;;
    MacBook10,1 ) echo "12-inch Retina (Kaby Lake) | 2017" ;;
    * ) echo "Unknown | Unknown" ;;
  esac
}

show_system() {
  local id=`system_profiler SPHardwareDataType|grep "Model Identifier"|awk '{print $3}'`
  log.stat "      Model Year: $(id2model $id)"
  log.stat "`system_profiler SPHardwareDataType | tail +5`"
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

check_brew() {
  if [ `which otool` ]; then
    # use otool
    otool -L $arg |egrep '/opt/homebrew|/usr/local/' 2>&1 >/dev/null
    if [ $? -eq 0 ] ; then
      log.stat "This binary is installed by brew package manager." $cyan
    else
      log.error "This binary is unknown origin, not macOS distribution or brew package manager"
    fi
  else
    if [[ "$arg" == *"/opt/homebrew"* || "$arg" == *"/usr/local/"* ]]; then
      log.stat "This binary is likely installed by brew package manager." $cyan
    else
      log.error "This binary is unknown origin, not macOS distribution or brew package manager"      
    fi
  fi
}

verify_code() {
  if [ $command_help -eq 1 ] ||  [ -z "$arg" ]  ; then
    log.stat "Usage: $my_name -c verify -a /sbin/disklabel  # check binary origin and if signed or not" $black
    exit 1
  fi

  log.stat "Verifying: $arg ..."
  # check if this is an exectutable
  if [ ! -x "$arg" ] || [ -d "$arg" ] ; then
    log.error "This is not an executable!"
    return
  fi
  
  codesign -d --verbose=2 $arg 2>&1 |grep "Apple Root CA"
  if [ $? -ne 0 ]; then
    check_brew
  else
      log.stat "This binary is macOS installed and managed" $green
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
  if [ $command_help -eq 1 ] ; then
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

list_user_details() {
  local u=$1
  log.stat "  Username:  $u"
  log.stat "  Full Name:`dscl . -read /Users/$u RealName|tail -1`"
  log.stat "  `dscl  . -read /Users/$u NFSHomeDirectory`"
  log.stat "  `dscl . -read /Users/$u UniqueID`"
  log.stat "  `dscl . -read /Users/$u PrimaryGroupID`"
  log.stat "  Is user admin?: `dsmemberutil checkmembership -U $u -G admin`"
}

do_user() {
  if [ $command_help -eq 1 ] ; then
    log.stat "Usage: $my_name -c$command_name   # show details of the user running the script" $black
    log.stat "Usage: $my_name -c$command_name -a bob  # show details of the user bob" $black
    exit 1
  fi

  local u=$USER
  if [ ! -z "$arg" ] ; then
    u=$arg
    # validate user
    if ! dscl . -read /Users/$u &>/dev/null; then
      log.error "$u: is not a valid user!"
      exit 5
    fi
  fi

  list_user_details $u
}

do_users() {
  dscl . -list /Users UniqueID | awk '$2 >= 501 {print $1}' | while read u; do
    list_user_details $u
    log.stat ""
  done
}

do_kext() {
 if [ $command_help -eq 1 ] ; then
    log.stat "Usage: $my_name -c $command_name [-a com.apple.driver.watchdog]  # kext stats for all or bundle id"
    exit 1
  fi
  
  # if arg provided just do kextstat for the bundle arg
  if [ -z "$arg" ] ; then
    log.stat "ALL Kernel Extention stats (excluding OS built-in)"
    kextstat -lk 2>/dev/null
  else
    log.stat "Kernel Extention stats for bundle: $arg"
    kextstat -b $arg 2>/dev/null
  fi
}

do_kmutil() {
  log.stat "All from system_profiler"
  system_profiler -json SPExtensionsDataType -detailLevel full | jq -r '.SPExtensionsDataType[] 
  | select(.spext_loaded == "spext_yes") 
  | "Name: \(.["_name"])\nBundle ID: \(.spext_bundleid)\nPath: \(.spext_path)\nSource: \(.spext_signed_by)\n"'
  
  log.stat "Loaded kernel modules:"
  kmutil check 2>&1|grep "Loaded extension" |awk '{print $4,$5}'

  log.warn "Failed modules:"
  kmutil check 2>&1|grep "Could not" |awk '{print $4,$5}'
 
}

do_power() {
  if [ $command_help -eq 1 ] ; then
    log.stat "Usage: $my_name -c $command_name [-a 60]  # sample power usage for 60sec"
    exit 1
  fi
  if [ ! -z "$arg" ] ; then
    power_sample_secs=$arg
  fi
  local awk_arg="/PID/{p=1; c++} p && c==$power_sample_secs"
  log.stat "List of top 10 apps consuming power below... Please wait $power_sample_secs seconds"
  top -l$power_sample_secs -s1 -o power -stats pid,command,power -n12 | awk "${awk_arg}" |egrep -v 'top|kernel_task'
}

# remove logs, cache, doc revision, spotlight etc
do_cleanup() {
  local tsize=0

  if [ $command_help -eq 1 ] ; then
    log.stat "Usage: $my_name -c $command_name  # cleanup log, cache spotlight & misl stuff"
    exit 1
  fi
  check_root
  
  # estimate size of potential cleanup items
  log.stat "Type: User Space"
  dscl . -list /Users UniqueID | awk '$2 >= 501 {print $1}' | while read u; do
    log.stat "  User: $u"
    home=$(dscl . read /Users/$u NFSHomeDirectory 2>/dev/null | awk '{print $2}')

    if [ -d "$home/$cache_path" ] ; then
      tsize=$((tsize + `du -I private -sk $home/$cache_path 2>/dev/null|awk '{print $1}'`))
      log.stat "    Cache: $(space_used "$home/$cache_path")"
    else
      log.stat "    Cache: N/A"
    fi
    if [ -d "$home/$logs_path" ] ; then
      tsize=$((tsize + `du -I private -sk $home/$logs_path 2>/dev/null|awk '{print $1}'`))
      log.stat "    Log:   $(space_used "$home/$logs_path")"
    else
      log.stat "    Log: N/A"
    fi
  done

  log.stat "Type: System Space"
  if [ -d "$cache_path" ] ; then
    tsize=$((tsize + `du -I private -sk $cache_path 2>/dev/null|awk '{print $1}'`))
  fi
  log.stat "  Cache: $(space_used $cache_path)"
  if [ -d "$logs_path" ] ; then
    tsize=$((tsize + `du -I private -sk $logs_path 2>/dev/null|awk '{print $1}'`))
  fi
  log.stat "  Log:   $(space_used $logs_path)"

  log.stat "Type: Spotlight Space"
  if [ -d "$spotlight_data_path" ] ; then
    tsize=$((tsize + `du -I private -sk $spotlight_data_path 2>/dev/null|awk '{print $1}'`))
  fi
  log.stat "  Used: $(space_used $spotlight_data_path)"

  log.stat "Type: Document Revisions Space"
  if [ -d "$doc_revision_path" ] ; then
    tsize=$((tsize + `du -I private -sk $doc_revision_path 2>/dev/null|awk '{print $1}'`))
  fi
  log.stat "  Used: $(space_used $doc_revision_path)"
  
  log.stat "Type: Apple Unified Log (AUL)"
  if [ -d "$aul_p1" ] ; then
    tsize=$((tsize + `du -I private -sk $aul_p1 2>/dev/null|awk '{print $1}'`))
    log.stat "  Used (diagnostic): $(space_used $aul_p1)"
  fi
  if [ -d "$aul_p2" ] ; then
    tsize=$((tsize + `du -I private -sk $aul_p2 2>/dev/null|awk '{print $1}'`))
    log.stat "  Used (uuidtext): $(space_used $aul_p2)"
  fi

  log.stat "Type: /var/folders"
  log.stat "  Used: $(space_used "/var/folders")"
  log.warn "Note: /var/folders size is information only, if it is excessive, reboot to reduce.\n"

  # convert tsize from KB to GB
  tsize=$(echo "scale=2; $tsize / (1024 * 1024)" | bc)
  log.stat "Total space can be reclaimed: $tsize GB\n"
  
  # check with user
  confirm_action "WARNING: All spaces listed above except /var/folders will be wiped."
  if [ $? -eq 0 ] ; then
    log.warn "skipping cleanup"
    exit 10
  fi

  # remove all the spaces
  log.stat "Removing everying listed above..."
  dscl . -list /Users UniqueID | awk '$2 >= 501 {print $1}' | while read u; do
    home=$(dscl . read /Users/$u NFSHomeDirectory 2>/dev/null | awk '{print $2}')
    log.stat "Removing cache/logs for user $u"
    if [ -d "${home}/${cache_path}" ]; then
      rm -rf ${home}/${cache_path}/*  >> $my_logfile  2>&1
    fi
    if [ -d "${home}/${logs_path}" ] ; then
      rm -rf ${home}/${logs_path}/*  >> $my_logfile  2>&1
    fi
  done

  # system space
  log.stat "Removing system cache/logs ..."  
  if [ ! -z "$cache_path" ] && [ -d $cache_path ] ; then
    rm -rf ${cache_path}/* >> $my_logfile  2>&1
  fi
  if [ ! -z "$logs_path" ] && [ -d $logs_path ] ; then
    rm -rf ${logs_path}/* >> $my_logfile  2>&1
  fi

  # spotlight space
  if [ ! -z "$spotlight_data_path" ] && [ -d $spotlight_data_path ] ; then
    log.stat "Disabling spotlight to remove spotlight data. Enable if you need it"
    mdutil -a -i off >> $my_logfile 2>&1
    # on reboot $spotlight_volume gets enabled though the -a above should disable all...so force again
    mdutil -i off $spotlight_volume >> $my_logfile 2>&1
    log.stat "Removing spotlight space..."
    rm -rf ${spotlight_data_path}/*
  fi

  # revision space
  if [ -d $doc_revision_path ] ; then
    log.stat "Removing revision space..."
    rm -rf ${doc_revision_path}/*
  fi

  # log space
  log.stat "Purging Apple Unified Logs (AUL) ..."
  confirm_action "WARNING: Purging AUL requires reboot."
  if [ $? -eq 0 ] ; then
    log.warn "Skiping AUL purge."
  else
    log.stat "Removing AUL logs ..."
    log erase --all >> $my_logfile 2>&1
    if [ -d "$aul_p1" ] ; then
      rm -rf ${aul_p1}/*
    fi
    if [ -d "$aul_p2" ] ; then
      rm -rf ${aul_p2}/*
    fi
  fi

  log.stat "All cleanup done." 
  log.warn "Note: If you purged, AUL, you must reboot now to get logs working!"
}

do_usb() {
  log.stat "\nUSB Data type"
  system_profiler SPUSBDataType | awk '!/USB:/'

  log.stat "\nUSB Devices"
  hidutil list --matching '{"Transport":"USB"}' | awk '/Devices:/ {show=1;next} show'

  log.stat "\nUSB Mass storage (if any)"
  ioreg -p IOUSB -c IOUSBHostDevice
}

do_wifi() {
  check_root
  log.stat "Wi-Fi Hardware details"
  system_profiler SPAirPortDataType -detailLevel mini
  
  log.stat "\nWi-Fi Connection details"
  sudo wdutil info | sed -n '/^WIFI$/,+30p'
}

do_monitor() {
  check_root

  if [ $command_help -eq 1 ] ; then
    log.stat "Usage: $my_name -c $command_name [-a <command>|<pid>]"
    log.stat "Example(s):"
    log.stat "  $my_name -c $command_name                # monitor all applications"
    log.stat "  $my_name -c $command_name -a \"WhatsApp\"  # monitor just whatsapp"
    exit 1
  fi

  log.stat "What would you like to monitor?"
  local choice=$(select_option "network filesys diskio pathname exec")
  
  log.stat "Running fs_usage monitor $choice, press Ctrl+C to exit..."
  if [ "$choice" = "invalid" ] ; then
    log.stat "Monitoring everything ..."
    fs_usage $arg
  else
    log.stat "Monitoring $choice ..."
    fs_usage -f $choice $arg
  fi
}

do_battery() {
  log.stat "Battery Status:"
  local src=$(pmset -g batt | awk -F"'" '/drawing from/ {print $2}')
  log.stat "  Power Source: $src" 
  
  local line=$(pmset -g batt | awk '/InternalBattery/')
  # if this is a iMac or other device with no battery present, this 'line' will be empty
  if [ -z "$line" ] ; then
    return
  fi
  log.stat "  Battery Level: `echo "$line" | grep -o '[0-9]\+%'`"
  log.stat "  Charger: `echo "$line" | awk -F';' '{print $2}'`"
  log.stat "  Charging: `echo "$line" | awk -F';' '{print $3}' | awk '{print $1,$2}'`"
  log.stat "  Battery Present: `echo "$line" | awk '{print $NF}'`"

  local last=$(pmset -g log | grep "Using Batt" | tail -n1 | awk '{print $1 " " $2 " " $3}') 
  local elapsed=$(( $(date +%s) - $(date -j -f "%Y-%m-%d %H:%M:%S %z" "$last" +%s) )) 
  local s=$(printf "%02d:%02d:%02d\n" $((elapsed/3600)) $((elapsed%3600/60)) $((elapsed%60)))
  log.stat "  On battery: $s (HH:MM:SS)"
}

do_airplay() {
  if [ ! -z "$arg" ] ; then
    log.stat "Details of airplay device $arg ..."
    dns-sd -L "$arg" _airplay._tcp
  else
    log.stat "Showing airplay devices..."
    dns-sd -B _airplay._tcp
  fi
}

do_fan() {
  # only for intel mac
  if [ $(macos_arch) == "Intel" ] ; then
    check_root
    log.stat "  `sudo powermetrics -i1 -n1  -ssmc|grep ^Fan`"
  else
    log.error "Fan access is not availabe in Apple Silicon based processors!"
  fi
}

do_orphan() {
  local tsize=0
  local csize=0
  local sample=""

  if [ $command_help -eq 1 ] ; then
    log.stat "Usage: $my_name -c $command_name [-a <user>]"
    log.stat "Example(s):"
    log.stat "  $my_name -c $command_name                 # check orphaned container space for current user"
    log.stat "  sudo $my_name -c $command_name -a <user>  # check orphaned container space any user"
    exit 1
  fi
  local u=$USER
  if [ ! -z "$arg" ] ; then
    check_root
    u=$arg
  fi
  
  log.stat "List of orphaned container space & potential space savings"
  local base="/Users/$u/Library/Containers"
  log.stat "Container Path: $base"
  
  for c in "$base"/*; do
    # Skip Apple containers
    [[ "$(basename "$c")" == com.apple.* ]] && continue

    log.debug "Checking container: $c"
    local plist="$c/Container.plist"
    [[ ! -f "$plist" ]] && continue
   
    # Extract *all* occurrences of application_bundle values
    # plutil -p prints JSON-like output; grep filters; sed extracts the value
    local bundles
    bundles=$(plutil -p "$plist" 2>/dev/null \
      | grep '"application_bundle"' \
      | sed -E 's/.*"application_bundle" => "(.*)"/\1/')

    # If no application_bundle key exists, skip (likely helper/agent)
    [[ -z "$bundles" ]] && continue

    # Check each bundle path found
    local orphan=true
    while IFS= read -r path; do
      if [[ -e "$path" ]]; then
        orphan=false
        break
      fi
    done <<< "$bundles"

    if $orphan; then
      tsize=$((tsize + `du -sk $c 2>/dev/null|awk '{print $1}'`))
      csize=`du -sh $c|awk '{print $1}'`
      log.stat "  $(basename "$c") ---> $csize"
      sample=$c
    fi
  done
  
  # print the details only if we found at least one item
  if [ ! -z "$sample" ] ; then
    # convert tsize from KB to GB
    tsize=$(echo "scale=2; $tsize / (1024 * 1024)" | bc)
    log.stat "Total space can be reclaimed: $tsize GB\n" $cyan
    log.warn "NOTE: This script will not delete these entries as some apps make things complicated"
    log.warn "  by renaming location ex: /Applications/OneDrive.localized/ while the plist points "
    log.warn "  non-existent path so the script can't determine accuratly if they are orphaned or "
    log.warn "  not. You have to manually examine each entry and delete them as per your needs.\n"
    log.stat "If you are confident, these are orphaned you can remove them maually as shown below"
    log.stat "  example: rm -rf $sample"
  else
    log.stat "No orphaned app containers is found!"
  fi
}

list_launchctl_items() {
  local plist_path=$1
  local label=""

  for pl in $plist_path/*.plist ; do

    if ! label=$(plutil -extract Label raw "$pl" 2>/dev/null) ; then
      label=$(basename "$pl" .plist)
    fi

    # Probe system, user, and gui domains
    for domain in $launchctl_domains ; do
      if launchctl print "$domain/$label" >/dev/null 2>&1 ; then
        log.stat "  Service: $label"
        log.stat "    Domain: $domain"
        # check if it is loaded
        launchctl list |grep $label >/dev/null 2>&1
        if [ $? -eq 0 ] ; then
          log.stat "    Loaded: Yes"
        else
          log.stat "    Loaded: No"
        fi
        local active_flag=$(sudo sfltool dumpbtm | grep -A 15 "$label" | awk -F'[()]' '/Disposition/ {print $2}'|head -n1)
        if (( (active_flag & 2) != 0 )) ; then
          log.stat "    Active: Yes"
        else
          log.stat "    Active: No"
        fi
        break
      fi
    done
  done

}

do_ld() {
  check_root
  log.stat "Launch Daemon Services: $ld_path"
  list_launchctl_items $ld_path
}

do_la() {
  # /Library/LaunchAgents
  log.stat "Launch Agent Services: $la_path [NOTE: need to provide sudo password]"
  list_launchctl_items $la_path

  # $HOME/Library/LaunchAgents
  log.stat "Launch Agent Services: ${HOME}/$la_path"
  list_launchctl_items ${HOME}/$la_path
  
}

do_mdm() {
  log.stat "Mobile Device Management info"
  profiles status -type enrollment
}

do_ftype() {
 if [ $command_help -eq 1 ] ; then
    log.stat "Usage: $my_name -c $command_name -a <filename>"
    exit 1
  fi
  if [ -z "$arg" ] ; then
    log.error "missing required filename argument!"
    exit
  fi
  if [ -d "$arg" ]; then
    log.error "${arg} is a directory, filename expected!"
    exit
  fi
  
  log.stat "\tName: $arg" $green
  log.stat "\tType: `file_type "$arg"`" $green
  log.stat "\tContent: `file_content \"$arg\"`" $green
  if is_media "$arg" ; then
    log.stat "\tMedia?: YES" $green
  else
    log.stat "\tMedia?: NO" $green
  fi
  log.stat "\tFlags: `ls -lO "$arg" |awk '{print $5}'`" $green
  local exatt=$(xattr -l "$arg")
  if [ ! -z "$exatt" ]; then
    log.stat "\tExtended: `echo $exatt|tr -d '\n'`" $green
  fi
}

do_showmounts() {
  log.stat "List of mounted external drives"
  for mp in `mount|awk '{print $3}'|grep '^/Volumes'` ; do 
    log.stat "Mount Point: $mp"
    df -h $mp |awk 'NR >1 {print "   Size:",$2,"\n  ","Used:",$3,"\n  ","Free: ",$4}'
  done
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

# enforce we are running macOS
check_mac

trap signal_handler SIGINT

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
    M)
      man_page
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

# Command possibly may have multiple entries separated by ',' so loop through and 
# execute all of them
IFS=',' read -ra commands <<< "$command_name"
for item in "${commands[@]}"; do
  cmd=$(echo "$item" | xargs)
  case $cmd in 
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
      show_system
      ;;
    serial)
      ioreg -c IOPlatformExpertDevice -d 2 | awk -F\" '/IOPlatformSerialNumber/{print $(NF-1)}'  
      ;;
    volume)
      do_volume  
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
    sl)
      showspotlight
      ;;
    disablesl)
      disablespotlight
      ;;
    enablesl)
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
    kext)
      do_kext
      ;;
    kmutil)
      do_kmutil
      ;;
    lsbom)
      do_lsbom
      ;;
    user)
      do_user
      ;;
    users)
      do_users
      ;;
    power)
      do_power
      ;;
    cleanup)
      do_cleanup
      ;;
    usb)
      do_usb
      ;;
    btc)
      system_profiler SPBluetoothDataType  | awk '/Not Connected/ {exit} {print}'
      ;;
    bta)
      system_profiler SPBluetoothDataType
      ;;
    hw)
      system_profiler SPHardwareDataType
      ;;
    wifi)
      do_wifi
      ;;
    monitor)
      do_monitor
      ;;
    battery)
      do_battery
      ;;
    airplay)
      do_airplay
      ;;
    fan)
      do_fan
      ;;
    orphan)
      do_orphan
      ;;
    la)
      do_la
      ;;
    ld)
      do_ld
      ;;
    mdm)
      do_mdm
      ;;
    ftype)
      do_ftype
      ;;
    showmounts)
      do_showmounts
      ;;
    *)
      log.error "Invalid command: $command_name"
      log.stat "Available commands: $supported_commands"
      exit 1
      ;;
  esac
done
