#!/usr/bin/env bash
#
# exif_check.sh --- Wrapper over exiftool to get various metadata.
#
# pre-req: exiftool
# install: 
#  brew install exiftool [MacOS]
#  apt-get install libimage-exiftool-perl [Linux]
#
# Author : Arul Selvan
# Version: Jan 13, 2023
#
# Version History:
#   Jan 13, 2023 --- Original version
#   Dec 9,  2024 --- Added more functions consolidated from bashrc
#

# version format YY.MM.DD
version=24.12.09
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Wrapper over exiftool to get various metadata."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="p:dlczvh"

format_file="/tmp/$(echo $my_name|cut -d. -f1).fmt"
format_file_string=""
source_path=""
zap_metadata=0

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -p <path>  ---> Directory path or file or wildcard
  -l         ---> print lat/lon
  -d         ---> print date
  -c         ---> print camera model
  -z         ---> zap/clear all metadata [Note: all other options are ignored if option enabled]
  -v         ---> verbose mode prints info messages, otherwise just errors are printed
  -h         ---> print usage/help

example: $my_name -p /path/*.jpg -g -d

EOF
  exit 0
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
    d)
      format_file_string="$format_file_string , Date: \$DateTimeOriginal"
      ;;
    l)
      format_file_string="$format_file_string , Lat: \$gpslatitude, Lon: \$gpslongitude"
      ;;
    c)
      format_file_string="$format_file_string , Camera: \$model"
      ;;
    z)
      zap_metadata=1
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z "$source_path" ] ; then
  log.error "Required argument i.e. path/name is missing!"
  usage
fi


# check if this run is to clear/zap metadata, if so do it and exit
if [ $zap_metadata -eq 1 ] ; then
  log.stat "Clearing all medatadata ..." $red
  exiftool -quiet -f -m -all= -overwrite_original $source_path
else
  echo $format_file_string > $format_file
  # run exiftool with our desired format.
  log.stat "`exiftool -quiet -f -p $format_file $source_path`" $green
fi

