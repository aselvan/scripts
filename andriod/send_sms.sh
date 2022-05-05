#!/system/bin/sh
#
# send sms
#
# Author:  Arul Selvan
# Version: Mar 31, 2018
#

function usage() {
  echo "Usage: $0 <+1number> <text>"
  exit
}

if [ $# -lt 2 ]; then
  usage
fi

number=$1
text=$2

echo "Sending \"$text\" to $number ..."
am start -a android.intent.action.SENDTO -d sms:$number --es sms_body "$text" --ez exit_on_sent true

# wait for ui to bring up activity
sleep 1

# press key 22 (D-pad right)
input keyevent 22
sleep 1

# NOTE: does not work with android messages which expects 
# position (x,y) and finger touch to send messages not enter key!

# press key 66 (enter key) to send 
input keyevent 66
