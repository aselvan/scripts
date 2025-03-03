#!/usr/bin/env bash
################################################################################
#
# process.sh --- Wrapper script to show various process information.
#
# Author:  Arul Selvan
# Created: Jan 10, 2012
#
# See also: 
#   util.sh
#
################################################################################
#
# Version History:
#   Jan 10, 2012 --- Original version (moved from .bashrc)
#   Mar 2 , 2025 --- implemented additional funcions, move to git etc.
################################################################################

# version format YY.MM.DD
version=25.03.02
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Wrapper script to show various process information"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}
arp_entries="/tmp/$(echo $my_name|cut -d. -f1)_arp.txt"

# commandline options
options="c:p:n:vh?"

command_name=""
supported_commands="pid|info|myprocess|listen"
name=""
pid=-1
port=-1

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -c <command>   ---> command to run. See supported commands below [Default: $myprocess]
  -n             ---> name of process. Used for commands like pid|info 
  -p             ---> pid (or port) depending on command info or listen
  -v             ---> enable verbose, otherwise just errors are printed
  -h             ---> print usage/help

Supported commands: 
  $supported_commands  

example(s): 
  $my_name -c info -p 37747
  $my_name -c listen -p 443
  $my_name -c myprocess
  $my_name -c pid -n bash

EOF
  exit 0
}

show_pid() {
  if [ -z "$name" ] ; then
    log.error "pid command needs a name. See usage below"
    usage
  fi
  log.stat "pid(s) of $name: $(pidof $name)"
}

show_info() {
  if [ $pid -le 0 ] ; then
    log.error "info command needs a pid. See usage below"
    usage
  fi
  log.stat "List of resources owned by PID: $pid"
  sudo lsof -p $pid |awk '{print $1,$3, $5, $9}'

  log.stat "Process Info:"
  log.stat "%memory    %CPU    RSS(MB)    VSZ (MB)"
  ps -p$pid -opmem=,pcpu=,rss=,vsz= |awk '{print $1,"    ", $2, "    ", $3/1024,"    ", $4/1024}'
}

show_listen() {
  if [ $port -le 0 ] ; then
    log.error "info command needs a port. See usage below"
    usage
  fi
  log.stat "The process at listening state port $port are below"
  sudo lsof -i :$port -s TCP:LISTEN
}

show_myprocess() {
  log.stat "List of process owned by $USER"
  log.stat "PID\tProcess Name"
  ps -u $USER -o pid=,comm= | while IFS= read -r line; do
    # Extract PID and command name (unfortunately macOS allows space in process name
    # so we have to do it this way which is expensive)
    local pid=$(echo "$line" | awk '{print $1}')
    local comm=$(echo "$line" | awk '{print substr($0, index($0,$2))}')
    
    # Use -- to indicate the end of options
    log.stat "$pid\t$(basename -- "$comm")" $grey
  done
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
    n)
      name="$OPTARG"
      ;;
    p)
      pid="$OPTARG"
      port=$pid
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z "$command_name" ] ; then
  log.error "command argument is required! See usage below"
  usage
fi

# run different wrappes depending on the command requested
case $command_name in
  pid)
    show_pid
    ;;
  info)
    check_root
    show_info
    ;;
  myprocess)
    show_myprocess
    ;;
  listen)
    show_listen
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac
