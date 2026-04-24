###############################################################################
#
# logger.sh --- include script for logging functionality (only for includes)
#
# Author:  Arul Selvan
# Created: Nov 14, 2023
#
# Wrapper for log functions used by all scripts. If a logger file name is 
# provided on log.init function, log messages are sent to file in addition
# to console, otherwise log messages are printed only on console.
#
################################################################################
# Version History:
#   Nov 14, 2023 --- Original version
#   Mar 9,  2025 --- Ensure logger file can be writable for effective user
#   Mar 18, 2025 --- Defined effective_user and replaced SUDO_USER usage.
#   Apr 24, 2026 --- Changed init function to create a world writable log file
################################################################################

logger_file=""
logger_init=0
verbose=0
failure=0
# foreground colors (add +10 for background)
grey=30
red=31
green=32
yellow=33
blue=34
magenta=55
cyan=36
white=37
black=39
default=$black

# -- Log functions ---
log.init() {
  # first check if we are called already, then do nothing
  if [ $logger_init -eq 1 ] ; then
    return
  fi
  logger_init=1
  logger_file=$1

  if [ ! -z "$logger_file" ] ; then
    # ensure log file created with umask 000 so anyone can write
    (umask 000 && touch $logger_file)
    
    # if this was a sudo run, just ensure file permission always stays world write
    if [ "$EUID" -eq 0 ] ; then
      chmod 666 $logger_file
    fi

    # empty file to start with
    echo -n > $logger_file
  fi

  # if logger filename is not provided, just log to console
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
