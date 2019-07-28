#!/bin/sh
#
# nef2jpg.sh -- convert Nicon raw file (NEF) to JPG
#
# usage: nef2jpg <directory_of_NEF_files>
# Author : Arul Selvan
# Version: Dec 2016
#
from=""
to=""

if [ -z "$1" ]; then
  echo "Usage: $0 <directory_of_NEF_files>"
  exit
fi

for fname in *.NEF ; do 
  echo "Converting $fname to ${fname%.NEF}.JPG"
  dcraw -c -q 3 -H 5 -w $fname | cjpeg -optimize -quality 100 > ${fname%.NEF}.JPG 
done
