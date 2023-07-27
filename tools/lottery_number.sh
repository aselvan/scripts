#!/bin/bash
#
# lottery_number.sh
#   This script generates lottery number using /dev/random assuming the OS 
#   entropy is reasonably high for true random number. In recent Linux kernel 
#   the system entropy at /proc/sys/kernel/random/entropy_avail is hardcoded 
#   to 256. I don't know or understand why but as per documentaion the poolsize 
#   is set to be 256 as well i.e. cat /proc/sys/kernel/random/poolsize
#
# Author:  Arul Selvan
# Created: Jul 27, 2022
#

# version format YY.MM.DD
version=23.07.27
my_name="`basename $0`"
my_version="`basename $0` v$version"

log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options="r:i:m:vh?"
white_range=1-70
mega_range=1-25
iterations=512
total_numbers=5
random_device="/dev/random"

# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
  cat << EOF

  Usage: $my_name [options]
     -r <range>  ---> Range for main numbers i.e. white balls [default: $white_range]
     -m <range>  ---> Range for mega ball [default: $mega_range]
     -i <number> ---> iterate in loop to create new entropy  [default: $iterations]
     -h          ---> print usage/help

  example: $my_name -h
  
EOF
  exit 0
}

iterate_loop() {
  echo "Running iteration of $iterations ..."
  for (( i=0; i<$iterations; i++ )) ; do
    shuf --random-source=$random_device -n$total_numbers -i$white_range 2>&1 >/dev/null
  done
}


# ----------  main --------------
echo $my_version | tee $log_file
# parse commandline options
while getopts $options opt ; do
  case $opt in
    i)
      iterations="$OPTARG"
      ;;
    r)
      white_range="$OPTARG"
      ;;
    m)
      mega_range="$OPTARG"
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

iterate_loop

# get whiteball numbers
white_numbers=`shuf --random-source=$random_device -n$total_numbers -i$white_range|tr  '\n' '  '`

# get megaball numbers
megaball_number=`shuf --random-source=$random_device -n1 -i$mega_range |tr  '\n' '  '`

echo "Your lucky lotto number is: $white_numbers [ $megaball_number]" |tee -a $log_file
