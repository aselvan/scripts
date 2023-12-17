#
# logger.sh --- This script is meant to be included in main script for logging functions.
#
#
# Author:  Arul Selvan
# Created: Nov 14, 2023
#
logger_file=""
logger_init=0
verbose=0
failure=0
grey=30
red=31
green=32
yellow=33
blue=34

# note: if logger filename is not provided on log.init by caller, just log to console

# -- Log functions ---
log.init() {
  # first check if we are called already, then do nothing
  if [ $logger_init -eq 1 ] ; then
    return
  fi
  logger_init=1
  logger_file=$1
  if [ -f "$logger_file" ] ; then
    rm -f $logger_file
  fi
  if [ ! -z "$logger_file" ] ; then
    echo -e "\e[0;${blue}m$my_version, `date +'%m/%d/%y %r'` \e[0m" | tee -a $logger_file
  else
    echo -e "\e[0;${blue}m$my_version, `date +'%m/%d/%y %r'` \e[0m" 
  fi
}

log.info() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  if [ ! -z "$logger_file" ] ; then  
    echo -e "\e[0;${green}m$msg\e[0m" | tee -a $logger_file
  else
    echo -e "\e[0;${green}m$msg\e[0m" 
  fi
}

log.debug() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  if [ ! -z "$logger_file" ] ; then  
    echo -e "\e[1;${grey}m$msg\e[0m" | tee -a $logger_file
  else
    echo -e "\e[1;${grey}m$msg\e[0m"
  fi
}

log.stat() {
  log.init
  local msg=$1
  local color=$2
  if [ -z $color ] ; then
    color=$blue
  fi
  if [ ! -z "$logger_file" ] ; then
    echo -e "\e[0;${color}m$msg\e[0m" | tee -a $logger_file 
  else
    echo -e "\e[0;${color}m$msg\e[0m"
  fi
}

log.warn() {
  log.init
  local msg=$1
  if [ ! -z "$logger_file" ] ; then  
    echo -e "\e[0;${yellow}m$msg\e[0m" | tee -a $logger_file
  else
    echo -e "\e[0;${yellow}m$msg\e[0m"
  fi
}

log.error() {
  log.init
  local msg=$1
  if [ ! -z "$logger_file" ] ; then  
    echo -e "\e[0;${red}m$msg\e[0m" | tee -a $logger_file
  else
    echo -e "\e[0;${red}m$msg\e[0m"
  fi
}
