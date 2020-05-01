#!/bin/sh
#
# run.sh --- simple wrapper to build and run tools out of kalilinux
#
# Author:  Arul Selvan
# Version: Apr 4, 2020
#


usage() {
  echo "Usage: $0 <build|responder|msfconsole|run>"
  exit
}

check() {
  # check if docker is running
  docker version >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    echo "[ERROR] docker engine is not running!"
    exit
  fi
  docker images 2>&1 |grep kali >/dev/null 2>&1
  if [ $? -ne 0 ] ; then
    echo "[ERROR] no kali image in local repository, run build first"
    usage
  fi
}

build() {
  echo "[INFO] building kali image..."
  docker build --rm -t kali .
}

responder() {
  check
  echo "[INFO] running responder..."
  docker run -it --rm --net=host kali responder -I eth0 -v
}

msfconsole() {
  check
  echo "[INFO] running msfconsole ..."
  docker run -it --rm --net=host kali msfconsole
}

# just run a shell on Kali
run() {
  check
  echo "[INFO] running a shell in Kali Linux ..."
  docker run -it --rm --net=host kali /bin/bash
}

case $1 in
  build|responder|msfconsole|run) "$@"
  ;;
  *) 
  usage
  ;;
esac

