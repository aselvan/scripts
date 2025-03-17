#!/usr/bin/env bash
################################################################################
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
# and can can be empty. A directory with MP3 files can be specified optionally with 
# -m argument which can be used with RANDOM_MP3 variable as background MP3 in which 
# case a random MP3 from the specified directory can be used as background MP3. Also 
# the first line skipped as a 'header' row and also lines contain '#' indicating 
# they are comments.
#
# ------------------  CSV File Format definition  ---------------------
# Directory Path,  Image Files,  Background MP3, Video Title, Video File Name, Create Date
# /Users/arul/test, .jpg|.JPG, background.mp3, "Our Vacation 1\n2023", vacation1.mp4, 19850101800
# /Users/arul/test, .jpeg|.JPEG, background.mp3, "Our Vacation 2\n2023", vacation2.mp4,
# /foo/bar, .png, background.mp3, , vacation1.mp4,
# # /foo/baz, .png, RANDOM_MP3, , vacation1.mp4,
# ------------------  CSV File Format definition  ---------------------
# PreReq: 
#   the following scripts from https://github.com/aselvan/scripts/tree/master/tools 
#   should be in the current dir.
#
#   img2video.sh 
#   reset_file_timestamp.sh
#   
# Author:  Arul Selvan
# Version: Mar 19, 2023
#
################################################################################
# Version History:
#   Mar 19, 2023 --- Original version
#   Mar 17, 2025 --- Converted to use standard logging & includes
#
################################################################################

# version format YY.MM.DD
version=25.03.17
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Create videos from images."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="c:s:m:vh?"

# staging path and it should have ton of freespace to create potentially
# large video files out of each of the directories. Just use a path that
# has at least 100GB free space.
img2video="$my_path/img2video.sh"
reset_file_timestamp="$my_path/reset_file_timestamp.sh"
stage_dir=""
mp3_dir=""
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

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -c <csvfile>  ---> CSV file formated as explained above (code comments)
  -s <stagedir> ---> staging path must have at least 100GB free space [default: '$stage_dir']
  -m <mp3dir>   ---> directory of mp3 files to be used for background music [default: '$mp3_dir']
  -v             --> enable verbose, otherwise just errors are printed
  -h             --> print usage/help  

example(s): 
  $my_name -c /data/videos/create_videos.csv -s /data/videos
  
EOF
  exit 0
}

# mp3_dir is set, return a random mp3 file path, otherwise blank
get_random_mp3() {
  random_mp3=`ls $mp3_dir/*.mp3 2>/dev/null |shuf -n1`
  echo $random_mp3
}

check_pre_requirements() {
  if [ ! -x $img2video ] ; then
    log.error "required script ($img2video) missing!"
    exit 1
  fi
  if [ ! -x $reset_file_timestamp ] ; then
    log.error "required script ($reset_file_timestamp) missing!"
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
    if [ "$background_mp3_file" == "RANDOM_MP3" ] ; then
      local mp3=$(get_random_mp3)
      if [ "$mp3" != "" ] ; then
        img2video_args="$img2video_args -a $mp3"
      else
        log.warn "no mp3 found in the directory: '$mp3_dir' ... continue w/ out audio!"        
      fi
    else
      img2video_args="$img2video_args -a $background_mp3_file"
    fi
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
    log.warn "missing CSV column 'Directory Path' ... skipping line #$record_count"
    return
  fi
  if [ -z "$src_mask" ] ; then
    log.warn "missing CSV column 'Image Files' ... skipping line #$record_count"
    return
  fi

  # validate source image path
  if [ ! -d "$src_path" ] ; then
    log.error "Image source directory $src_path does not exist!, skipping line #$record_count"
    return
  fi

  # if createdate is not provided use current timestamp
  if [ -z "$create_date" ] ; then
    create_date=$default_create_date
  fi
  
  # we should be in $stage_dir/images directory, just to be save use full path amd ensure it is clean
  log.stat "Copying source images to staging area ..."
  rm -f $stage_dir/images/*
  find $src_path -maxdepth 1 -type f | xargs -I {} cp {} $stage_dir/images/.

  # reset file timestamp w/ image metadata for timeline squencing
  log.stat "Reseting OS timestamp using metadata for time squencing ..."
  $reset_file_timestamp -p .

  # setup arguments to call img2video.sh
  build_img2video_arguments

  # execute img2video and wait till it completes
  log.stat "Creating video. This task may take a long time, please wait ..."
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
    log.stat "Success creating video at $stage_dir/$video_name ..."
  else
    log.stat "Video create failed, see log for details ($my_logfile) ..."
  fi

  # finally cleanup $stage_dir/images/ for next line
  rm -f $stage_dir/images/*
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
    m)
      mp3_dir="$OPTARG"
      if [ ! -d $mp3_dir ] ; then
        log.error "The MP3 directory ($mp3_dir) does not exists! (see usage)"
        usage
      fi
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ ! -f "$csv_file" ] ; then
  log.error "CSV file is missing or non-existent. See usage."
  usage
fi

if [ ! -d "$stage_dir" ] ; then
  log.error "Stage dir is missing or non-existent. See usage."
  usage
else
  # prepare staging dir and cd over there for our processing
  cd $stage_dir >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    log.error "Unable to cd to stagedir: $stage_dir"
    usage
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
    log.debug "Line #${record_count} contains comment skip ..."
    continue
  fi

  # trim whitspace on all column values first
  trim_column_values

  log.stat "### Processing line #${record_count} ###      "
  log.stat "  Path:           $src_path"
  log.stat "  Image Mask:     $src_mask"
  log.stat "  Background:     $background_mp3_file"
  title=$(echo $video_title | tr '\\n' ' ')
  log.stat "  Title:          $title"
  log.stat "  Video Filename: $video_name"
  log.stat "  Timestamp:      $create_date"
  
  # finally, create video
  create_video
done
