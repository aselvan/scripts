#
# awk script to parse and pic google contact CSV file fields to be 
# imported into callcenter phone book which is very stupid simple
# format: <speed_dial#>,<first last>, <phone>,<groupname>
#
# Need to get the following from Google contact CSV
#  $1 firstname
#  $3 lastname
#  $18 primary
#  $19 home
#  $21 cell
#
# sample run: cat <google_contact_export_file> | awk -f google_contact_to+callcentric.awk
#
# Author: Arul Selvan
# Version: Nov 13, 2016
#

BEGIN {
  FS = ",";
}

{
  first = $1;
  last  = $3;
  home  = $19;
  cell  = $21;

  # no name available, then skip
  if ( first == "" && last == "" ) 
    next;
    
  # Note: google export writes line feed for some address fields makeing
  # it two lines screwing with us. Still have to edit the output manually
  # before we import to callcenter.
  # one line for home and cell 
  if (home != "") 
    print "," "\"" first " " last "-Home\""  "," home;
  if (cell != "")
    print "," "\"" first " " last "-Mobile\""  "," cell;
}

END {
#  print "";
}

