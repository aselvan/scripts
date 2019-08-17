#!/bin/sh
#
# max_capacity_change.sh -- crude shell script to change the max capacity of db2 datasource entries
#
# Author:  Arul Selvan
# Version: Apr 18, 2014

# the max capacity to change to
max_capacity=1
backup_ext="odsfix"
# find only the db2 datasource (can be *.xml also).
db2_data_sources=`find . -name \*.xml -exec grep -l "localhost:50000" {} \;`

function change {
  for name in $db2_data_sources ; do
    cp $name ${name}.${backup_ext} || exit
    sed -i "s|\(<max-capacity>\)[^<>]*\(</max-capacity>\)|\1${max_capacity}\2|g" $name
    sed -i "s|\(<initial-capacity>\)[^<>]*\(</initial-capacity>\)|\1${max_capacity}\2|g" $name
    sed -i "s|\(<capacity-increment>\)[^<>]*\(</capacity-increment>\)|\1${max_capacity}\2|g" $name
  done
}

function restore {
  for name in $db2_data_sources ; do
    # to be safe do a move/overwrite *only* if we find a backup file
    if [ -e ${name}.${backup_ext} ]; then
        mv ${name}.${backup_ext} $name
    fi
  done
}

if [ $# -ne 1 ]; then
  echo "Usage: `basename $0` <change|restore>"
  exit
fi

if [ "$1" = "change" ]; then
  change
elif [ "$1" = "restore" ]; then
  restore
fi
