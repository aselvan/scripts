#!/bin/bash
#
# geocode_media_files.sh --- add lat/lon to media files.
#
# While most phones & few gps enabled digital cameras add lat/lon to pictures/videos, 
# often times we endup with scanned images or old image files etc that don't have this 
# information which you may want to add or modify so tools like google photos, onedrive 
# photos, apple photo etc can catalogue your media based on lat/lon.
#
# pre-req: 
#   exiftool & jq (install as shown below)
#     brew install exiftool jq [MacOS]
#     apt-get install libimage-exiftool-perl jq [Linux]
#
#   API key (for converting address to lat/lon)
#     Goto positionstack.com and create a free account and get the API key. Yes its 
#     free and gives you 25,000 requests/month to get lat/lon from address. Once you 
#     get the API key create a file ~/.positionstack.key and place your key there for 
#     this script to use. (note: you have to renew every month for free tier!)
#
# Author  : Arul Selvan
# Version : Oct 11, 2022
#

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

# version format YY.MM.DD
version=22.10.11
my_name=`basename $0`
my_version="$my_name v$version"
os_name=`uname -s`
options="p:a:k:l:h"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
source_path=""
exiftool_bin="/usr/bin/exiftool"
timestamp=`date +%Y%m%d%H%M`
type_check=0
address=""
api_url="http://api.positionstack.com/v1/forward"
api_key_file="$HOME/.positionstack.key"
api_response="/tmp/${my_name}_api_response.txt"
api_key=""
latlon=""
lat=
lon=

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -p <name>    ---> file/path for single file (or quoted for wildcard)"
  echo "  -a <address> ---> Address (in quotes) to get lat/lon info to be added as metadata"
  echo "  -k <api_key> ---> API key from positionstack.com for geocoding. If not provided, attempt to read from $api_key_file"
  echo "  -l <lat,lon> ---> use this values in quotes separated by comma/space for lat/lon [note: -a arg will be ignored]"
  echo ""
  echo "example: $my_name -p photo.jpg -a \"1600 Amphitheatre Parkway Mountain View, CA 94043\""
  echo "example: $my_name -p \"/data/photos/*.jpg\" -l \"37.422288,-122.085652\"" 
  echo ""
  exit 0
}

# check if file is a media file that could support metadata
is_media() {
  local f=$1
  local mtype=`file -b --mime-type $f | cut -d '/' -f 2`

  case $mtype in 
    jpg|jpeg|JPEG|JPG|PDF|pdf|mpeg|MPEG|MP3|mp3|mp4|MP4|png|PNG)
      return 0
      ;;
    *)
    echo "[WARN] media type '$mtype' for file '$f' is unknown, skipping ..." | tee -a $log_file    
      return 1 
      ;;
  esac
}

check_http_status() {
  http_code=$1

  # add all http codes here, later.
  case $http_code in 
    200)
      # positionstack.com API is dumb, returns 200 for failures @#~!
      error_code=`cat $api_response | jq -r '.error.code'`
      if [ $error_code = null ] ; then
        return
      fi
      error_msg=`cat $api_response | jq -r '.message'`      
      echo "[ERROR] positionstack.com API returned error_code='$error_code'; error_message='$error_msg'" | tee -a $log_file
      ;;
    401)
      echo "[ERROR] 401 unauthorized, expired token or bad user/password?" | tee -a $log_file
      ;;
    422)
      echo "[ERROR] 422 unprocessable entity, throttling?" | tee -a $log_file
      ;;
    *)
      echo "[ERROR] $http_code unknown error!" | tee -a $log_file
      ;;
  esac
  exit 1
}

get_latlon() {
  # ensure we have address to work w/
  if [ -z $address ] ; then
    echo "[ERROR] address needed to get lat/lon, see usage below ..." | tee -a $log_file
    usage
  fi
  
  if [ -z $api_key ] ; then
    # attempt to get API key from $api_key_file
    if [ -f $api_key_file ] ; then
      api_key=`cat $api_key_file`
    else
      echo "[ERROR] no api-key provided for getting lat/lon from address!" | tee -a $log_file
      usage
    fi
  fi
  
  local uri="$api_url?access_key=$api_key&query=$address"
  echo "[INFO] making API ($api_url) call to convert address to lat/lon ..." | tee -a $log_file  
  local http_status=`curl -s -w "%{http_code}" -o $api_response "$uri"`
  check_http_status $http_status

  lat=`cat $api_response | jq '.data[0].latitude'`
  lon=`cat $api_response | jq '.data[0].longitude'`

  if [ -z $lat ] || [ -z $lon ] ; then
    echo "[ERROR] address to lat/lon API failed to return geo cords!"
    exit
  fi
}

# ----------  main --------------
# parse commandline options
while getopts $options opt; do
  case $opt in
    p)
      source_path="$OPTARG"
      ;;
    a)
      address=`echo $OPTARG|jq -Rr @uri` 
      ;;
    k)
      api_key="$OPTARG"
      ;;
    l)
      prev_ifs="$IFS"
      IFS=', '
      latlon=($OPTARG)
      lat=${latlon[0]}
      lon=${latlon[1]}
      if [ -z $lat ] || [ -z $lon ] ; then
        echo "[ERROR] unable to parse lat/lon from '$latlon', see usage below"
        usage
      fi
      IFS="$prev_ifs"
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
echo "[INFO] $my_version" | tee -a $log_file

if [ $os_name = "Darwin" ]; then
  exiftool_bin=/usr/local/bin/exiftool
fi

# ensure exiftool is available
if [ ! -e $exiftool_bin ] ; then
  echo "[ERROR] $exiftool_bin is required for this script to work" | tee -a $log_file
  exit 1
fi

if [ -z "$source_path" ] ; then
  echo "[ERROR] required arguments missing i.e. path/name" | tee -a $log_file
  usage
fi

# if lat/lon provided via cmdline, use it otherwise make API call using address
if [ -z $lat ] || [ -z $lon ] ; then
  echo "[INFO] lat/lon ($lat/$lon) either empty or not provided, attempting to use address ..."| tee -a $log_file
  get_latlon
fi

# check if source path is a single file
if [ -f "$source_path" ] ; then
  file_list="$source_path"
else
  dir_name=$(dirname "$source_path")
  file_name=$(basename "$source_path")
  file_list=`ls -1 $dir_name/$file_name`
fi

for fname in ${file_list} ;  do
  is_media $fname
  if [ $? -ne 0 ] ; then
    continue
  fi
  # save create date (if present) so we can reset OS timestamp since adding GPS
  # data and overwriting original will wipe file's OS timestamp.
  create_date=`$exiftool_bin -d "%Y%m%d%H%M.%S" -createdate $fname | awk -F: '{print $2;}'`  
  echo "[INFO] adding GPS ($lat, $lon) to '$fname' ..." | tee -a $log_file
  $exiftool_bin -GPSLatitude*=$lat -GPSLongitude*=$lon -overwrite_original $fname 2>&1 >> $log_file
  if [ ! -z $create_date ] ; then
    touch -t $create_date $fname
  fi
done
