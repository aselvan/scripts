#!/usr/bin/env bash
################################################################################
# chrome.sh --- Wrapper utility for Chrome.app cleanup, status, search etc
#
# Author:  Arul Selvan
# Created: Jun 9, 2026
#
################################################################################
#
# Version History: (original & last 3)
#   Jun 9, 2026 --- Original version
################################################################################

# version format YY.MM.DD
version=26.06.09
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Chrome app cleanup,status,search etc"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
login_db_file="/tmp/$(echo $my_name|cut -d. -f1).db"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="c::a:vh?M"

arg=""
command_name=""
supported_commands="running|kill|login"
# if -h argument comes after specifiying a valid command to provide specific command help
command_help=0

google_chrome="Google Chrome.app"
login_db_src="$HOME/Library/Application Support/Google/Chrome/Default/Login Data"


usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name -c <command> [options]
  -c <command> [-h] ---> command to run [see supported commands below] -h to show command syntax
  -a <arg>          ---> arg can be user/website name (for use in 'login' command)
  -v                ---> enable verbose, otherwise just errors are printed
  -h                ---> print usage/help
  -M                ---> info on all commands, somewhat like unix manpage
NOTE: For commands requiring args add -h after the command to see command specific usage.
For a brief manpage of various commands, run $my_name -M

Examples: 
  $my_name -c running 

Supported commands: 
$(echo -e $supported_commands)


EOF
  exit 0
}

man_page() {
  log.stat "---------- Summary of all supported commands ---------- "
  log.stat "Command     Description" $cyan
  cat << EOF
kill     Kill all chrome processes
running  Check if any chrome processes are running
login    List user/password from login data for the site

EOF
  exit 0
}

do_kill() {
  log.stat "Check if Chrome is running..."
  do_running
  if [ $? -eq 0 ] ; then
    log.stat "  Killing all Chrome proecesses..."
    killall "$google_chrome"
  else
    log.warn "  No Chrome proceses found"
  fi
}

do_running() {
  check_root
  ps -ef |grep -i "$google_chrome" | grep -vi drive|grep -v grep >/dev/null 2>&1
  return $?
}

do_login() {
  check_installed sqlite3

  if [ $command_help -eq 1 ] ||  [ -z "$arg" ]  ; then
    log.stat "Usage: $my_name -c $command_name -a <string>  # string can be partial/full website or username" $black
    exit 1
  fi
  
  # cleanup left over from past run, shouldn't exists but check anyway.
  if [ -f $login_db ] ; then
    rm -f "$login_db"
  fi
  # create a tempfile
  login_db=$(mktemp $login_db_file)

  # copy the logindb to tmp file and make sure we remove on exit
  trap 'rm -f "$login_db"' EXIT
  cp "$login_db_src" "$login_db"

  log.stat "Looking up login data for $arg ..."
  # Capture output into an array (one element per row)
  mapfile -t rows < <(sqlite3 "$login_db" "select action_url,username_value,password_value from logins where action_url like '%$arg%';" 2>$my_logfile)

  # Check if the array size is greater than 1
  if [ "${#rows[@]}" -gt 1 ]; then
    log.stat "The query '$arg' returned ${#rows[@]} rows below. Change query to unique & try again."
    for row in "${rows[@]}"; do
      IFS='|' read -r url username password <<< "$row"
      log.stat "  URL: $url"
    done
  elif [ "${#rows[@]}" -eq 1 ] ; then
    log.debug "Results: ${rows[0]}"
    IFS='|' read -r url username password <<< "${rows[0]}"
    log.stat "  URL:  $url"
    log.stat "  User: $username"
    log.stat "  Pass: $password"
  else
    log.error "  No entry found!, rowcount=${#rows[@]}"
  fi
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

# enforce we are running macOS
check_mac

# parse commandline options
while getopts $options opt ; do
  case $opt in
    c)
      command_name="$OPTARG"
      ;;
    a)
      arg="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    M)
      man_page
      ;;
    ?|h|*)
      if [[ -n "$command_name" ]] && valid_command "$command_name" "$supported_commands" ; then
        command_help=1
      else
        usage
      fi
      ;;
  esac
done

# check for any commands
if [ -z "$command_name" ] ; then
  log.error "Missing command, see usage below"
  usage
fi

case $command_name in 
  kill)
    do_kill
    ;;
  login)
    do_login
    ;;
  running)
    do_running
    if [ $? -eq 0 ] ; then
      log.stat "  Chrome is running" $green
    else
      log.stat "  Chrome is not running" $red
    fi
    ;;
  *)
    log.error "Invalid command: $command_name"
    log.stat "Available commands: $supported_commands"
    exit 1
    ;;
esac
