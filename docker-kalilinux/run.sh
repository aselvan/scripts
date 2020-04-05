#!/bin/sh
#
# run.sh --- simple wrapper to build and run tools out of kalilinux
#
# Author:  Arul Selvan
# Version: Apr 4, 2020
#


build() {
  echo "[INFO] building kali image..."
  docker build --rm -t kali .
}

responder() {
  echo "[INFO] running responder..."
  docker run -it --rm --net=host kali responder -I eth0 -v
}

msfconsole() {
  echo "[INFO] running msfconsole ..."
  docker run -it --rm --net=host kali msfconsole
}

case $1 in
  build|responder|msfconsole) "$@"
  ;;
  *) echo "Usage: $0 <build|responder|msfconsole>"
  ;;
esac

