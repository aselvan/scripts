#!/bin/bash
# 
# simple script to count RSS size of specificed process or all processes
#
# Author:  Arul Selvan
# Version: Nov 12, 2012

filter=$1

if [ ! -z "$filter" ]; then
  echo "Counting RSS size of process: $filter"
  rss_kbytes=`ps -augx --no-header | grep $filter | grep -v grep | awk '{print $6;}' |paste -sd+|bc`
else
  echo "Counting RSS size of all processes"
  rss_kbytes=`ps -augx --no-header | grep -v grep | awk '{print $6;}' |paste -sd+|bc`
fi

echo "Size: $rss_kbytes KB or $(echo "scale=2; $rss_kbytes/1024"  | bc -l) MB or $(echo "scale=2; $rss_kbytes/(1024*1024)"  | bc -l) GB"
