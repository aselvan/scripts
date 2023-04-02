#
# Simple awk to get the pair of host/IP and create a line to include in 
# postfix client_access file
#
# Author: Arul Selvna
# Version: Apr 14, 2012
#

BEGIN {
    rule_num=287;
}
{
  ip = $1;
  host= $2;
  rule_num=rule_num+1;
  print ip, "     554 No SPAM/UBE/opt-in accepted here, get lost -rule=",rule_num," [",host,"] [Rulename: client_access_cidr]"; 
}

END {
#  print "";
}
