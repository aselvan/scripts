#!/usr/bin/env bash
################################################################################
# qrcode2txt.sh --- convert all qrcode files to TXT
#
# Purpose: 
#   quick handy script to read all qrcodes files in current directory and 
#   write all secrets to text file.
#
# Required: "brew install zbarimg" or  "apt-get install zbarimg"
#
# OS: Linux (or) MacOS
# Author:  Arul Selvan
# Created: Jan 31, 2025
#
# See Also:
#   wifi_qrcode2txt.sh
#   qrcode.sh
#   ScanQRCode.php
#
################################################################################
# Version History:
#   Jan 31, 2025 --- Original version
#   Mar 17, 2025 --- Added dir argument to look for qr-code files
################################################################################

# version format YY.MM.DD
version=25.03.17
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Convert QR-Code to Text"
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
my_name_noext="$(echo $my_name|cut -d. -f1)"

default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="e:o:d:vh?"

output_file="/tmp/$(echo $my_name|cut -d. -f1).txt"
file_ext="png"
dir_path="."

usage() {
  cat << EOF
$my_name --- $my_title

Usage: $my_name [options]
  -d <path>   ---> Directory path to look for qr-code files [Default: "$dir_path"]
  -e <ext>    ---> File extention for all qrcode files [Default: *.$file_ext]
  -o <file>   ---> Output text file to save qrcode secrets [Default: $output_file}
  -v          ---> enable verbose, otherwise just errors are printed.
  -h          ---> print usage/help.

example: 
  $my_name
  $my_name -o allcodes.txt -d /tmp -e png

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
    d)
      dir_path="$OPTARG"
      ;;
    e)
      file_ext="$OPTARG"
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
check_installed zbarimg

log.stat "Creating text file with all QR-code files in: $dir_path/*.$file_ext"

rm -rf $output_file
found=0
find $dir_path -name "*.${file_ext}" -type f | while read -r file; do
  echo "File: $file" >> $output_file
  zbarimg -q $file >> $output_file
  echo "" >> $output_file
  found=1
done

if [ $found -eq 0 ] ; then
  log.error "There are no *.$file_ext files found under dir $dir_path"
else
  log.stat "qr-code output file: $output_file"
fi
