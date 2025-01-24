#!/usr/bin/env bash
################################################################################
# qrcode.sh --- Read or Create QR-Code
#
# Purpose: 
#   Can be used to read the QR-Code content secret, or URL or other data. Also
#   can create QR code with given content in the from of text strings
#
# Required: qrencode. You can install with "brew install qrencode zbarimg" or 
#           "apt-get install qrencode zbarimg"
#
# OS: Linux (or) MacOS
# Author:  Arul Selvan
# Created: Jul 16, 2024
#
# See Also:
#   wifi_qrcode.sh
#   ScanQRCode.php
#
################################################################################
# Version History:
#   Jan 24, 2025 --- Original version
################################################################################

# version format YY.MM.DD
version=25.01.24
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Read or Create QR-Code."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
my_name_noext="$(echo $my_name|cut -d. -f1)"

default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="q:o:t:vh?"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

qrcode_text=""
qrcode_file=""
output_file="qrcode.png"

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -q <file>   ---> QRcode file to read and convert to text.
  -t <text>   ---> Text in quotes to convert to QR-code.
  -o <file>   ---> Create QR-Code file from text string [Default: $output_file}
  -v          ---> enable verbose, otherwise just errors are printed.
  -h          ---> print usage/help.

example: 
  $my_name -f myqrcode_file.png
  $my_name -t "https://www.selvansoft.com" -o qrcode_selvansoft.png 

EOF
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

# parse commandline options
while getopts $options opt ; do
  case $opt in
    q)
      qrcode_file="$OPTARG"
      ;;
    t)
      qrcode_text="$OPTARG"
      ;;
    o)
      output_file="$OPTARG"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# check for required tool
check_installed qrencode
check_installed zbarimg

if [ ! -z "$qrcode_file" ] && [ -f $qrcode_file ] ; then
  # convert qr-code file to txt
  log.stat "Reading QR-code file $qrcode_file ..."
  log.stat "`zbarimg -q $qrcode_file`" $green
elif [ ! -z "$qrcode_text" ] ; then
  # convert text to qr-code file
  log.stat "Creating QR-code file using text \"$qrcode_text\" ..."
  qrencode -o $output_file "$qrcode_text"
  log.stat "Created QR-Code file: $output_file" $green
else
  log.error "No options specified, see usage below"
  usage
fi
