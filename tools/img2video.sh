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
version=23.03.19
my_name=`basename $0`
my_version="$my_name v$version"
options="i:a:s:o:f:t:h?"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
image_list_file="image_list.txt"
scale="2400:1600"
video_codec="-vcodec libx264"
frame_rate="0.25"
filter_complex="scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2"
image_wildcard=".jpg|.JPG"
audio_file=""
title_text=""
output_file="output.mp4"
title_image="title.jpg"
title_background="blue"
title_foreground="white"
title_font="Chalkboard-SE-Bold" # This is macOS font found @ /System/Library/Fonts/Supplemental/
title_font_size=75
title_size="1600x1200"
cmdline_args=`printf "%s " $@`
IFS_old=$IFS

usage() {
cat << EOF
  Usage: $my_name [options]
    -i <images]>   --> regex for input images in current dir [default: "$image_wildcard"]
    -t <text>      --> text can contain '\n' for multi-line to create a title image [optional]
    -a <mp3>       --> mp3 audio for adding background [optional]
    -s <scale>     --> scale images to width:height [default: $scale]
    -f <framerate> --> framerate image/sec i.e. 1 means 1 image/sec [default: $frame_rate]"
    -o <output>    --> filename for output video [default: $output_file]
  
   example: $my_name -t "Vacation 2023\nPictures from our vacation" -i "$image_wildcard" -a background.mp3 -s $scale -o $output_file

EOF
  exit 0
}

cleanup_tmp() {
  if [ -f $title_image ] ; then
    rm $title_image
  fi
  if [ -f $image_list_file ] ; then
    rm $image_list_file
  fi
}

# for now hardcoded values, can expand to take arguments for font/image size etc.
create_title_image() {
  echo "[INFO] creating video title image $title_image ..." |tee -a $log_file
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
}

# ----------  main --------------
# ensure ffmpeg is available
which ffmpeg >/dev/null 2>&1
if [ $? -ne 0 ] ; then
  echo "[ERROR] ffmpeg is required for this script to work, install it first [ex: brew install ffmpeg]."
  exit 1
fi

if [ -f $log_file ] ; then
  rm $log_file
fi
echo "[INFO] $my_version" |tee $log_file

# parse commandline options
while getopts $options opt; do
  case $opt in
    i)
      image_wildcard="$OPTARG"
      ;;
    t)
      title_text="$OPTARG"
      create_title_image
      ;;
    a)
      if [ -f $OPTARG ] ; then
        audio_file="-stream_loop -1 -i $OPTARG -shortest -map 0:v -map 1:a"
      else
        echo "[WARN] audio file ($OPTARG) does not exists, continuing w/ out audio" | tee -a $log_file
      fi
      ;;
    s)
      scale="$OPTARG"
      filter_complex="scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2"
      ;;
    o)
      output_file="$OPTARG"
      ;;
    f)
      frame_rate="$OPTARG"
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

# create the timeline based order we want
create_sorted_filelist

echo "[INFO] creating video using all images found at: `pwd`/$image_wildcard ..." |tee -a $log_file
ffmpeg -f concat -safe 0 -r $frame_rate -i $image_list_file $audio_file $video_codec -filter_complex "$filter_complex" -pix_fmt yuv420p -r 30 -y $output_file >> $log_file 2>&1
if [ $? -eq 0 ] ; then
  echo "[INFO] Success creating video file: $output_file" | tee -a $log_file
else
  echo "[ERROR] Failed to create video, ffmpeg returned error see log file $log_file for details " | tee -a $log_file
fi
echo "[INFO] cleaning up tmp files" | tee -a $log_file
cleanup_tmp
echo "[INFO] all done" | tee -a $log_file
