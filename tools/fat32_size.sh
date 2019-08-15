#!/bin/sh

#
#  fat32_size.sh --- script to split (and combine later) files for fat32 fs.
#
#  Author:  Arul Selvan
#  Version: Sep 21, 2014

# 4gb (note ths '*' need to be escaped!)
four_gb=`expr 4 \* 1024 \* 1024 \* 1024`
split_args="--bytes=1GB --numeric-suffixes=1"
md5sum_command="md5sum -b"

usage() {
  echo "Usage: $0 --split <filename>|--combine <original_filename>"
  exit
}

split_file() {
  fname=$1
  if [ -z $fname ]; then
    usage
  fi

  # calculate file size to see if we need to split
  #fsize=`ls -l $fname |cut -d' ' -f5`
  fsize=`ls -l $fname |awk '{print $5;}'`
  if [ $fsize -gt $four_gb ]; then
     echo "File: $fname is too big for fat32, needs spliting..."
  else
     echo "INFO: File $fname already is under 4GB, no need to split for fat32"
     exit
  fi

  # calculate md5sum
  echo "Calculating md5sum for $fname... (may take long time)"
  $md5sum_command $fname > $fname.md5

  # 
  # split using zip with 1GB chunks each
  echo "Spliting $fname into 1GB chunks ... (may take long time)"
  split $split_args $fname $fname.part
  echo "Done spliting."
  exit
}

combine_file() {
  fname=$1
  if [ -z $fname ]; then
    usage
  fi

  # we expect $fname.part01...0n
  echo "Combining the files split earlier to full size...(may take long time)..."
  cat $fname.part* > $fname
  
  # check the md5sum (we expect the $fname.md5 created earlier)
  echo "Verifying file integrity after combining... (may take a long time) ..."
  if [ $os = "Darwin" ]; then
    $md5sum_command $fname >$fname.md5.combined
    diff $fname.md5 $fname.md5.combined >/dev/null 2>&1
  else
    md5sum -c $fname.md5
  fi
  if [ $? -ne 0 ]; then
    echo "ERROR: md5sum does not match after combining, file parts may be corrupted!"
  else
    echo "Successfully combined $fname using $fname.part<NN>"
  fi
  exit
}

# -------- main -----------
# check the os, MacOS does not have md5sum and split works in different way
os=`uname -s`
if [ $os = "Darwin" ]; then
  split_args="-a3 -b1024m"
  md5sum_command="md5 -q"
fi

# parse commandline
while [ "$1" ] 
do
  if [ "$1" = "--split" ]; then
    shift 1
    split_file $1
    break
  elif [ "$1" = "--combine" ]; then
    shift 1
    combine_file $1
    break
  else
    usage
  fi
done

# we get here if there are no args
usage
