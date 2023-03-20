#!/bin/bash
#
# create_videos.sh --- script to create videos from images.
#
# This is a handy script to convert all images into videos so we can store it 
# in YouTube for free. This script will use the img2video.sh script to actually 
# convert images and create 1 video for 1 directory full of JPG images. All is 
# needed is a CSV file as described below to describe, each directory path, video 
# title, output name, images to include with regex mask, a background mp3 etc. 
# The videos will be created under the $stage_dir so need to ensure adiquate 
# space is available there for copying source images and making video files 
# which could be pretty large, just reserve at least 100GB
#
# CSV input file format (note: first line ignored as header)
# -----------------------------------------------------------
# Directory Path,  Image Files,  Background MP3,          Video Title,           Video File Name
# /data/vacation1, ".jpg|.JPG", /vacation1/bg_music1.mp3, "Our Vacation 1\n2023", vacation1.mp4
# /data/vacation2, ".png",      /vacation1/bg_music2.mp3, "Our Vacation 2\n2023", vacation1.mp4
#
# Author:  Arul Selvan
# Version History
# --------------
#   23.03.19 --- Initial version
#

# version format YY.MM.DD
version=23.03.19
my_name="`basename $0`"
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
cmdline_args=`printf "%s " $@`

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="c:s:vh?"
verbose=0
sample_env="${SAMPLE_ENV:-default_value}"

# staging path and it should have ton of freespace to create potentially
# large video files out of each of the directories. Just use a path that
# has at least 100GB free space.
stage_dir=""
csv_file=""
src_path=""
src_mask=""
background_mp3_file=""
video_title=""
video_name=""

IFS_old=$IFS

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -c <csvfile>  ---> CSV file formated as explained above (read code)
     -s <stagedir> ---> staging path must have at least 100GB free space [default: '$stage_dir']
     -v            ---> verbose mode prints info messages, otherwise just errors
     -h            ---> print usage/help

  example: $my_name -h
  
EOF
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
  write_log "[STAT]" "$my_version"
  write_log "[STAT]" "starting at `date +'%m/%d/%y %r'` ..."
}

init_osenv() {
  if [ $os_name = "Darwin" ] ; then
    write_log "[STAT]" "MacOS environment"
  else
    write_log "[STAT]" "Other environment (Linux)"
  fi
}

create_video() {
  write_log "[INFO]" "Creating video $video_name using files from $src_path ..."
  write_log "[INFO]" "  Mask: $src_mask"
  write_log "[INFO]" "  Video Title: $video_title"
  write_log "[INFO]" "  Video Name:  $video_name"
  write_log "[INFO]" "  Video Background: $background_mp3_file"

  # TODO: implement video creation

}

# ----------  main --------------
init_log
init_osenv
# parse commandline options
while getopts $options opt; do
  case $opt in
    c)
      csv_file="$OPTARG"
      ;;
    s)
      stage_dir="$OPTARG"
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

if [ ! -f "$csv_file" ] ; then
  write_log "[ERROR]" "CSV file is missing or non-existent. See usage below"
  usage
fi

if [ ! -d "$stage_dir" ] ; then
  write_log "[ERROR]" "Stage dir is missing or non-existent. See usage below"
  usage
fi


# loop through CSV file and create video for each entry
exec < $csv_file
read header
while IFS="," read -r src_path src_mask background_mp3_file video_title video_name
do
  if [ -z "$src_path" ] ; then
    continue
  fi
  create_video
done 
