#!/bin/bash
#
# liapp_gdrive_import.sh 
# 
# Script to download the liapp data from gdrive, import to our libre-db, move the loaded
# files to gdrive/liapp/backup. Can be run on cron
#
# Prereq: rclone (https://rclone.org/drive) must be installed & configured with liapp: in rclone.conf
#  brew install rclone (last version 1.41)
#  define liapp: in ~/config/rclone.conf as shown below
# [liapp]
# type = drive
# client_id =
# client_secret =
# scope = drive
# root_folder_id = <folderIDGoeshere>
# service_account_file =
# token = <your security token to access gdrive>
# 
#
# Author: Arul Selvan
# Version:  Apr 5, 2018
#

tmp_dir="/Users/arulselvan/tmp"
local_dir="${tmp_dir}/liapp"
log_file="${tmp_dir}/logs/liapp_import.log"
internet_test_log="${tmp_dir}/logs/internet_test.log"

google_dns_host=8.8.8.8
libre_app="./libre_app.pl"
rclone="/usr/local/bin/rclone"
libre_export_filename="libre_data_export.csv"

# script must be in the libre-data (libre home direcory)
scriptPath=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

# go to libre-data directory
cd $scriptPath || exit

echo "Import liapp job starting..." > $log_file
echo "Date: `date`">> $log_file

# check and make sure our apps are available.
if [ ! -e $libre_app ]; then
  echo "$libre_app program not found!" >> $log_file
  exit
fi
if [ ! -e $rclone ]; then
  echo "$rclone program not found!" >> $log_file
fi

# we need internet connectivity for accessing gdrive ofcourse
# so check if we got internet
echo "Checking for internet...">> $log_file
/sbin/ping -t30 -c1 -qo $google_dns_host >$internet_test_log 2>&1
if [ $? -ne 0 ]; then
   echo "No internet access... exiting." >> $log_file
   exit
fi

# delete the png files liapp creates in gdrive, we don't need it.
$rclone delete --include /*.png liapp: >> $log_file 2>&1

# dedup filenames first
$rclone dedupe --dedupe-mode rename liapp: >>$log_file 2>&1

# copy all files to $local_dir
mkdir -p $local_dir >>$log_file 2>&1
rm -f $local_dir/*.csv >>$log_file 2>&1
$rclone copy --include /*.csv liapp: $local_dir >>$log_file 2>&1

# check if we got any files from gdrive copy above.
ls -1 $local_dir/*.csv >/dev/null 2>&1
rc=$?
if [ "$rc" !=  "0" ] ; then 
  echo "No files found in gDrive, returncode=$rc ... exiting." >>$log_file 2>&1
  exit
fi

# first backup DB 
cp libre-db.sqlite libre-db.sqlite.backup >>$log_file 2>&1

# also export to our format
$libre_app --export $libre_export_filename >>$log_file 2>&1

# now import all liapp from gdrive
csv_files=`ls -1 $local_dir/*.csv`
for csv in $csv_files ; do
  echo "Importing $csv ..." >>$log_file 2>&1
  $libre_app --type liapp --import $csv >>$log_file 2>&1
done

# move files to backup directory in gdrive
$rclone copy --include /*.csv $local_dir liapp:/backup >>$log_file 2>&1
$rclone delete --include /*.csv liapp: >>$log_file 2>&1

# backup the sqlite db to gdrive
$rclone copy --include /*.sqlite . liapp:

# remove tmp data as well
rm -f $local_dir/*.csv >>$log_file 2>&1
echo "$0 completed successfully." >>$log_file 2>&1
