#!/usr/bin/env bash
################################################################################
# attr.sh --- wrapper over xatter (macOS) lsattr/chattr (linux)
#
#
# Author:  Arul Selvan
# Created: Aug 2, 2025
################################################################################
# Version History:
#   Aug 2,  2025 --- Original version
################################################################################

# version format YY.MM.DD
version=25.08.02
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="wrapper over xatter (macOS) lsattr/chattr (linux)"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="c:f:vh?"

command_name=""
supported_commands="show|clear"
command_help=0
file_name=""

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name -c command [options]
  -c <cmd>   ---> command to run [see supported commands below] -h to show command syntax
  -f <file>  ---> file to check attr information
  -v         ---> enable verbose, otherwise just errors are printed
  -h         ---> print usage/help

Supported commands: 
  $supported_commands

example(s): 
  $my_name -c show -f foo
  $my_name -c clear -f foo
  
EOF
  exit 0
}

check_command_help() {
  if [ $command_help -eq 1 ] ||  [ -z "$file_name" ]  ; then
    if [ -z $file_name ] ; then
      log.error "Need file name for the command: '${command_name}'"
    fi
    log.stat "Usage: $my_name -c $command_name -f foo.txt  # check attribute of foo.txt" $black
    exit 1
  fi
}

function not_implemented() {
  log.warn "Not implemented for $os_name yet, exiting..."
  exit 99
}

do_show_linux() {
  not_implemented
}

do_show_mac() {
  if xattr "$file_name" | grep -q . ; then
    xattr "$file_name"
  else
    log.warn "No extended attributes found for $file_name"
  fi
}

do_clear_linux() {
  not_implemented
}

do_clear_mac() {
  not_implemented
}

do_show() {
  log.debug "show attribute"
  check_command_help

  case $os_name in 
    Darwin)
      do_show_mac
      ;;
    Linux)
      do_show_linux
      ;;
    *)
      not_implemented
      ;;
  esac
}

do_clear() {
  log.debug "clear attribute"
  check_command_help

  case $os_name in 
    Darwin)
      do_clear_mac
      ;;
    Linux)
      do_clear_linux
      ;;
    *)
      not_implemented
      ;;
  esac
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
      if ! valid_command "$command_name" "$supported_commands" ;  then
        log.error "Unknown command: '${command_name}'. See usage for supported commands"
        usage
      fi
      ;;
    f) 
      file_name="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      if [[ -n "$command_name" ]] ; then
        command_help=1
      else
        usage
      fi
      ;;
  esac
done

# default is always show
if [ -z "$command_name" ]; then
  command_name=show
fi

# run different wrappes depending on the command requested
case $command_name in
  show)
    do_show
    ;;
  clear)
    do_clear
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac


