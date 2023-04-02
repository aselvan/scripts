# sample to show sprintf and sub function usage and color
# sample run: echo "first second third" |awk -f awk_sample.awk
BEGIN{}
{
  red_color_on="\033[1;31m";
  red_color_off="\033[0m";
  name=$1;
  company=$2;
  score=trim($3);
  print "Plain: ",$1,$2,$3;
  print "Color: ",$1,$2, red_color_on $3 red_color_off;
  var = sprintf("%s  => array(0 => %s, \"%s\"),",name,score,company);
  print var;
}

function trim(s) {
  sub(/\r/,"",s);
  return s;
}
