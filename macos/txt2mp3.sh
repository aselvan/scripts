#!/bin/bash
#
# txt2mp3.sh --- wrapper to create mp3 using macOS tools
#
# The script uses 'say' commandline binary comes w/ MacOS to convert text to AIFF and
# uses 'lame' to convert AIFF to MP3
#
# PreReq: lame (install w/ 'brew install lame')
#
# Author:  Arul Selvan
# Created: Dec 30, 2022
#

# version format YY.MM.DD
version=22.12.30
my_name="`basename $0`"
my_version="`basename $0` v$version"
cmdline_args=`printf "%s " $@`
lame_bin="/usr/local/bin/lame"
my_pid=$$

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="h?s:o:"
message=""
out_file="/tmp/txt2mp3.mp3"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  echo ""
  echo "Usage: $my_name [options]"
  echo "  -s <message>     ---> message in quotes to be converted to mp3"
  echo "  -o <output_file> ---> output file name for mp3 [default: $out_file]" 
  echo "  -h               ---> print usage/help"
  echo ""
  echo "example: $my_name -s \"Hello [[slnc 75]], my name is Bob\""
  echo "         the above example inserts 75 msec pause after saying 'Hello'"
  echo ""
  exit 0
}

write_log() {
  local msg_type=$1
  local msg=$2

  echo "$msg_type $msg" | tee -a $log_file
}

init_log() {
  if [ -f $log_file ] ; then
    rm -f $log_file
  fi
  write_log "[STAT]" "$my_version: starting at `date +'%m/%d/%y %r'` ..."
}

# ----------  main --------------
init_log
if [ ! -x $lame_bin ] ; then
  write_log "[ERROR]" "required utility $lame_bin is missing, install w/ 'brew install lame'"
  usage
fi
# parse commandline options
while getopts $options opt; do
  case $opt in
    s)
      message="$OPTARG"
      ;;
    o)
      out_file="$OPTARG"
      ;;
    ?)
      usage
      ;;
    *)
      usage
      ;;
  esac
done

# check for message
if [ -z "$message" ] ; then
  write_log "[ERROR]" "need text to convert to mp3!"
  usage
fi

write_log "[INFO]" "converting text to mp3 ..."
temp_file=$(mktemp /tmp/${my_name}.${my_pid})

echo "$message" | say -vDaniel -o $temp_file
if [ $? -ne 0 ] ; then
  write_log "[ERROR]" "converting to AIFF failed!"
  exit 1
fi

$lame_bin $temp_file $out_file
if [ $? -ne 0 ] ; then
  write_log "[ERROR]" "converting to MP3 failed!"
  exit 2
fi

rm $temp_file
write_log "[INFO]" "successfully converted message to mp3. The output file is at: $out_file"

