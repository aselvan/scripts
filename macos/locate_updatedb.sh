#!/usr/bin/env bash
################################################################################
# locate_updatedb.sh --- Builds locate db for locate command. 
#
# There is a native service /System/Library/LaunchDaemons/com.apple.locate.plist
# but seem to be either not running or disabled or deprecated in favor of the 
# stupid Spotlight which is a CPU hog. This script can be run as cronjob to 
# build locate DB with a desired frequency (recomended to run nightly every day).
#
# Author:  Arul Selvan
# Version: Aug 9, 2014
################################################################################
#
# Version History:
#   Aug 9,  2014 --- Original version 
#   Feb 23, 2025 --- moved to github and modified to match scripts in this repo
################################################################################

# version format YY.MM.DD
version=25.02.23
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Builds locate db for locate command."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="vh?"

locate_updatedb_bin="/usr/libexec/locate.updatedb"
locate_database="/var/db/locate.database"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -v  ---> enable verbose, otherwise just errors are printed
  -h  ---> print usage/help

example(s): 
  $my_name 
  
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

# parse commandline options
while getopts $options opt ; do
  case $opt in
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# need root
check_root

log.stat "Building locatedb: $locate_database ..."

# note: the locate.updatedb script is stupid and doesn't work if we aren't in that directory!
cd /usr/libexec/

$locate_updatedb_bin >> $my_logfile 2>&1

log.stat "Total runtime: $(elapsed_time)"

