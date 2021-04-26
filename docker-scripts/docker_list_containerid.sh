#!/bin/bash

# docker_list_containerid.sh 
#    List all the container IDs (local and remote) for the swarm stack
#
# Author:  Arul Selvan
# Version: May 17, 2019
#

if [ -z $1 ] ; then
  echo "Usage: $0 <swarm_service_name>"
  exit
fi
service_name=$1

echo "[INFO] List of all containers across all hosts for the service '$service_name'"
docker stack ps $service_name --format "{{.Node}} {{.ID}}" -f "desired-state=running"| while read entry ; do
  host=$(echo $entry | cut -f 1 -d " ")
  #if [ $host = $myhost ] ; then
  #  continue
  #fi
  task=$(echo $entry | cut -f 2 -d " ")
  container=$(docker inspect --format '{{.Status.ContainerStatus.ContainerID}}' $task| head -c 12)
  echo "[INFO] remote container@host: ${container}@${host}"
done

