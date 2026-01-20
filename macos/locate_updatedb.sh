#!/usr/bin/env bash
################################################################################
# locate_updatedb.sh --- Builds locate db for locate command. 
#
# There is a native service /System/Library/LaunchDaemons/com.apple.locate.plist
# but seem to be either not running or disabled or deprecated in favor of the 
# stupid Spotlight which is a CPU hog. This script can be run as cronjob to 
# build locate DB with a desired frequency (recomended to run nightly every day).
#
# NOTE: Apple version of the locate.updatedb script runs as 'nobody' user and
# as such can't include index for /Users/ directory. In this script we copy 
# the macOS provided file, modify the 'nobody' to the username we want and 
# run the build so our user files are included in the indexing.
#
# Author:  Arul Selvan
# Version: Aug 9, 2014
################################################################################
#
# Version History:
#   Aug 9,  2014 --- Original version 
#   Feb 23, 2025 --- moved to github and modified to match scripts in this repo
#   Feb 24, 2025 --- Use our own copy of locate.updatedb to include /User dirs
################################################################################

# version format YY.MM.DD
version=25.02.24
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Builds locate db for locate command."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="u:vh?"

locate_updatedb_path="/usr/libexec"
locate_updatedb_bin="locate.updatedb"
locate_database="/var/db/locate.database"
username="arul"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -u  ---> user name to run locatedb build [Default: $username]
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
    u)
      username="$OPTARG"
      ;;
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
log.stat "Building locatedb with user ($username): $locate_database ..."

# fixup the locate.updatedb script to use our username
cat ${locate_updatedb_path}/${locate_updatedb_bin} |sed s/nobody/$username/g > /tmp/${locate_updatedb_bin}
chmod +x /tmp/${locate_updatedb_bin}

# note: the locate.updatedb script is stupid and doesn't work if we aren't in that directory!
cd /tmp
`pwd`/$locate_updatedb_bin >> $my_logfile 2>&1

log.stat "Total runtime: $(elapsed_time)"

