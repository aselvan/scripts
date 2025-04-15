#!/usr/bin/env bash
################################################################################
#  
# img2video.sh --- script to combine images to generate a video file
#
# Reads all images provided and generates a video file. The order of files
# used to create video will be dictaed by each file's OS timestamp in 
# reversed order i.e. most recent files first. 
#
# Execute this script in the directory where your *.jpg exists and writable
# for creating temporary files.
#
# Note: ffmpeg utility needed for this script, you can install it as shown 
#       below for you OS
#
#   macOS:   brew install ffmpeg
#   Linux:   apt-get install ffmpeg
#   Windows: Get a real OS!
#
# Author : Arul Selvan
# Version: Mar 6, 2023  --- original version
################################################################################
# Version History:
#   Mar 6,  2023 --- Original version
#   Mar 17, 2025 --- Added [0:v] to filter_complex to fix the error, std logging
################################################################################

# version format YY.MM.DD
version=25.03.17
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Combine images to generate a video file"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="i:a:s:o:f:t:d:vh?"

image_list_file="image_list.txt"
scale="2400:1600"
video_codec="-vcodec libx264"
frame_rate="0.25"
filter_complex="[0:v]scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2"
#image_wildcard=".jpg|.JPG|.png"
image_wildcard=".jpg|.JPG|.png|.jpeg|.JPEG|.gif|.GIF"
audio_file=""
output_file="output.mp4"
title_image="title.jpg"
end_image="end.jpg"
title_background="blue"
title_foreground="white"
title_font="Chalkboard-SE-Bold" # This is macOS font found @ /System/Library/Fonts/Supplemental/
title_font_size=75
title_size="1600x1200"
cmdline_args=`printf "%s " $@`
copyright="created by SelvanSoft, LLC (selvansoft.com)"
title_metadata="$my_version, $copyright"
creation_date=`date -u +%Y%m%d%H%M`
title_text="Home video from pictures\n$copyright"
end_text="THE end!\n$copyright"

usage() {
cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -i <images]>   --> regex for input images in current dir [default: "$image_wildcard"]
  -t <text>      --> text can contain '\n' for multi-line to create a title image [optional]
  -a <mp3>       --> mp3 audio for adding background [optional]
  -s <scale>     --> scale images to width:height [default: $scale]
  -f <framerate> --> framerate image/sec i.e. 1 means 1 image/sec [default: $frame_rate]"
  -d <timestamp> --> Set video create time in UTC; format is YYYYMMDDHHMM [default: ${creation_date}01]"
  -o <output>    --> filename for output video [default: $output_file]
  -v             --> enable verbose, otherwise just errors are printed
  -h             --> print usage/help  
  
example(s): 
  $my_name -t "Vacation 2023\nPictures from our vacation" -i "$image_wildcard" -a background.mp3 -s $scale -o $output_file

EOF
  exit 0
}

check_pre_requirements() {
  # ensure ffmpeg is available
  which ffmpeg >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    echo "[ERROR] ffmpeg is required for this script to work, install it first [ex: brew install ffmpeg]."
    exit 1
  fi
}

cleanup_tmp() {
  if [ -f $title_image ] ; then
    rm $title_image
  fi
  if [ -f $end_image ] ; then
    rm $end_image
  fi
  if [ -f $image_list_file ] ; then
    rm $image_list_file
  fi
}

create_end_image() {
  log.stat "creating video end image $end_image ..."
  convert -size $title_size -gravity center -background $title_background -fill $title_foreground -font $title_font -pointsize $title_font_size label:"$end_text" $end_image
}

# for now hardcoded values, can expand to take arguments for font/image size etc.
create_title_image() {
  log.stat "creating video title image $title_image ..."
  convert -size $title_size -gravity center -background $title_background -fill $title_foreground -font $title_font -pointsize $title_font_size label:"$title_text" $title_image
}

create_sorted_filelist() {
  if [[ -f $title_image && ! -z $title_text ]] ; then
    echo "file '$title_image'" > $image_list_file
  else
    echo -n "" > $image_list_file
  fi
  
  for f in `ls -rt | egrep $image_wildcard` ; do
    if [ $f == $title_image ] ; then
      continue
    fi
    echo "file '$f'" >> $image_list_file
  done

  # add end slide
  echo "file '$end_image'" >> $image_list_file
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
    i)
      image_wildcard="$OPTARG"
      ;;
    t)
      title_text="$OPTARG"
      ;;
    a)
      if [ -f $OPTARG ] ; then
        audio_file="-stream_loop -1 -i $OPTARG -shortest -map 0:v -map 1:a"
      else
        log.warn "audio file ($OPTARG) does not exists, continuing w/ out audio"
      fi
      ;;
    s)
      scale="$OPTARG"
      filter_complex="[0:v]scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2"
      ;;
    o)
      output_file="$OPTARG"
      ;;
    d)
      creation_date="$OPTARG"
      ;;
    f)
      frame_rate="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# create title and end slide pictures
clean_title=$(echo ${title_text//\\n/ })
title_metadata="$clean_title, $copyright"
create_title_image
create_end_image

# create the timeline based order we want
create_sorted_filelist

log.stat "creating video using all images found at: `pwd`/$image_wildcard ..."
ffmpeg -noautorotate -f concat -safe 0 -r $frame_rate -i $image_list_file $audio_file $video_codec -filter_complex "$filter_complex" -pix_fmt yuv420p -r 30 -y -timestamp ${creation_date}01 -metadata title="$title_metadata" $output_file >> $my_logfile 2>&1
rc=$?
log.stat "cleaning up tmp files"
cleanup_tmp

if [ $rc -eq 0 ] ; then
  log.info "Success creating video file: $output_file"
  touch -t $creation_date $output_file
  exit 0
else
  log.error "Failed to create video, ffmpeg returned error see log file $my_logfile for details"
  exit 1
fi
