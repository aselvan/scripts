#!/usr/bin/env bash
#
# util.sh --- Wrapper for many useful utility commands.
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
my_title="Misl util tools wrapper all in one place"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}
arp_entries="/tmp/$(echo $my_name|cut -d. -f1)_arp.txt"

# commandline options
options="c:n::vh?"

command_name=""
supported_commands="tohex|todec"
number=""

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -c <command>     ---> command to run [see supported commands below]  
  -n <number>      ---> used by all commands that requires a number argument.
  -v               ---> enable verbose, otherwise just errors are printed
  -h               ---> print usage/help

Supported commands: $supported_commands  
example: $my_name -c tohex -n 1000
  
EOF
  exit 0
}


function do_tohex() {
  if [ -z $number ] ; then
    log.error "tohex needs a number, see usage"
    usage
  fi
  log.stat "\tDecimal:Hex: $number:`printf "0x%x" $number`"
}

function do_todec() {
  if [ -z $number ] ; then
    log.error "todec needs a number, see usage"
    usage
  fi
  log.stat "\tHex:Decimal: $number:`printf "%d" $number`"
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

# pastebuffer depending on OS [note: used to copy certain things to paste buffer like ip, macc etc]
if [ $os_name = "Darwin" ]; then
  pbc='pbcopy'
else
  pbc='xsel --clipboard --input'
fi


# parse commandline options
while getopts $options opt ; do
  case $opt in
    c)
      command_name="$OPTARG"
      ;;
    n)
      number="$OPTARG"
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
  tohex)
    do_tohex
    ;;
  todec)
    do_todec
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac
