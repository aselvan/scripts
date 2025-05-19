#!/usr/bin/env bash
################################################################################
# logtune.sh --- supress chatty logs on MacOS to help reduce wasted CPU & IO
#
# The name of this script is a misnomer since it doesn't really tune anything rather 
# it just simply turns off/on the chatty loging subsystems on MacOS. There are ton of
# messages in memory & persisted totally useless messages like "application x" is 
# reading "propery y" who cares? Just run 'log stats --overview' and check how many 
# million messages are logged. For example, in my brandnew macbook air running just 3 
# days showed 14 million messages logged. The settings this script alters will be 
# found under "/Library/Preferences/Logging/Subsystems"
#
# I know some people may disagree w/ me saying logs should not be turned off and is 
# not going to make a difference etc, I would challenge them to show me when was the 
# last time they ever looked at logs on a macOS. Bottomeline is, I am a power user but 
# I dont give rats ass about useless logs apple decided to do by default especially,  
# debug level messages!
#
# Here is how I collected the list of subsystems spewing logs, I am sure there are better
# ways to do this, but this will do for now. I could filter only "Debug" messages but 
# like I said above, I dont' care :)
# 
# # collect log lines by streaming log for few hours like so below...
# timeout 3h log stream --debug |grep "\[com.*\]" >~/log.txt'
# # now filter all the com.* subsystems involved, sort it, get uniq counts and get the 
# # top 30 (ignore rest unless they are too much)
# cat ~/log.txt | awk '{if ( $8 ~ /com\./ ) {print $8} else if ( $9 ~ /com\./ ) {print $9} }'|sort|uniq -c|sort -nr|head -n30>subsystems.txt
#
# <Disclaimer> 
# This comes without warranty of any kind what so ever. You are free to use it at your own 
# risk. I assume no liability for the accuracy, correctness, and usefulness of this script 
# nor for any sort of damages using these scripts may cause.
#
# Author:  Arul Selvan
# Created: Aug 1, 2022
################################################################################
# Version History:
#   Aug 1,  2022 --- Original version
#   May 19, 2025 --- Use standard logging, option to view current setting
#################################################################################

# version format YY.MM.DD
version=25.05.19
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="View/change macOS log settings"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="l:svh?"

show_setting=0
log_level="off"
subsystem_settings_dir="/Library/Preferences/Logging/Subsystems"

# list of subsystems to turn off. This is by no means the full list but this should cover most 
# annoying log spews. note: the category is a comma separated list after the ':'.
subsystem_list="\
  com.apple.bluetooth \
  com.apple.CoreDisplay \
  com.apple.amp.mediaremote:MediaRemote \
  com.apple.symptomsd:analytics,attribution,metrics,flow \
  com.apple.defaults \
  com.apple.iconservices:default,trace \
  com.apple.CarbonCore:checkfix,coreservicesdaemon \
  com.apple.CFBundle:resources \
  com.apple.locationd.Core:Notifier \
  com.apple.locationd.Motion:AOP \
  com.apple.locationd.Position:GeneralCLX,Position \
  com.apple.locationd.Utility:Database \
  com.apple.locationd.Legacy:Generic_deprecated \
  com.apple.CoreAnalytics \
  com.apple.powerlog \
  com.apple.CoreBrightness \
  com.apple.CoreBrightness.CBHIDEventManager \
  com.apple.CoreBrightness.CBDisplayModuleSKL \
  com.apple.CoreBrightness.CBColorModule \
  com.apple.CoreBrightness.BrightnessSystemInternal \
  com.apple.CoreBrightness.CBALSEvent \
  com.apple.CoreBrightness.ColourSensorFilterPlugin \
  com.apple.spotlightserver \
  com.apple.useractivity:Diagnostic,main \
  com.apple.runningboard:process,assertion,monitor,connection \
  com.apple.sharing \
  com.apple.rapport \
  com.apple.networkusage:network-usage \
  com.apple.network:connection,boringssl \
  com.apple.chrono:clockDatePublisher \
  com.apple.watchdogd:service-monitoring-thread \
  com.apple.WiFiManager \
  com.apple.CoreUtils:CUBonjourBrowser,BonjourBrowser \
  com.apple.mDNSResponder:D2D \
  com.apple.opendirectoryd:session,object-lifetime,pipeline \
  com.apple.spotlightindex:Access \
  com.apple.launchservices:record \
  com.apple.FileURL:resolve com.apple.launchservices:record \
  com.apple.icloud.searchpartyd:beaconStore \
  com.apple.SkyLight:default \
  com.apple.iohid:ups,service,default,activity \
  com.apple.quicklook:cloudthumbnails.cache.sqlite,cloudthumbnails.cache.thread,cloudthumbnails.cache.memory,cloudthumbnails.cache.index,cloudthumbnails.cache.db.cleanup \
  com.apple.appkit.xpc.openAndSavePanelService:default \
  com.apple.VDCAssistant:device.usbclient,device.clientstream,device.frameaccumulator \
  com.apple.TCC:access \
  com.apple.DiskArbitration.diskarbitrationd:default \
  com.apple.distnoted:diagnostic \
  com.apple.amp.core:powermanagement \
  com.apple.controlcenter:battery \
  com.apple.SystemConfiguration:SCDynamicStore \
  com.apple.WirelessRadioManager.Coex:Trace,Public \
  com.apple.loginwindow.logging:Standard \
  com.apple.launchservices:cas \
  com.apple.HIToolbox:MBarView,MBDaisyFrame \
  com.apple.duetactivityscheduler:default,scoring,lifecycle(activityGroup) \
  com.apple.analyticsd:xpc,event \
"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -l <level>   ---> Level to change; valid levels are: off|default|info|debug
  -s           ---> show current settings on all subsystems
  -v           ---> enable verbose, otherwise just errors are printed
  -h           ---> print usage/help

example(s): 
  $my_name -l off
  $my_name -s
  
EOF
  exit 0
}

change_level() {
  check_root
  confirm_action "About to reset log level to '$log_level' ..."
  if [ $? -eq 0 ] ; then
    log.stat "No changes done, exiting"
    exit 0
  fi

  log.stat "Changing log level to '$log_level' for the list of subsystems (Dir: $subsystem_settings_dir)"
  for ss in $subsystem_list ; do
    ss_name=$(echo $ss |awk -F: '{print $1}');
    cat_list=$(echo $ss|awk -F: '{print $2}'|sed "s/,/ /g");
    log.stat "  subsystem: $ss_name, loglevel=$log_level"
    log config --mode "level: $log_level" --subsystem $ss_name >> $my_logfile 2>&1
    for cat in $cat_list ; do
      log.stat "    subsystem/category: $ss_name:$cat, loglevel=$log_level"
      log config --mode "level: $log_level" --subsystem $ss_name --category $cat >> $my_logfile 2>&1
    done
  done
  exit 0
}

show_level() {
  check_root
  log.stat "Showing log settings for all subsystems (Dir: $subsystem_settings_dir)"
  for ss in $subsystem_list ; do
    ss_name=$(echo $ss |awk -F: '{print $1}');
    cat_list=$(echo $ss|awk -F: '{print $2}'|sed "s/,/ /g");    
    log.stat "subsystem: $ss_name"
    log.stat "  `log config --subsystem $ss_name --status`" $grey
    for cat in $cat_list ; do
      log.stat "  `log config --subsystem $ss_name --category $cat --status`" $grey
    done
  done
  exit 0
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
while getopts $options opt; do
  case $opt in
    l)
      log_level="$OPTARG"
      change_level
      ;;
    s)
      show_level
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

usage
