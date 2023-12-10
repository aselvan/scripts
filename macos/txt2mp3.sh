#!/usr/bin/env bash
#
# txt2mp3.sh --- convert text to mp3 using macOS tools
#
# The script uses 'say' commandline binary that is part of MacOS to convert text to mp3
# Note:
#   The say' coommand does not support mp3 so we need 'lame' to convert to mp3. If lame
#   is not installed, this script creates an audio only mp4 instead of mp3
#
# PreReq: 
#   lame (install w/ 'brew install lame')
#
# Author:  Arul Selvan
# Created: Dec 30, 2022
#

# version format YY.MM.DD
version=23.12.06
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Convert text to mp3 using macOS tools"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="t:o:l:m:vh?"

my_pid=$$
text=""
volume=30
model="Samantha (Enhanced)"
cur_vol=0
out_file="/tmp/$(echo $my_name|cut -d. -f1).mp3"
default_format="--file-format mp4f"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -t <text>     ---> text (can include rate of speach) in quotes to be converted to mp3
  -o <filename> ---> output file name for mp3 [default: $out_file]
  -l <number>   ---> volume to adjust before speaking between 1-100 [Default: $volume]
  -m <model>    ---> voice model in quotes [Default: "$model"]
  -v            ---> enable verbose, otherwise just errors are printed
  -h            ---> print usage/help
  
example: $my_name -t "Hello [[slnc 75]], my name is Bob"
         the above example inserts 75 msec pause after saying 'Hello'
EOF
  exit 0
}

set_volume() {
  # save current volume to restore, & set new volume
  cur_vol=$(osascript -e 'output volume of (get volume settings)')
  log.debug "Saved current volume ($cur_vol)."
  log.debug "Setting current volume to $volume"
  osascript -e "set volume output volume $volume" 2>&1 | tee -a $log_file
}

restore_volume() {
  log.debug "Restoring current volume"
  osascript -e "set volume output volume $cur_vol"  2>&1 | tee -a $log_file
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

# parse commandline options
while getopts $options opt; do
  case $opt in
    t)
      text="$OPTARG"
      ;;
    o)
      out_file="$OPTARG"
      ;;
    l)
      volume="$OPTARG"
      ;;
    m)
      model="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check for message
if [ -z "$text" ] ; then
  log.error "Required argument -t missing!"
  usage
fi

set_volume

log.stat "Converting text to mp3..."
# if lame utility is there, convert to mp3 otherwise default to mp4 (audio only)
which lame 2>&1 >/dev/null
if [ $? -eq 0 ] ; then
  temp_file=$(mktemp /tmp/${my_name}.${my_pid})
  echo "$text" | say -v "$model" -o $temp_file 2>&1 >> $my_logfile
  if [ $? -ne 0 ] ; then
    log.error "Say tool failed!"
    rm $temp_file
    restore_volume
    exit 2
  fi

  lame --quiet $temp_file $out_file 2>&1 >> $my_logfile
  if [ $? -ne 0 ] ; then
    log.error "Converting to MP3 failed!"
    rm $temp_file
    restore_volume
    exit 3
  fi
  rm $temp_file
else
  # lame tool does not exist, so writing mp4 w/ audio only
  log.debug "lame tool does not exist, so writing mp4 w/ audio only"
  echo "$text" | say $default_format -v "$model" -o $out_file  
fi

restore_volume
log.stat "The audio file is at: $out_file" $green

