#!/usr/bin/env bash
#
################################################################################
# veracrypt.sh --- Wrapper over veracrypt to mount/unmount encrypted volumes
#
# Note: If no password is provided, script will look for password in the environment 
# variable VERACRYPT_PASSWORD but -p <password> argument will override password. 
#
# PreReq: veracrypt software must be installed (https://www.veracrypt.fr/en/Downloads.html)
#
# Author:  Arul Selvan
# Version: Mar 18. 2023
################################################################################
#
# Version History
#   Mar 18, 2023 --- original version
#   Jan 17, 2024 --- modified to use logger and function includes
#   Feb 26, 2025 --- added flag to allow mount over-ride dir that are in path
################################################################################

# version format YY.MM.DD
version=25.02.26
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Wrapper over veracrypt to mount/unmount encrypted volumes."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="c:p:m:u:lvh?"

password="${VERACRYPT_PASSWORD:-}"
# volume will be mounted at $mount_point/$container_file 
container_file=""
mount_point="/mnt/veracrypt"
container_file="$HOME/data/encrypted/vc56g_exfat.hc"
veracrypt_bin="/usr/bin/veracrypt"
veracrypt_opt="--allow-insecure-mount "

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -m <path>      ---> Mount point path [default: $mount_point]
  -c <container> ---> encrypted container file to mount as volume [default: $container_file]
  -p <password>  ---> mount password for the encrypted container
  -u <path>      ---> unmount the currently mounted volume
  -l             ---> list all veracrypt volumes
  -v             ---> enable verbose, otherwise just errors are printed
  -h             ---> print usage/help

example(s): 
  $my_name -m $mount_point -c $container_file -p "password123"
  $my_name -u $mount_point
  
EOF
  exit 1
}

init_osenv() {
  if [ $os_name = "Darwin" ] ; then
    mount_point="$HOME/mnt/veracrypt"
    veracrypt_bin="/Applications/VeraCrypt.app/Contents/MacOS/VeraCrypt"
  else
    check_root
  fi
}

umount_veracrypt() {
  log.stat "Unmounting $mount_point volume ..."
  $veracrypt_bin -t -d $mount_point
  if [ $? -eq 0 ] ; then
    log.stat "Successfully umounted volume at $mount_point"
    exit 0
  else
    log.error "Failed to umount container '$container_file'"
    exit 1
  fi
}

list_volumes() {
  log.stat "list of volumes mounted in this host below"
  $veracrypt_bin -t -l
  exit 0
}

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
init_osenv

# parse commandline options
while getopts $options opt; do
  case $opt in
    m)
      mount_point="$OPTARG"
      ;;
    u)
      mount_point="$OPTARG"      
      umount_veracrypt
      ;;
    l)
      list_volumes 
      ;;
    p)
      password="$OPTARG"
      ;;
    c)
      container_file="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check for password
if [ -z "$password" ] ; then
  log.error "No password found or provided, See the usage below ..."
  usage
fi

# check for container file
if [ -z "$container_file" ] ; then
  log.error "Container file is empty. See the usage below ..."
  usage
fi

if [ ! -d "$mount_point" ] ; then
  log.error "Mount point path '$mount_point' does not exist..."
  usage
fi

# mount the volume
log.stat "Mounting $container_file at mount point $mount_point ..."
$veracrypt_bin -t -k "" --pim=0 --protect-hidden=no --slot 1 --mount-options=timestamp $veracrypt_opt --password "$password" --mount $container_file $mount_point
if [ $? -eq 0 ] ; then
  log.stat "Successfully mounted volume at $mount_point"
  exit 0
else
  log.error "Failed to mount container '$container_file'"
  exit 1
fi
