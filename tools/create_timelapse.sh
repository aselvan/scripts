#!/usr/bin/env bash
#
# create_timlapse.sh --- script to create timelapse animated gif
#
# This script creates a animated GIF using imagemagick (must be installed).
# It assumes the image files needed are in current directory so make sure
# to 'cd' to the directory where all the image files present.
#
# Author:  Arul Selvan
# Created: Aug 21, 2023
#

# version format YY.MM.DD
version=23.08.21
my_name="`basename $0`"
my_version="`basename $0` v$version"
dir_name=`dirname $0`
my_path=$(cd $dir_name; pwd -P)

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
default_list_file="/tmp/$(echo $my_name|cut -d. -f1).txt"
list_file=""
animation_output="/tmp/$(echo $my_name|cut -d. -f1).gif"
size="640x480"
frame_delay="25"
first_frame_delay=0
loop=1

log_init=0
options="i:o:l:d:f:s:vh?"
verbose=0
failure=0
green=32
red=31
blue=34

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -i <listfile>   ---> input file contains list of images in the order to inlcude in animated gif
     -o <outputfile> ---> output name for animated file [default: $animation_output]
     -s <size>       ---> size in width/height [default: $size]
     -l <loop>       ---> loop/iteration count [default: run once do not loop]
     -d <delay>      ---> insert a delay (1/100 of sec) units [default: $frame_delay]
     -f <delay>      ---> insert a different delay for first frame [default: same as -d option]
     -v              ---> verbose mode prints info messages, otherwise just errors are printed 
     -h              ---> print usage/help

  example: $my_name -h
  
EOF
  exit 0
}

# -- Log functions ---
log.init() {
  if [ $log_init -eq 1 ] ; then
    return
  fi

  log_init=1
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  echo -e "\e[0;34m$my_version, `date +'%m/%d/%y %r'` \e[0m" | tee -a $log_file
}

log.info() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[0;32m$msg\e[0m" | tee -a $log_file 
}
log.debug() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[1;30m$msg\e[0m" | tee -a $log_file 
}
log.stat() {
  log.init
  local msg=$1
  local color=$2
  if [ -z $color ] ; then
    color=$blue
  fi
  echo -e "\e[0;${color}m$msg\e[0m" | tee -a $log_file 
}
log.warn() {
  log.init
  local msg=$1
  echo -e "\e[0;33m$msg\e[0m" | tee -a $log_file 
}
log.error() {
  log.init
  local msg=$1
  echo -e "\e[0;31m$msg\e[0m" | tee -a $log_file 
}

# ----------  main --------------
log.init

# parse commandline options
while getopts $options opt ; do
  case $opt in
    i)
      list_file="$OPTARG"
      ;;
    o)
      animation_output="$OPTARG"
      ;;
    l)
      loop="$OPTARG"
      ;;
    d)
      frame_delay="$OPTARG"
      ;;
    f)
      first_frame_delay="$OPTARG"
      ;;
    s)
      size="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# create list file if one not provided
if [ -z $list_file ] ; then
  list_file=$default_list_file
  ls -t1 *.jpg > $list_file
fi

# run convert to create animation GIF
convert -loop 1 -dispose previous -thumbnail $size -delay $frame_delay @$list_file ${animation_output}

# if different delay for 1st frame requested change the delay
if [ $first_frame_delay -ne 0 ] ; then
  log.stat "  Reseting first frame delay to $first_frame_delay ..."
  convert ${animation_output} \( -clone 0 -set delay $first_frame_delay \) -swap 0,-1 +delete ${animation_output}.tmp
  mv ${animation_output}.tmp ${animation_output}
fi
log.stat "Output file is: $animation_output"
