#!/bin/bash
#
# dedup.sh --- identifiy and separate files w/ same content but different name
#
#
# Author:  Arul Selvan
# Version: Feb 6, 2021
#

export PATH="/usr/bin:/sbin:/usr/local/bin:$PATH"
os_name=`uname -s`
my_name=`basename $0`
run_date=`date +'%F-%H%M'`
log_file="/tmp/$(echo $my_name|cut -d. -f1).log"
options_list="f:s:d:h"

source_dir=""
dest_dir=""
file_filter="*"
mdsum_file=/tmp/${my_name}_mdsums.txt

usage() {
  echo "Usage: $my_name [options]"
  echo "  -s <path>   --- source path where duplicate files are found"
  echo "  -d <path>   --- destination path to move unique files from source"
  echo "  -f <filter> --- filter ex: \"*.jpg *.pdf\"  [default: *]"
  exit 0
}

# process commandline
while getopts "$options_list" opt; do
  case $opt in
    s)
      source_dir=$OPTARG
      ;;
    d)
      dest_dir=$OPTARG
      ;;
    f)
      file_filter="$OPTARG"
      ;;
    h)
      usage
      ;;
    \?)
     usage
     ;;
    :)
     usage
     ;;
   esac
done

# no source or dest?
if [[ -z $source_dir || -z $dest_dir ]] ; then
  echo "[ERROR] missing source or dest args!"
  usage
fi

echo "[INFO] starting '$my_name $@'"  | tee $log_file
file_list=`(cd $source_dir; ls -1 $file_filter)`
total=`echo $file_list|wc -w|tr -d ' '`

rm -f $mdsum_file
count=1
for fname in $file_list ; do
  printf "[INFO] creating md5sum file $count/$total ...\r" 
  (cd $source_dir; md5sum $fname >> $mdsum_file)
  ((count++))
done
echo
unique_file_list=`cat $mdsum_file|sort -u -k1,1|awk '{print $2}'`

for fname in $unique_file_list ; do
  printf "[INFO] copying ${source_dir}/${fname} to ${dest_dir} ...\r" 
  echo   "[INFO] copying ${source_dir}/${fname} to ${dest_dir} " >> $log_file
  cp ${source_dir}/${fname} ${dest_dir}/.
done
echo
