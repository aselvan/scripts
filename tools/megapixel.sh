#!/usr/bin/env bash
#
# megapixel.sh --- Converts to megapixel value of width & height
#
#
# Author:  Arul Selvan
# Created: Jul 19, 2022
#

# version format YY.MM.DD
version=23.11.14
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Converts width & height to megapixel value"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="g:h?"
geometry=""
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
     -h            ---> print usage/help

  example: $my_name -g 4096x2048
  
EOF
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
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z "$geometry" ] ; then
  log.error "Required argument 'geometry' missing!"
  usage
fi

# get width & height
IFS="x" read width height <<< "$geometry"

megapixel=$(echo "scale=2; ($width * $height) / $million" | bc)
log.stat "$geometry = $megapixel megapixel" $green
