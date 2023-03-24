#!/bin/bash
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

# ensure path for utilities
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=23.03.24
my_name=`basename $0`
my_version="$my_name v$version"
options="i:a:s:o:f:t:d:vh?"
verbose=0
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
image_list_file="image_list.txt"
scale="2400:1600"
video_codec="-vcodec libx264"
frame_rate="0.25"
filter_complex="scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2"
image_wildcard=".jpg|.JPG"
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
  Usage: $my_name [options]
    -i <images]>   --> regex for input images in current dir [default: "$image_wildcard"]
    -t <text>      --> text can contain '\n' for multi-line to create a title image [optional]
    -a <mp3>       --> mp3 audio for adding background [optional]
    -s <scale>     --> scale images to width:height [default: $scale]
    -f <framerate> --> framerate image/sec i.e. 1 means 1 image/sec [default: $frame_rate]"
    -d <timestamp> --> Set video create time in UTC; format is YYYYMMDDHHMM [default: ${creation_date}01]"
    -v             ---> verbose mode prints INFO messages, otherwise just errors
    -o <output>    --> filename for output video [default: $output_file]
  
   example: $my_name -t "Vacation 2023\nPictures from our vacation" -i "$image_wildcard" -a background.mp3 -s $scale -o $output_file

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
  write_log "[INFO]" "creating video end image $end_image ..."
  convert -size $title_size -gravity center -background $title_background -fill $title_foreground -font $title_font -pointsize $title_font_size label:"$end_text" $end_image
}

# for now hardcoded values, can expand to take arguments for font/image size etc.
create_title_image() {
  write_log "[INFO]" "creating video title image $title_image ..."
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

# ----------  main --------------
init_log
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
        write_log "[WARN]" "audio file ($OPTARG) does not exists, continuing w/ out audio"
      fi
      ;;
    s)
      scale="$OPTARG"
      filter_complex="scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2"
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
    ?)
      usage
      ;;
    h)
      usage
      ;;
    *)
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

write_log "[INFO]" "creating video using all images found at: `pwd`/$image_wildcard ..."
ffmpeg -f concat -safe 0 -r $frame_rate -i $image_list_file $audio_file $video_codec -filter_complex "$filter_complex" -pix_fmt yuv420p -r 30 -y -timestamp ${creation_date}01 -metadata title="$title_metadata" $output_file >> $log_file 2>&1
rc=$?
write_log "[INFO]" "cleaning up tmp files"
cleanup_tmp

if [ $rc -eq 0 ] ; then
  write_log "[INFO]" "Success creating video file: $output_file"
  touch -t $creation_date $output_file
  exit 0
else
  write_log "[ERROR]" "Failed to create video, ffmpeg returned error see log file $log_file for details"
  exit 1
fi
