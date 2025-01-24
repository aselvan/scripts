#!/usr/bin/env bash
################################################################################
# wifi_qrcode.sh --- Create a QR Code to scan to connect to a Wi-Fi network
#
# Purpose: 
#   We've all probably had friends or relatives visit our home and ask for the 
#   Wi-Fi password. If you're security-minded like me, you've likely set up a 
#   an isolated VLAN or at least a "Guest" network with a complex/long password. 
#   The problem is, sharing a long, complex password with symbols and numbers 
#   can be frustrating to enter manually.
#
#   So what this tool does is creates a QR-Code that they can scan and join
#   your Wi-Fi network without having to type anything. This way you can create 
#   a super long/complex password like below.
#
#   1c#aiw8tu4ni0bu3Goo0phah%h.ooz@A <<< Not a real password ofcourse :)
#   
#   If you have a Mac or Linux, just install qrencode binary as mentioned
#   at the required section below and the script will run out of the box. 
#   To see how it works, you can try scanning the sample QR-Code file in 
#   this directory called "wifi_qrcode.png" to see how it works.
#
# Data format:
# The following is the format for the QRcode string to convert to image
# 
#  "WIFI:S:<SSID>;T:<WEP|WPA|>;P:<password>;H:<true|false|>;"
#
#   where
#     WIFI:S:<SSID>        ---> the SSID of the WiFi access point
#     T:<WEP|WPA|nopass>   ---> encryption type
#     P:<password>         ---> Wi-Fi password
#     H:<true|false|blank> ---> true for hidden & false for visible SSID
#
#   example: WIFI:S:MyHomeNetwork;T:WPA;P:SuperSecure123;H:false;
#
# Required: qrencode. You can install with "brew install qrencode" or 
#           "apt-get install qrencode"
#
# OS: Linux (or) MacOS
# Author:  Arul Selvan
# Created: Jul 16, 2024
#
# See Also:
#   ScanQRCode.php
#
################################################################################
# Version History:
#   Jul 16, 2024 --- Original version
#

# version format YY.MM.DD
version=24.07.16
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="Create a QR Code to scan to connect to a Wi-Fi network."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
my_name_noext="$(echo $my_name|cut -d. -f1)"

default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="s:p:o:t:Hvh?"

# ensure path for cron runs (prioritize usr/local first)
export PATH="/usr/local/bin:/usr/bin:/usr/sbin:/bin:/sbin:$PATH"

ssid=""
password=""
enc_type="WPA"
hidden="false"
output_file="wifi_qrcode.png"

usage() {
  cat << EOF
  
$my_name --- $my_title

Usage: $my_name [options]
  -s <SSID>   ---> Your Wi-Fi accesspoint's SSID
  -p <passwd> ---> The password to join your access point
  -o <file>   ---> Output QR-Code file to generate [Default: $output_file}
  -t <type>   ---> Type of encryption (i.e. WPA or WEP) [Default: $enc_type]
  -H          ---> Indicates your accesspoint is hidden [Default: assumed to be visible]
  -v          ---> enable verbose, otherwise just errors are printed
  -h          ---> print usage/help

example: $my_name -s "MyWifiSSID" -p "password" -o $output_file
  
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
    s)
      ssid="$OPTARG"
      ;;
    p)
      password="$OPTARG"
      ;;
    o)
      output_file="$OPTARG"
      ;;
    t)
      enc_type="$OPTARG"
      ;;
    H)
      hidden="true"
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

# check required args
if [[ -z "$ssid" || -z $password || -z $output_file ]] ; then
  log.error "  Missing arguments! See usage below."
  usage
fi

# construct the QR-code string
#  "WIFI:S:<SSID>;T:<WEP|WPA|>;P:<password>;H:<true|false|>;;"
qrcode_string="WIFI:S:$ssid;T:$enc_type;P:$password;H:$hidden;"
log.debug "qrcode_string='$qrcode_string'"

qrencode -o $output_file "$qrcode_string"
log.stat "Created QR-Code file is here: $output_file"
