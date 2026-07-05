#!/usr/bin/env bash
################################################################################
# gpg.sh --- Simple gpg wrapper script
#
# Author:  Arul Selvan
# Created: Jul 5, 2026
#
################################################################################
#
# Version History: (original & last 3)
#   Jul 5, 2026 --- Original version
################################################################################

# version format YY.MM.DD
version=26.07.05
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Simple gpg wrapper script"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
login_db_file="/tmp/$(echo $my_name|cut -d. -f1).db"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="l:e:d:r:o:vh?"
fname=""
receipients=()
output_fname=""

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -l <file.gpg>   ---> gpg encrypted file to list packets inside
  -e <file.ext>   ---> encrypt the file.ext [note: should follow -r option]
  -r <receipient> ---> receipient key or email [can use -r multiple times]
  -o <output>     ---> used by -d option and must be specified before -d command
  -d <file.gpg>   ---> decrypt file.gpg
  -v              ---> enable verbose, otherwise just errors are printed
  -h              ---> print usage/help

Examples: 
  $my_name -l file.gpg
  $my_name -r <recepient1> -r <recepient2> -e file
  $my_name -o file.out -d file.enc
EOF
  exit 0
}

list_packets() {
  log.stat "The file $fname is encrypted for:"

  gpg --list-only --list-packets "$fname" 2>&1 | while IFS= read -r line; do
    if [[ $line =~ ID\ ([0-9A-F]+) ]]; then
        key_id="${BASH_REMATCH[1]}"
    elif [[ $line =~ \"(.*)\" ]]; then
        recipient="${BASH_REMATCH[1]}"
        log.stat "  Receipient: $recipient ; Key:$key_id"
        unset key_id recipient
    fi
  done
  exit 0
}

enc_file() {
  # check if receipient is specified
  if [[ -z "${receipients[*]}" ]]; then
    log.error "No recipients specified, see usage below"
    usage
  fi

  # check file
  if [ ! -f $fname ] ; then
    log.error "Filename $fname does not exists!"
    exit 1
  fi

  gpg "${receipients[@]}" -e "$fname"
  exit 0
}

dec_file() {
  # check input
  if [ ! -f $fname ] ; then
    log.error "Filename $fname does not exists!"
    exit 1
  fi

 # check output
  if [ -z "$output_fname" ] ; then
    log.error "No output filename, see usage!"
    usage
  fi

  gpg -o "$output_fname" -d "$fname" 2>/dev/null
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

# ensure we have gpg installed
check_installed gpg

# parse commandline options
while getopts $options opt ; do
  case $opt in
    l)
      fname="$OPTARG"
      list_packets
      ;;
    r)
      receipients+=(-r $OPTARG )
      ;;
    e)
      fname="$OPTARG"
      enc_file
      ;;
    d)
      fname="$OPTARG"
      dec_file
      ;;
    o)
      output_fname="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

usage
