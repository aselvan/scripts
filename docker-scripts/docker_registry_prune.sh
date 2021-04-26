#!/bin/sh
#
# prune docker registry with docker-distribution-pruner
# pre_req: go get -u gitlab.com/gitlab-org/docker-distribution-pruner
#
# Note: this is run on cron once a week
#
# Author:  Arul Selvan
# Version: Oct 15, 2018
#

log_file=/tmp/docker_registry_prune.log
rep_path=/data/docker_registry
prune_tool=/opt/go/bin/docker-distribution-pruner
prune_tool_options="-delete -soft-delete=false"
docker_registry_config="/root/bin/docker_registry_config.yml"

echo "Registry prune start: `date`" > $log_file
echo "$0 starting ..." >> $log_file

# run the prune tool
if [ -x "$prune_tool" ] ; then
  $prune_tool -config=$docker_registry_config $prune_tool_options >> $log_file 2>&1
else
  echo "$prune_tool is missing, exit" >> $log_file
  exit
fi

# initiate registry GC process (NOTE: not sure this is needed)
echo "" >> $log_file
echo "Initiating registry GC process ... " >> $log_file
docker exec registry /bin/registry garbage-collect /etc/docker/registry/config.yml >> $log_file 2>&1

# need to restart registry (NOTE: not sure this is needed)
docker stop registry
sleep 15
systemctl start registry

