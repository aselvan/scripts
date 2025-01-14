#
# Simple awk to format the output of iptables command below
#
#
#  iptables -L ufw-user-input -n -v |grep DROP|sort -k1 -r -n|head -n10
#  header is: pkts bytes target     prot opt in     out     source   destination 
#
# Author:  Arul Selvna
# Version: Jul 5, 2014
#

BEGIN {
   # any static stuff here
   print "#pkts\t#bytes\ttarget\tsource    ";
}
{
  pkts = $1;
  bytes= $2;
  target=$3;
  source=$8;
  source_details="";
  # only print if there are any packets
  if ( pkts > 0 ) {
    "whois "source" |grep descr|head -n1|awk -F: '{print $2;}'" | getline source_details
    if ( source_details == "") {
      "whois "source" |grep organisation| tail -n1|awk -F: '{print $2;}'" | getline source_details    
    }
    # trim leading spaces
    sub(/^[ \t]+/, "", source_details)
    print pkts "\t" bytes "\t" target "\t" source "    \t---> " source_details; 
  }
}

END {
#  print "";
}
