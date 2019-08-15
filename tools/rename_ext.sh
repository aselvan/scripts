#!/bin/sh
#
# rename_ext.sh -- renames files from one extention to other
#
# usage: rename_ext.sh --from <ext> --to <ext>
# Author : Arul Selvan
# Version: Jun 15, 2014
#
from=""
to=""

while [ $1 ]; do
        if [ "$1" = "--from" ]; then
                shift 1
                from=$1
        elif [ "$1" = "--to" ]; then
                shift 1
                to=$1
        fi
        shift 1
done

if [ "$from" = "" -o "$to" = "" ] ; then
   echo "Usage: $0 --from <ext> --to <ext>"
   echo "example: $0 --from JPG --to jpg"
   exit
fi

echo "Renaming *.$from to *.$to ..."
for i in *.$from ; do 
    mv "$i" "${i%.$from}".$to; 
done
