#!/system/bin/sh
#
# sound_settings.sh 
#
# Setup desired sound volume on different andriod sound devices 
#
# Author:  Arul Selvan
# Version: Jan 6, 2018
#

# can't change any volume settings if DnD is on
dnd_status=`settings get global zen_mode`

if [ $dnd_status -ne 0 ] ; then
  echo "Do Not Distrub is on: $dnd_status"
  echo "Can not adjust volume... exiting."
  exit
fi

# media volume 0-15 (set to 14)
service call audio 3 i32 3 i32 14 i32 1

# phone volume 0-7 (set to 3)
service call audio 3 i32 2 i32 3 i32 1 

# bluetooth volume (0-15)
service call audio 3 i32 6 i32 15 i32 1 

# alarm volume 0-7 (set to 3)
service call audio 3 i32 4 i32 3 i32 1
