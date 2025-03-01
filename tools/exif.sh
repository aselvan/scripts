#!/usr/bin/env bash
################################################################################
#
# exif.sh --- Wrapper script to prints various metadata
#
# pre-req: exiftool
#   MacOS: brew install exiftool
#   Linux: apt-get install libimage-exiftool-perl
#
# Author : Arul Selvan
# Version: Jan 13, 2023
#
# See also: 
#   add_metadata.sh copy_metadata.sh geocode_media_files.sh 
#   reset_file_timestamp.sh reset_media_timestamp.sh
################################################################################
#
# Version History:
#   Jan 13, 2023 --- Original version
#   Dec 9,  2024 --- Added more functions consolidated from bashrc
#   Mar 1,  2025 --- Moved megapixel function & made it command based vs options
################################################################################

# version format YY.MM.DD
version=25.03.01
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Wrapper script to prints various metadata."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="c:a:p:vh?"
command_name="date"
supported_commands="geo|date|megapixel|zap|camera"
format_file="/tmp/$(echo $my_name|cut -d. -f1).fmt"
format_file_string=""
source_path=""
arg=""
width=1
height=1
megapixel=0
million=1000000

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

usage() {
  cat << EOF
  
$my_name --- $my_title
Usage: $my_name [options]
  -c <command>  ---> command to run (see supported commands below) [Default: $command_name]
  -p <path>     ---> Directory path or file or wildcard depending on the command [Required]
  -a <arg>      ---> Optional argumenst to some commands like 'megapixel'
  -v            ---> verbose mode prints info messages, otherwise just errors are printed
  -h            ---> print usage/help

Supported commands: 
  $supported_commands
example(s): 
  $my_name -c geo -p /path/*.jpg
  $my_name -c megapizel -p file.jpg
  $my_name -c megapizel -a 1024x768 # shows would be megapixel value for image of that size

EOF
  exit 0
}

megapixel_from_geometry() {
  # get width & height
  IFS="x" read width height <<< "$arg"
  log.debug "Width: $width ; Height: $height"

  megapixel=$(echo "scale=2; ($width * $height) / $million" | bc)
  log.stat "$arg = ${megapixel} MP" $green
}

megapixel_from_file() {
  if [ -d "$source_path" ] ; then
    log.error "megapixel command needs file, but $source_path is a directory!"
    exit 10
  fi

  local width_height_megapixel=$(exiftool -s -csv -ImageWidth -ImageHeight -Megapixels $source_path|awk -F, 'FNR==2 {print $2 "," $3 "," $4}')
  if [ -z "$width_height_megapixel" ] ; then
    log.error "Unable to read width, height & megapixel from $source_path!"
    exit 2
  fi
  # get width & height
  IFS="," read width height megapixel <<< "$width_height_megapixel"
  if [ -z $megapixel ] ; then
    log.stat "`basename $source_path`: does not contain megapixel info, calculating based on geomerty"
    megapixel=$(echo "scale=2; ($width * $height) / $million" | bc)
    log.stat "Calculated: Megapixel: ${megapixel} MP ; Geometry: ${width}x${height} " $green
  else
    log.stat "`basename $source_path`: Megapixel: ${megapixel} MP ; Geometry: ${width}x${height}" $green
  fi
}

show_megapixel() {
  if [ -f "$source_path" ] ; then
    megapixel_from_file
  elif [ -d "$source_path" ] ; then
    log.error "megapixel command needs file, but $source_path is a directory!"
    exit 10
  elif [ ! -z $arg ] ; then
    megapixel_from_geometry
  else
    log.error "megapixel command needs file or geometry spec. See usage"
    usage
  fi
}

check_req_args() {
  if [ -z "$source_path" ] ; then
    log.error "Required argument i.e. path/name is missing! See usage below"
    usage
  fi
}

show_date() {
  check_req_args
  log.stat "`exiftool -quiet -f -p $format_file $source_path`" $green
}

show_geo() {
  check_req_args
  log.stat "`exiftool -quiet -f -p $format_file $source_path`" $green
}

show_camera() {
  check_req_args
  log.stat "`exiftool -quiet -f -p $format_file $source_path`" $green
}

zap_metadata() {
  check_req_args
  log.stat "Clearing all medatadata on $source_path ..." $red
  exiftool -quiet -f -m -all= -overwrite_original $source_path >> $my_logfile 2>&1
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

# check required tools
check_installed exiftool

format_file_string="\$FileName"
# parse commandline options
while getopts $options opt; do
  case $opt in
    p)
      source_path="$OPTARG"
      ;;
    c)
      command_name="$OPTARG"
      ;;
    a)
      arg="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# execute the command requested
case $command_name in
  geo)
    echo "\$FileName: Lat: \$gpslatitude, Lon: \$gpslongitude" > $format_file
    show_geo
    ;;
  date)
    echo "\$FileName: Date: \$DateTimeOriginal" > $format_file
    show_date
    ;;
  megapixel)
    show_megapixel
    ;;
  camera)
    echo "\$FileName: Camera: \$model" > $format_file
    show_camera
    ;;
  zap)
    zap_metadata
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac
