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
# Version History:
#   Aug 21, 2023 --- Original version
#   Nov 3,  2024 --- Changed to use standard includes and magick instead of convert
#

# version format YY.MM.DD
version=24.11.03
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Create a timelapse animated gif"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="i:o:l:d:f:s:vh?"

default_list_file="/tmp/$(echo $my_name|cut -d. -f1).txt"
list_file=""
animation_output="/tmp/$(echo $my_name|cut -d. -f1).gif"
size="640x480"
frame_delay="25"
first_frame_delay=0
loop=1

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"


usage() {
  cat << EOF
$my_title

Usage: $my_name [options]
  -i <listfile>   ---> file contains list of images (one per line) in the order
  -o <outputfile> ---> output name for animated file [default: $animation_output]
  -s <size>       ---> size in width/height [default: $size]
  -l <loop>       ---> loop/iteration count [default: run once do not loop]
  -d <delay>      ---> insert a delay (1/100 of sec) units [default: $frame_delay]
  -f <delay>      ---> insert a different delay for first frame [default: same as -d option]
  -v              ---> verbose mode prints info messages, otherwise just errors are printed 
  -h              ---> print usage/help

  example: $my_name -o animated.gif -l10 -d100
  
EOF
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
#magick -loop $loop -dispose previous -thumbnail $size -delay $frame_delay @$list_file ${animation_output}
magick -loop $loop -dispose previous -delay $frame_delay -size $size @$list_file ${animation_output}

# if different delay for 1st frame requested change the delay
if [ $first_frame_delay -ne 0 ] ; then
  log.stat "  Reseting first frame delay to $first_frame_delay ..."
  magick ${animation_output} \( -clone 0 -set delay $first_frame_delay \) -swap 0,-1 +delete ${animation_output}.tmp
  mv ${animation_output}.tmp ${animation_output}
fi
log.stat "Output file is: $animation_output"
