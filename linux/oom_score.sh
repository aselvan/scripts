#!/bin/bash
# oom_score.sh --- prints the oom score,adjustment score of running processes
#
# Author:  Arul Selvan
# Version: Jan 26, 2020
#

printf 'PID\tOOM Score\tOOM Adj\tCommand\n'

while read -r pid comm; do
	[ -f /proc/$pid/oom_score ] && 
	#[ $(cat /proc/$pid/oom_score) != 0 ] && 
	printf '%d\t%d\t\t%d\t%s\n' "$pid" "$(cat /proc/$pid/oom_score)" "$(cat /proc/$pid/oom_score_adj)" "$comm"; 
done < <(ps -e -o pid= -o comm=) | sort -k2nr
