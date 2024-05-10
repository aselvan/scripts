#!/usr/bin/env bash
#
# parallel_dd.sh --- Run dd in parallel to copy image to multiple devices
#
# The assumption here is that if we run dd in parallel the throughput can 
# be much better than running in serial i.e. one by one if the destination 
# devices are on separage USB bus so they don't compete for I/O.
#
# Required: tee, dd, pv (for progress install with "apt-get|brew install pv")
#
# Author:  Arul Selvan
# Created: May 10, 2024
#
# Version History:
#   May 10, 2024 --- Original version
#

# version format YY.MM.DD
version=24.05.10
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Run dd in parallel to copy image to multiple devices."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="i:l:s:vh?"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

device_list=""
image_file=""
dd_bs="32"

usage() {
  cat << EOF
$my_title

Usage: $my_name [options]
  -i <image> ---> The disk image to write to multiple devices 
  -l <list>  ---> list of output devices write image
  -s <size>  ---> buffer size (megabyte) argument for dd [default: $dd_bs]
  -v         ---> enable verbose, otherwise just errors are printed
  -h         ---> print usage/help

example: $my_name -i myimage -l "/dev/sdb /dev/sdb /dev/sdc"
  
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
    i)
      image_file="$OPTARG"
      ;;
    l)
      device_list="$OPTARG"
      ;;
    s)
      dd_bs="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check for root, pv etc
check_root
check_installed pv

# check required args
if [ -z "$image_file" ] || [ -z "$device_list" ] ; then
  log.error "Missing required arguments! See usage below"
  usage
fi

# set correct flag for buffer size depending on MacOS or Linux
if [ "$os_name" = "Darwin" ] ; then
  dd_bs="${dd_bs}m"
else
  dd_bs="${dd_bs}M"
fi

# construct dd chain for parallel run
dd_chain=""
for dev in $device_list ; do
  dd_chain="$dd_chain >(dd of=$dev bs=$dd_bs >>$my_logfile 2>&1)"
done

# capture output of tee going to stdout to dev/null
dd_chain="$dd_chain | dd of=/dev/null >/dev/null 2>&1"

# confirm
confirm_action "WARNING: writing to \"$device_list\""
if [ $? -eq 0 ] ; then
  log.warn "Aborting..."
  exit 1
fi

# finally execute dd in parallel.
# note: we need to do in subshell to avoid shell interpreting and messing things up
log.stat "Running ..."
full_command="pv $image_file | tee $dd_chain"
/usr/bin/env bash -c "$full_command" 2>&1 >> $my_logfile
log.stat "$my_name completed."
