#!/bin/bash
#
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
#

# version format YY.MM.DD
version=22.08.02
my_name="`basename $0`"
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
cmdline_args=`printf "%s " $@`

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="evh?"
verbose=0
enable_log=0
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

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -e  ---> enable logging back"
  echo "  -v  ---> verbose mode prints info messages, otherwise just errors are printed"
  echo "  -h  ---> print usage/help"
  echo ""
  echo "example: $my_name -h"
  echo ""
  exit 0
}

write_log() {
  local msg_type=$1
  local msg=$2

  # log info type only when verbose flag is set
  if [ "$msg_type" == "[INFO]" ] && [ $verbose -eq 0 ] ; then
    return
  fi

  echo "$msg_type $msg" | tee -a $log_file
}

init_log() {
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  write_log "[STAT]" "$my_version: starting at `date +'%m/%d/%y %r'` ..."
}

check_root() {
  if [ `id -u` -ne 0 ] ; then
    write_log "[ERROR]" "root access needed to run this script, run with 'sudo $my_name' ... exiting."
    exit
  fi
}

reset_logging() {
  write_log "[INFO]" "setting log level to '$log_level' for the list of subsystems ..."
  for ss in $subsystem_list ; do
    ss_name=$(echo $ss |awk -F: '{print $1}');
    cat_list=$(echo $ss|awk -F: '{print $2}'|sed "s/,/ /g");
    write_log "[INFO]" "subsystem: $ss_name, loglevel=$log_level"
    # if we are turninng off, just remove the file, no need to call log
    if [ $log_level = "info" ] ; then
      if [ -f $subsystem_settings_dir/$ss_name.plist ] ; then
        rm $subsystem_settings_dir/$ss_name.plist
      fi
      continue
    fi
    /usr/bin/log config --mode "level: $log_level" --subsystem $ss_name >> $log_file 2>&1
    for cat in $cat_list ; do
      write_log "[INFO]" "    subsystem/category: $ss_name:$cat, loglevel=$log_level"
      /usr/bin/log config --mode "level: $log_level" --subsystem $ss_name --category $cat >> $log_file 2>&1
    done
  done
}

# ----------  main --------------
init_log

# parse commandline options
while getopts $options opt; do
  case $opt in
    e)
      log_level="info"
      ;;
    v)
      verbose=1
      ;;
    ?)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

check_root

# confirm if no option 
write_log "[WARN]" "About to reset log level to '$log_level' ..."
read -p "Are you sure? (y/n) " -n 1 -r
echo 
if [[ $REPLY =~ ^[Yy]$ ]] ; then
  reset_logging
else
  write_log "[INFO]" "Exiting w/ out any change"
fi
