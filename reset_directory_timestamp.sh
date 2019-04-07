#!/bin/sh
  
# reset_directory_timestamp.sh --- change directory timestamp based on a file in that directory
#
# Author : Arul Selvan
# Version: Apr 7. 2019


directory_path="/var/www/photos"
filename="index.html"
alternate_filename="jdothumb.html"

if [ ! -z $1 ] ; then
  directory_path=$1
fi

if [ ! -z $2 ] ; then
  filename=$2
fi

dir_list=`ls -1d ${directory_path}/*/`

for dir in ${dir_list} ;  do
  if [ -f $dir/$filename ] ; then
    ts=`stat --printf="%y" ${dir}/$filename |awk -F'[- :]' '{print $1 $2 $3 $4 $5 ".01"}'`
  elif [ -f $dir/$alternate_filename ] ; then
    ts=`stat --printf="%y" ${dir}/$alternate_filename |awk -F'[- :]' '{print $1 $2 $3 $4 $5 ".01"}'`
  else
    echo "Dir: $dir does not contain ${filename}!, skipping ..."
    continue
  fi
  echo "executing touch -t $ts $dir"
  touch -t $ts $dir
done
