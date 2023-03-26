#!/bin/bash
#
# create_videos.sh --- script to create videos from images.
#
# This is a handy script to convert all images into videos so we can store it 
# in YouTube for free. This script will use the img2video.sh script to actually 
# convert images and create 1 video for 1 directory full of JPG images. All is 
# needed is a CSV file as described below to define directory path, video 
# title, output name, images to include with regex mask, a background mp3 etc. 
# The videos will be created under the $stage_dir/ so need to ensure adiquate 
# space is available there for copying source images and making video files 
# which could be pretty large, just reserve at least 100GB
#
# CSV format notes:
# ----------------
# The following is a sample CSV input file format. See create_videos.csv file in 
# this directory which is part of actual CSV rows I used to create all my videos.
# Title column can have space, line feed '\n' etc but rest like path, mask, 
# filename should not contain space or linefeed etc. Create date should be in 
# UTC timzone with the format YYYYMMDDHHMM. If you don't care about exact hour on 
# the date you can just use timestamp in your timezone. The 3rd column (background mp3) 
# and 4th column (video title) and 6th column (timestamp) are optional (see row 3) 
# and can can be empty. Also the first line skipped as a 'header' row and also lines 
# contain '#' indicating they are comments.
#
# ------------------  CSV File Format definition  ---------------------
# Directory Path,  Image Files,  Background MP3, Video Title, Video File Name, Create Date
# /Users/arul/test, .jpg|.JPG, background.mp3, "Our Vacation 1\n2023", vacation1.mp4, 19850101800
# /Users/arul/test, .jpeg|.JPEG, background.mp3, "Our Vacation 2\n2023", vacation2.mp4,
# /foo/bar, .png, background.mp3, , vacation1.mp4,
# # /foo/baz, .png, background.mp3, , vacation1.mp4,
# ------------------  CSV File Format definition  ---------------------
# PreReq: 
#   the following scripts from https://github.com/aselvan/scripts/tree/master/tools 
#   should be in the current dir.
#
#   img2video.sh 
#   reset_file_timestamp.sh
#   
# Author:  Arul Selvan
# Version History
# --------------
#   23.03.19 --- Initial version
#

# version format YY.MM.DD
version=23.03.25
my_name="`basename $0`"
my_version="`basename $0` v$version"
host_name=`hostname`
os_name=`uname -s`
cmdline_args=`printf "%s " $@`
dir_name=`dirname $0`
my_path=$(cd $dir_name; pwd -P)

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="c:s:vh?"
verbose=0

# staging path and it should have ton of freespace to create potentially
# large video files out of each of the directories. Just use a path that
# has at least 100GB free space.
img2video="$my_path/img2video.sh"
reset_file_timestamp="$my_path/reset_file_timestamp.sh"
stage_dir=""
csv_file=""
src_path=""
src_mask=""
background_mp3_file=""
video_title=""
video_name=""
IFS_old=$IFS
record_count=1
img2video_args=""
default_create_date=`date -u +%Y%m%d%H%M`

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -c <csvfile>  ---> CSV file formated as explained above (code comments)
     -s <stagedir> ---> staging path must have at least 100GB free space [default: '$stage_dir']
     -v            ---> verbose mode prints info messages, otherwise just errors
     -h            ---> print usage/help

  example: $my_name -c /data/videos/create_videos.csv -s /data/videos
  
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

check_pre_requirements() {
  if [ ! -x $img2video ] ; then
    write_log "[ERROR] required script ($img2video) missing!"
    exit 1
  fi
  if [ ! -x $reset_file_timestamp ] ; then
    write_log "[ERROR] required script ($reset_file_timestamp) missing!"
    exit 1
  fi
  
}

build_img2video_arguments() {

  # build img2video args list
  img2video_args="-i $src_mask"
  if [ ! -z "$video_name" ] ; then
    img2video_args="$img2video_args -o $stage_dir/$video_name"
  fi

  if [ ! -z "$background_mp3_file" ] ; then
    img2video_args="$img2video_args -a $background_mp3_file"
  fi
}

