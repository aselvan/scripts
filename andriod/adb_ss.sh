#!/bin/bash
#
# adb_ss.sh --- simple wrapper script to capture screen[shot|recording] from your phone
#               to the host computer via adb (usb or wifi). Note: if scrcpy is installed
#               video recording will be done with it, otherwise adb command is used.
#
# See also: adb_wifi.sh, remove_bloatware.sh etc.
#
#
# Author:  Arul Selvan
# Version: Jun 6, 2023
#
# version format YY.MM.DD
version=23.06.06
my_name="`basename $0`"
my_version="`basename $0` v$version"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options_list="s:f:crh?"
output_file_prefix="/tmp/$(echo $my_name|cut -d. -f1)"
output_file=""
device=""
video_bitrate="64m"
video_format="h264"
video_length=30
video_size_scrcpy=768
video_size_adb="540x960"
# 0=screenshot 1=video record
ss_type=0
# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"


usage() {
  cat << EOF

  Usage: $my_name [options]
     -s <device> ---> device id of your phone [run 'adb devices' to get device id]
     -f <output> ---> output filename [default: $output_file_prefix.[png|mp4]
     -c          ---> capture a screenshot
     -r          ---> record a video for $video_length seconds to file
     -h          ---> print usage/help

  example: $my_name -s deviceid -c -f /tmp/phone_screen.png
  
EOF
  exit 0
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
          echo "[INFO] this device ($device) is connected via TCP, attempting to connect ... " | tee -a $log_file
          adb connect $device 2>&1 | tee -a $log_file
        else
          echo "[INFO] this device ($device) is connected via USB ... " | tee -a $log_file
        fi
        return
        ;;
    esac
  done
  
  echo "[ERROR] the specified device ($device) does not exist or connected!"
  exit 1
}

# TODO: not working because scrcpy creates subshell and runs a java process 
# (scrcpy-server.jar) inside the phone. Not sure how to limit the recording time
# investigate later to fix this, for now just use adb screenrecord
record_with_scrcpy() {
  # scrcpy does not have feature to stop after sometime, so doing a 
  # hackjob here i.e. kill it after the length of time we need the video
  # elapsed.
  scrcpy -s $device --max-size=$video_size_scrcpy --no-display -r $output_file 2>&1 >> $log_file &
  pid=$!
  echo "[INFO] waiting to capture $video_length worth of video..." | tee -a $log_file
  sleep $video_length
  kill -1 $pid
  echo "[INFO] done" | tee -a $log_file
  exit 0
}


screen_capture() {
  if [ -z $output_file ] ; then
    output_file="${output_file_prefix}.png"
  fi
  echo "[INFO] screen capture will be stored at: $output_file"
  adb -s $device exec-out "screencap -p" > $output_file
}

screen_record() {
  if [ -z $output_file ] ; then
    output_file="${output_file_prefix}.mp4"
  fi
  echo "[INFO] screen recording video will be at: $output_file" | tee -a $log_file

  # use scrcpy if installed TODO: not able to make it work, comment out for now.
  #which scrcpy 2>&1 >/dev/null
  #if [ $? -eq 0 ] ; then
  #  echo "[INFO] using scrcpy to record video ..." | tee -a $log_file
  #  record_with_scrcpy
  #  exit
  #fi

  # screen record args
  sr_args="screenrecord --output-format=$video_format --time-limit=$video_length --bit-rate=$video_bitrate --size=$video_size_adb"
  
  # TODO: not able to pass "" to screenrecord for directly saving file on host. Need to figureout.
  #adb -s $device exec-out "$sr_args -" > $output_file
  # For now just save it on phone and do a 'adb pull'
  adb -s $device shell $sr_args /sdcard/tmp.mp4 2>&1 | tee -a $log_file
  adb -s $device pull /sdcard/tmp.mp4 $output_file 2>&1 | tee -a $log_file
  adb -s $device shell rm /sdcard/tmp.mp4 2>&1 | tee -a $log_file
  echo "[INFO] done" | tee -a $log_file
  exit 0
}

# --------------- main ----------------------
echo "$my_version" | tee $log_file
while getopts "$options_list" opt ; do
  case $opt in 
    s)
      device=$OPTARG
      check_device
      ;;
    c)
      ss_type=0
      ;;
    r)
      ss_type=1
      ;;
    f)
      output_file="$OPTARG"
      ;;
    h|?|*)
      usage
      ;;
  esac
done

# if nothing specified, just print usage
if [ $# -eq 0 ] ; then
  echo "[ERROR] no commands specified!"
  usage
fi

# if setup call do setup, otherwise just assume we are running command on already setup device
if [ $ss_type -eq 0 ] ; then
  screen_capture
elif [ $ss_type -eq 1 ] ; then
  screen_record
else
  echo "[ERROR] invalid command tyoe"
  usage
fi
