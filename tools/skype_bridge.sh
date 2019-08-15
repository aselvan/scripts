#!/bin/sh
# tiny wrapper to start the sip2sys skype to bridge the
# obihai/google voice phone to skype.
#
# Author:  Arul Selvan
# Version: Jan 11, 2015

# script to start the skype bridge (sip2sis) 
SIP2SIS_HOME=$HOME/sip2sis/
SIP2SIS_BIN=SipToSis_linux
SIP2SIS_LOG="/tmp/${SIP2SIS_BIN}.log"

cd $SIP2SIS_HOME || exit $?
echo "Starting $SIP2SIS_HOME/$SIP2SIS_BIN ..."
echo "Log file: $SIP2SIS_LOG"

nohup ./$SIP2SIS_BIN 2>&1 >$SIP2SIS_LOG </dev/null &
