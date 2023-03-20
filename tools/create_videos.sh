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

# staging path and it should have ton of freespace to create potentially
# large video files out of each of the directories. Just use a path that
# has at least 100GB free space.
img2video="img2video.sh"
stage_dir=""
csv_file=""
src_path=""
src_mask=""
background_mp3_file=""
video_title=""
video_name=""
IFS_old=$IFS
record_count=0

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

assign_img2video_arguments() {
  # assign img2video.sh arguments
  if [ ! -z "$video_title" ] ; then
    i2v_title="-t \"$video_title\""
  else
    i2v_title=""
    echo "### title empty!"
  fi
  if [ ! -z "$background_mp3_file" ] ; then
    i2v_mp3="-a $background_mp3_file"
  else
    i2v_mp3=""
    echo "### mp3 empty"
  fi
  if [ ! -z "$src_mask" ] ; then
    i2v_mask="-i \"$src_mask\""
  else
    i2v_mask=""
    echo "### mask empty"
  fi
  if [ ! -z "$video_name" ] ; then
    i2v_output="-o $video_name"
  else
    i2v_output=""
    echo "### output empty"
  fi
}

trim_column_values() {
  src_path=$(echo $src_path|xargs)
  src_mask=$(echo $src_mask|xargs)
  video_title=$(echo $video_title|xargs)
  video_name=$(echo $video_name|xargs)
  background_mp3_file=$(echo $background_mp3_file|xargs)
}

create_video() {
  # validate requirements (if we don't have src path & mask nothing to do)
  if [ -z "$src_path" ] ; then
    write_log "[WARN] CSV file missing required argument column 'Directory Path' ... skipping row $record_count"
    return
  fi
  if [ -z "$src_mask" ] ; then
    write_log "[WARN] CSV file missing required argument 'Image Files' ... skipping row $record_count"
    return
  fi
  write_log "[STAT]" "### Processing row #$record_count ###      "
  write_log "[INFO]" "  Path: $src_path"
  write_log "[INFO]" "  Mask: $src_mask"
  write_log "[INFO]" "  Title: $video_title"
  write_log "[INFO]" "  Name:  $video_name"
  write_log "[INFO]" "  Background: $background_mp3_file"

  # copy the files from $src_path to the staging area
  if [ ! -d $src_path ] ; then
    write_log "[ERROR] Image source directory $src_path does not exist!, skipping row #$record_count"
    return
  fi
  cd $stage_dir || exit
  # cp -p $src_path/* .

  # setup arguments to call img2video.sh
  assign_img2video_arguments
  echo $img2video $i2v_mask $i2v_title $i2v_mp3 $i2v_output

  # execute img2video and wait till it completes
  write_log "[STAT]" "Calling img2video.sh, it would take a long time, so wait..."
  
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
  # check for EOF
  if [ -z "$src_path" ] ; then
    continue
  fi

  # row counter
  ((record_count++))

  # trim whitspace on all column values first
  trim_column_values

  # finally, create video
  create_video
done 
