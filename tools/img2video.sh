#!/bin/bash
#  
# img2video.sh --- script to combine images to generate a video file
#
# Reads all images provided and generates a video file. The order of files
# used to create video will be dictaed by each file's OS timestamp in 
# reversed order i.e. most recent files first. 
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
version=23.03.06
my_name=`basename $0`
my_version="$my_name v$version"
options="i:a:s:o:f:t:h?"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
scale="2400:1600"
video_codec="-vcodec libx264"
frame_rate="1/7"
filter_complex="scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2"
image_wildcard="*.jpg"
audio_file=""
title_image=""
output_file="output.mp4"

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -i <image[s]>    --> input images [default: $image_wildcard]"
  echo "  -t <title_image> --> title image to use, it must exist on same path and writable [optional]"
  echo "  -a <mp3>         --> mp3 audio for adding background [optional]"
  echo "  -s <scale>       --> scale images to width:height [default: $scale]"
  echo "  -f <framerate>   --> framerate 1/sec [default: $frame_rate]"
  echo "  -o <output>      --> filename for output video [default: $output_file]"
  echo ""
  echo "example: $my_name -t mytitle.png -i \"$image_wildcard\" -a background.mp3 -s $scale -o $output_file"
  echo ""
  exit 0
}

# ensure ffmpeg is available
which ffmpeg >/dev/null 2>&1
if [ $? -ne 0 ] ; then
  echo "[ERROR] ffmpeg is required for this script to work, install it first [ex: brew install ffmpeg]."
  exit 1
fi

# ----------  main --------------
# parse commandline options
while getopts $options opt; do
  case $opt in
    i)
      image_wildcard="$OPTARG"
      ;;
    t)
      title_image="$OPTARG"
      # update current time so this file is sorted at the top by -pattern_type glob option
      touch $title_image
      ;;
    a)
      audio_file="-i $OPTARG"
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

if [ -f $log_file ] ; then
  rm $log_file
fi


echo "[INFO] $my_version starting ..." |tee $log_file
echo "[INFO] creating video file using all images found at `pwd`/$image_wildcard ..." |tee -a $log_file
ffmpeg -framerate $frame_rate -pattern_type glob -i "$image_wildcard" $audio_file $video_codec -filter_complex "$filter_complex" -pix_fmt yuv420p -r 30 -shortest -y $output_file >> $log_file 2>&1
echo "[INFO] Created video file: `pwd`/$output_file" | tee -a $log_file
