#!/bin/sh
#
# Registry cleaner script. This is needed to purge and GC the registry that gets growing
# in an uncontrollable way as CICD pipline builds happen every night for various products.
# This script goes through each application namespace and collects all the image hashes 
# except the last recent X (controlled by image_count variable) and request API call to 
# delete the image.
#
# Note: this is run on cron every night to do daily cleanup
#
# Author:  Arul Selvan
# Version: Mar 21, 2018
#

registry_url="https://your.registry.com/v2"

# leave just the last 12 images.
image_count=12
log_file=/tmp/docker_registry_cleaner.log
rep_path=/data/docker_registry/docker/registry/v2/repositories

echo "Registry cleaner start: `date`" > $log_file
echo "$0 starting ..." >> $log_file

# application list
APP_LIST="vmp/fpm vmp/api ops/obc m1/app m1-reporting m1/m1-app-cron"

for app_path in $APP_LIST ; do
  echo "Deleting namespace: $app_path" >> $log_file
  
  # check and make sure the dir exists
  if [ ! -d $rep_path/$app_path/_manifests/revisions/sha256/ ]; then
    echo "    Nothing to delete for: $app_path" >> $log_file
    continue
  fi
  
  sha=$(ls -rt $rep_path/$app_path/_manifests/revisions/sha256/|head -n -$image_count)

  for hash in $sha; do 
    echo "    Deleting $hash ..." >> $log_file
    curl -s -X DELETE $registry_url/$app_path/manifests/sha256:$hash >> $log_file 2>&1
  done
done

# initiate registry GC process 
echo "" >> $log_file
echo "Initiating registry GC process ... " >> $log_file
docker exec registry /bin/registry garbage-collect /etc/docker/registry/config.yml >> $log_file 2>&1

# need to restart registry (note: restart doesn't seem to work right, so stop and let systemd restart)
docker stop registry
sleep 15
systemctl start registry
