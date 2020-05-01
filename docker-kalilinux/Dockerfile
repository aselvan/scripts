#
# Dockerfile -- simple minimalistic container of kalilinux
#
# Author:  Arul Selvan
# Version: Apr 4, 2020
#

FROM kalilinux/kali-rolling

MAINTAINER Arul Selvan <aselvan@selvans.net>

RUN apt-get -y update && apt-get -y install \
  metasploit-framework responder netcat aircrack-ng && \
  apt-get autoremove -y && \
  apt-get clean

CMD "/bin/bash"
