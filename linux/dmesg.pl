#!/usr/bin/perl

# Print human readable dmesg.
#
# Author:  Arul Selvan
# Version: Mar 17, 2012

use strict;
use warnings;
 
my @dmesg_new = ();
my $dmesg = "/bin/dmesg";
my @dmesg_old = `$dmesg`;
my $now = time();
my $uptime = `cat /proc/uptime | cut -d"." -f1`;
my $t_now = $now - $uptime;
 
sub format_time {
 my @time = localtime $_[0];
 $time[4]+=1;    # Adjust Month
 $time[5]+=1900;    # Adjust Year
 return sprintf '%4i-%02i-%02i %02i:%02i:%02i', @time[reverse 0..5];
}
 
foreach my $line ( @dmesg_old )
{
 chomp( $line );
 if( $line =~ m/\[\s*(\d+)\.(\d+)\](.*)/i )
 {
 # now - uptime + sekunden
 my $t_time = format_time( $t_now + $1 );
 push( @dmesg_new , "[$t_time] $3" );
 }
}
 
print join( "\n", @dmesg_new );
print "\n";
