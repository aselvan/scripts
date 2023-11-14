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
green=32
red=31
blue=34

# -- Log functions ---
log.init() {
  logger_file=$1
  if [ $logger_init -eq 1 ] ; then
    return
  fi

  if [ -z $logger_file ] ; then
    echo "FATAL: log filename is required for logger.sh ... exiting!"
    exit 1
  fi
  logger_init=1
  if [ -f $logger_file ] ; then
    rm -f $logger_file
  fi
  echo -e "\e[0;34m$my_version, `date +'%m/%d/%y %r'` \e[0m" | tee -a $logger_file
}

log.info() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[0;32m$msg\e[0m" | tee -a $logger_file 
}
log.debug() {
  if [ $verbose -eq 0 ] ; then
    return;
  fi
  log.init
  local msg=$1
  echo -e "\e[1;30m$msg\e[0m" | tee -a $logger_file 
}
log.stat() {
  log.init
  local msg=$1
  local color=$2
  if [ -z $color ] ; then
    color=$blue
  fi
  echo -e "\e[0;${color}m$msg\e[0m" | tee -a $logger_file 
}
log.warn() {
  log.init
  local msg=$1
  echo -e "\e[0;33m$msg\e[0m" | tee -a $logger_file 
}
log.error() {
  log.init
  local msg=$1
  echo -e "\e[0;31m$msg\e[0m" | tee -a $logger_file 
}

