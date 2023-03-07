#!/bin/bash
#  
# img2video.sh --- combine images (jpg,png,etc) to a mp4 video
#
# Preq: ffmpeg utility must be installed (brew install ffmpeg)
#
# Author : Arul Selvan
# Version: Mar 6, 2023

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

#
# ffmpeg -framerate 1/6 -pattern_type glob -i '*.jpg' -i background.mp3 -vcodec libx264 -filter_complex "scale=2400:1600:force_original_aspect_ratio=decrease,pad=2400:1600:(ow-iw)/2:(oh-ih)/2" -pix_fmt yuv420p -r 30 -shortest image.mp4
#

my_name=`basename $0`
os_name=`uname -s`
options="i:a:s:o:f:h?"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
scale="2400:1600"
video_codec="-vcodec libx264"
frame_rate="1/7"
filter_complex="scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2"
image_wildcard="*.jpg"
audio_file=""
output_file="output.mp4"

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -i <image[s]>  --> input images. note: this can be wildcard like \"*.jpg\" in quotes"
  echo "  -a <mp3>       --> mp3 audio for adding background [optional]"
  echo "  -s <scale>     --> scale images to width:height. note: smaller size will be padded"
  echo "  -f <framerate> --> framerate 1/sec [default: $frame_rate]"
  echo "  -o <output>    --> filename for output video [default: $output_file]"
  echo ""
  echo "example: $my_name -i \"*.jpg\" -a background.mp3 -s 1200:800 -o myvideo.mp3"
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


echo "[INFO] $my_name starting ..." > $log_file

ffmpeg -framerate $frame_rate -pattern_type glob -i "$image_wildcard" $audio_file $video_codec -filter_complex "$filter_complex" -pix_fmt yuv420p -r 30 -shortest $output_file