trim_column_values() {
  src_path=$(echo $src_path|xargs)
  src_mask=$(echo $src_mask|xargs)
  video_title=$(echo $video_title|xargs)
  video_name=$(echo $video_name|xargs)
  background_mp3_file=$(echo $background_mp3_file|xargs)
  create_date=$(echo $create_date|xargs)
}

create_video() {
  # validate requirements (if we don't have src path & mask nothing to do)
  if [ -z "$src_path" ] ; then
    write_log "[WARN] missing CSV column 'Directory Path' ... skipping line #$record_count"
    return
  fi
  if [ -z "$src_mask" ] ; then
    write_log "[WARN] missing CSV column 'Image Files' ... skipping line #$record_count"
    return
  fi

  # validate source image path
  if [ ! -d "$src_path" ] ; then
    write_log "[ERROR] Image source directory $src_path does not exist!, skipping line #$record_count"
    return
  fi

  # if createdate is not provided use current timestamp
  if [ -z "$create_date" ] ; then
    create_date=$default_create_date
  fi
  
  # we should be in $stage_dir/images directory, just to be save use full path amd ensure it is clean
  write_log "[STAT]" "Copying source images to staging area ..."
  rm -f $stage_dir/images/*
  find $src_path -maxdepth 1 -type f | xargs -I {} cp {} $stage_dir/images/.

  # reset file timestamp w/ image metadata for timeline squencing
  write_log "[STAT]" "Reseting OS timestamp using metadata for time squencing ..."
  $reset_file_timestamp -p .

  # setup arguments to call img2video.sh
  build_img2video_arguments

  # execute img2video and wait till it completes
  write_log "[STAT]" "Creating video. This task may take a long time, please wait ..."
  # handle args w/ space separately as they don't work on subshell.

  # inject /dev/null as the input stream otherwise it would mess up our (parent)
  # input stream where we are reading the CSV file.
  if [ ! -z "$video_title" ] ; then
    $img2video $img2video_args -t "$video_title" -d $create_date < /dev/null
    rc=$?
  else
    $img2video $img2video_args -d $create_date < /dev/null
    rc=$?
  fi
  if [ $rc -eq 0 ] ; then
    write_log "[STAT]" "Success creating video at $stage_dir/$video_name ..."
  else
    write_log "[ERROR]" "Video create failed, see log for details ($log_file) ..."
  fi

  # finally cleanup $stage_dir/images/ for next line
  rm -f $stage_dir/images/*
}

# ----------  main --------------
init_log
check_pre_requirements

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
  write_log "[ERROR]" "CSV file is missing or non-existent. See usage."
  usage
fi

if [ ! -d "$stage_dir" ] ; then
  write_log "[ERROR]" "Stage dir is missing or non-existent. See usage."
  usage
else
  # prepare staging dir and cd over there for our processing
  cd $stage_dir >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    write_log "[ERROR]" "Unable to cd to stagedir: $stage_dir" || usage
  fi
  mkdir -p images
  cd images || exit 3
fi

# loop through CSV file and create video for each entry
exec < $csv_file
read header
while IFS="," read -r src_path src_mask background_mp3_file video_title video_name create_date ; do

  # line counter
  ((record_count++))

  # check for EOF (or empty lines?)
  if [ -z "$src_path" ] ; then
    continue
  fi

  # check for comments
  if [[ "$src_path" == *"#"* ]]; then
    write_log "[INFO]" "Line #${record_count} contains comment skip ..."
    continue
  fi

  # trim whitspace on all column values first
  trim_column_values

  write_log "[STAT]" "### Processing line #${record_count} ###      "
  write_log "[INFO]" "  Path:           '$src_path'"
  write_log "[INFO]" "  Image Mask:     '$src_mask'"
  write_log "[INFO]" "  Background:     '$background_mp3_file'"
  write_log "[INFO]" "  Title:          '$video_title'"
  write_log "[INFO]" "  Video Filename: '$video_name'"
  write_log "[INFO]" "  Timestamp:      '$create_date'"
  
  # finally, create video
  create_video
done
