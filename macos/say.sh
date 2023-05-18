#!/bin/bash
#
# say.sh --- simple wrapper over say
#
#
# Author:  Arul Selvan
# Created: May 18, 2023
#

# version format YY.MM.DD
version=23.05.18
my_name="`basename $0`"
my_version="`basename $0` v$version"
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="t:v:h?"

text="Hello there"
volume=5
cur_vol=0

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -t <text>    ---> text to say on macOS system speaker [Default: $text]
     -v <number>  ---> volume to adjust before speaking between 1-100 [Default: $volume]
     -h           ---> print usage/help

  example: $my_name -v$volume -t "$text"
  
EOF
  exit 0
}

# ----------  main --------------
echo "$my_version" | tee $log_file

# parse commandline options
while getopts $options opt ; do
  case $opt in
    v)
      volume=$OPTARG
      ;;
    t)
      text="$OPTARG"
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

# save current volume to restore, & set new volume
cur_vol=$(osascript -e 'output volume of (get volume settings)')
osascript -e "set volume output volume $volume" 2>&1 | tee -a $log_file

# emit the text to speaker
echo "$text" | say  2>&1 | tee -a $log_file

# restore original volume
osascript -e "set volume output volume $cur_vol"  2>&1 | tee -a $log_file

