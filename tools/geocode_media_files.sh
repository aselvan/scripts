#!/usr/bin/env bash
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
# See Also: reset_file_timestamp.sh copy_metadata.sh exif_check.sh geocode_media_files.sh add_metadata.sh reset_media_timestamp.sh exif_check.sh
#
# Version History
# --------------
#   22.10.11 --- Initial version
#   24.04.07 --- Added see also
#
version=24.04.07
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Add lat/lon to media files"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="p:a:k:l:h"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

source_path=""
# exiftool opt to ignore minor errors
exiftool_opt="-m"
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
cat << EOF

$my_name - $my_title

Usage: $my_name [options]
  -p <name>    ---> file/path for single file (or quoted for wildcard)
  -a <address> ---> Address (in quotes) to get lat/lon info to be added as metadata
  -k <api_key> ---> API key from positionstack.com for geocoding. If not provided, attempt to read from $api_key_file
  -l <lat,lon> ---> use this values in quotes separated by comma/space for lat/lon [note: -a arg will be ignored]
  -v           ---> enable verbose, otherwise just errors are printed

  example: $my_name -p photo.jpg -a "1600 Amphitheatre Parkway Mountain View, CA 94043"
  example: $my_name -p "/data/photos/*.jpg" -l "37.422288,-122.085652"

  See Also: reset_file_timestamp.sh copy_metadata.sh exif_check.sh geocode_media_files.sh add_metadata.sh reset_media_timestamp.sh exif_check.sh

EOF
  exit 0
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
      log.error "positionstack.com API returned error_code='$error_code'; error_message='$error_msg'" 
      ;;
    401)
      log.error "401 unauthorized, expired token or bad user/password?" 
      ;;
    422)
      log.error "422 unprocessable entity, throttling?" 
      ;;
    *)
      log.error "$http_code unknown error!"
      ;;
  esac
  exit 1
}

get_latlon() {
  # ensure we have address to work w/
  if [ -z $address ] ; then
    log.error "address needed to get lat/lon, see usage below ..."
    usage
  fi
  
  if [ -z $api_key ] ; then
    # attempt to get API key from $api_key_file
    if [ -f $api_key_file ] ; then
      api_key=`cat $api_key_file`
    else
      log.error "no api-key provided for getting lat/lon from address!"
      usage
    fi
  fi
  
  local uri="$api_url?access_key=$api_key&query=$address"
  log.stat "making API ($api_url) call to convert address to lat/lon ..."  
  local http_status=`curl -s -w "%{http_code}" -o $api_response "$uri"`
  check_http_status $http_status

  lat=`cat $api_response | jq '.data[0].latitude'`
  lon=`cat $api_response | jq '.data[0].longitude'`

  if [ -z $lat ] || [ -z $lon ] ; then
    log.error "address to lat/lon API failed to return geo cords!"
    exit
  fi
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile

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
        log.error "unable to parse lat/lon from '$latlon', see usage below"
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

# ensure exiftool is available
which exiftool >/dev/null 2>&1
if [ $? -ne 0 ] ; then
  log.error "exiftool is required for this script to work, install it first [ex: brew install exiftool]."
  exit 1
fi

if [ -z "$source_path" ] ; then
  log.error "Required arguments missing i.e. path/name"
  usage
fi

# if lat/lon provided via cmdline, use it otherwise make API call using address
if [ -z $lat ] || [ -z $lon ] ; then
  log.stat "lat/lon ($lat/$lon) either empty or not provided, attempting to use address ..."
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
  create_date=`exiftool $exiftool_opt -d "%Y%m%d%H%M.%S" -createdate $fname | awk -F: '{print $2;}'`  
  log.stat "adding GPS ($lat, $lon) to '$fname' ..." $green
  exiftool $exiftool_opt -GPSLatitude*=$lat -GPSLongitude*=$lon -overwrite_original $fname 2>&1 >> $my_logfile
  if [ ! -z $create_date ] ; then
    touch -t $create_date $fname
  fi
done
