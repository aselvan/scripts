#!/bin/sh

# graphic_perf.sh -- runs glx tools
#
# Author : Arul Selvan
# Version: Dec 2013
export vblank_mode=0
program_name=

usage() {
	echo "Usage: $0 [--gears|--mark]" 
	exit
}

# parse commandline args
while [ "$1" ] 
do
        if [ "$1" = "--gears" ]; then
		program_name=/usr/bin/glxgears
		break
        elif [ "$1" = "--mark" ]; then
		program_name=/usr/bin/glmark2
		break
        else
                usage
        fi
done

if [ "$program_name" = "" ]; then
	usage
fi

exec $program_name
