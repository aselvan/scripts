#!/bin/bash
#
# libre_view_import.sh --- handy script to import the librewview downloaded data
# 
# Author:  Arul Selvan
# Version: May 17, 2020
#

log_dir="${HOME}/tmp/logs"
log_file="${log_dir}/libre_view_import.log"
libre_app="./libre_app.pl"
libre_export_file="libre_data_export.csv"
libre_import_file="libreview_data.txt"

# script must be in the libre-data (libre home direcory)
scriptPath=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# go to libre-data directory
cd $scriptPath || exit

# make sure log dir exists
mkdir -p $log_dir || exit

download_file=$1

if [ -z $download_file ]; then
	echo "Usage: $0 <libre_view_downloaded_file>"
	exit 1
fi

# make sure the file exists
if [ ! -f $download_file ]; then
	echo "Error: $download_file does not exist!"
	echo "Usage: $0 <libre_view_downloaded_file>"
	exit 2
fi

# check and make sure our apps are available.
if [ ! -e $libre_app ]; then
  echo "$libre_app program not found!" 
  exit
fi

echo "Import libreview downloaded data from the file: $1 ..." > $log_file
echo "Date: `date`">> $log_file

# first backup DB 
cp libre-db.sqlite libre-db.sqlite.backup >>$log_file 2>&1

$libre_app --import $download_file >>$log_file 2>&1
if [ $? -ne 0 ] ; then
	echo "ERROR: importing, bailing out."
	exit 3
fi

# also export to our format
cp $libre_export_file $libre_export_file.backup
echo "Exporting to: $libre_export_file" >> $log_file
$libre_app --export $libre_export_file >>$log_file 2>&1

# make a backup of the $import_file and replace it w/ downloaded file
cp $libre_import_file $libre_import_file.backup
mv $download_file $libre_import_file

echo "$0 completed successfully." >>$log_file 2>&1
