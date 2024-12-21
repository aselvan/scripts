#!/usr/bin/env bash
#
# docker.sh --- Wrapper for many useful docker commands.
#
# Author:  Arul Selvan
# Created: Jan 10, 2012
#
# Version History:
#   Jan 10, 2012 --- Original version (moved from .bashrc)
#

# version format YY.MM.DD
version=2012.01.10
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Misl docker tools wrapper all in one place"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}
arp_entries="/tmp/$(echo $my_name|cut -d. -f1)_arp.txt"

# commandline options
options="c:s:n:C:vh?"

command_name=""
supported_commands="rm|rmi|images|shell|exec|clean"
string=""
container_name=""
container_command=""

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -c <command>     ---> command to run [see supported commands below]  
  -s <string>      ---> optionally used by "images" command to search for specific string
  -n <string>      ---> name of the container used by "shell|exec" commands
  -C <string>      ---> name of command used by "exec" command
  -v               ---> enable verbose, otherwise just errors are printed
  -h               ---> print usage/help

Supported commands: $supported_commands  
example: $my_name -c tohex -n 1000
  
EOF
  exit 0
}


function do_images() {
  if [ ! -z $string ] ; then
    docker images | grep $string | tr -s ' ' | cut -d ' ' -f 3
  else
    docker images -q
  fi
}

function do_rm() {
  docker rm -vf $(docker ps -a -q) 2>/dev/null || echo "No more containers to remove."  
}

function do_rmi() {
  docker rmi $(docker images -q) 2>/dev/null || echo "No more images to remove."  
}

function do_clean() {
  do_rm
  do_rmi
}

function do_shell() {
  if [ -z $container_name ]; then
    log.error "missing container name to get a shell, see usage"
    usage
  fi
  docker exec -it `docker ps -f name=$container_name -q` /bin/sh
}

function do_exec() {
  if [ -z $container_name ] || [ -z $container_command ] ; then
    log.error "missing container name and/or command name to execute, see usage"
    usage
  fi
  docker exec `docker ps -f name=$container_name -q` $container_command
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
    c)
      command_name="$OPTARG"
      ;;
    s)
      string="$OPTARG"
      ;;
    n)
      container_name="$OPTARG"
      ;;
    C)
      container_command="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check for any commands
if [ -z "$command_name" ] ; then
  log.error "Missing arguments, see usage below"
  usage
fi

# run different wrappes depending on the command requested
case $command_name in
  images)
    do_images
    ;;
  rm)
    do_rm
    ;;
  rmi)
    do_rmi
    ;;
  shell)
    do_shell
    ;;
  exec)
    do_exec
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac
