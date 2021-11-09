#!/bin/bash
#
# node_version_check.sh --- quick and dirty script to check selected node module versions
#
# Author:  Arul Selvan
# version: Nov 9, 2021
#

my_name=`basename $0`
run_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
options_list="p:s:h"

# the location of node modules
node_modules_path="`npm list -g|head -n1`/node_modules"
node_package_list="rc coa ua-parser-js"

echo "[INFO] checking node packages versions..." |tee $run_logfile

for p in $node_package_list ; do
  p=`echo $p|tr -d ' '`
  if [ ! -d ${node_modules_path}/${p} ]; then
    echo -e "\tPackage:$p, version: not present" | tee -a $run_logfile
  else
    v=`cat ${node_modules_path}/${p}/package.json |awk '/version/ {print $2;}'|head -n1`
    echo -e "\tPackage:$p, version:$v" | tee -a $run_logfile
  fi
done
echo "[INFO] done" | tee -a $run_logfile
