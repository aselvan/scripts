#!/usr/bin/env bash
#
# megapixel.sh --- Prints megapixel value from width & height or jpg file
#
#
# Author:  Arul Selvan
# Created: Jul 19, 2022
#

# version format YY.MM.DD
version=23.11.14
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Prints megapixel value using width & height or jpg file"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="g:f:h?"
geometry=""
jpg_file=""
width=1
height=1
megapixel=0
million=1000000

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

$my_name - $my_title

Usage: $my_name [options]
  -g <geometry> ---> width & height to convert to mega pixel
  -f <jpg>      ---> read megapixel from image if present or calculate based on width/height
  -h            ---> print usage/help

example: $my_name -g 4096x2048
example: $my_name -f /path/file.jpg

EOF
  exit 0
}

megapixel_from_geometry() {
  # get width & height
  IFS="x" read width height <<< "$geometry"

  megapixel=$(echo "scale=2; ($width * $height) / $million" | bc)
  log.stat "$geometry = ${megapixel} MP" $green

  exit 0
}

megapixel_from_file() {
  local width_height_megapixel=$(exiftool -s -csv -ImageWidth -ImageHeight -Megapixels $jpg_file|awk -F, 'FNR==2 {print $2 "," $3 "," $4}')
  if [ -z "$width_height_megapixel" ] ; then
    log.error "Unable to read width, height & megapixel from file!"
    exit 2
  fi
  # get width & height
  IFS="," read width height megapixel <<< "$width_height_megapixel"
  if [ -z $megapixel ] ; then
    megapixel=$(echo "scale=2; ($width * $height) / $million" | bc)
    log.stat "Calculated: Megapixel: ${megapixel} MP ; Geometry: ${width}x${height} " $green
  else
    log.stat "From Image: Megapixel: ${megapixel} MP ; Geometry: ${width}x${height}" $green
  fi

  exit 0
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init 

# parse commandline options
while getopts $options opt ; do
  case $opt in
    g)
      geometry="$OPTARG"
      megapixel_from_geometry
      ;;
    f)
      jpg_file="$OPTARG"
      megapixel_from_file
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

usage
