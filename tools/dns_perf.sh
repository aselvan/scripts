#!/usr/bin/env bash
#
# dns_perf.sh --- DNS lookup of large, random hosts to measure DNS resolve time.
#
#
# Author : Arul Selvan
# Version: Oct 7, 2022

# version format YY.MM.DD
version=23.11.28
my_name="`basename $0`"
my_version="`basename $0` v$version"
my_title="DNS lookup of large, random hosts to measure DNS resolve time."
my_dirname=`dirname $0`
my_path=$(cd $my_dirname; pwd -P)
my_logfile="/tmp/$(echo $my_name|cut -d. -f1).log"
default_scripts_github=$HOME/src/scripts.github
scripts_github=${SCRIPTS_GITHUB:-$default_scripts_github}

# commandline options
options="s:f:u:d:vh?"

default_host_list="/tmp/$(echo $my_name|cut -d. -f1).txt"
host_list=""
dns_server=""
single_host=""
#url_host_list="https://raw.githubusercontent.com/aselvan/public-domain-lists/master/opendns-top-domains.txt"
url_host_list=""


# ensure path for cron runs
export PATH="/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:$PATH"

usage() {
cat << EOF
$my_name - $my_title

Usage: $my_name [options]
  -s <host>  ---> single host to use for test
  -f <list>  ---> file contains list of hosts for testing
  -u <url>   ---> url returns a list of hosts for testing [note: url should return a file w/ one FQDN per line]
  -d <dns>   ---> DNS server to use instead of default 
  -v         ---> enable verbose, otherwise just errors are printed
  -h         ---> print usage/help

  example: $my_name -l myhostlist.txt
  example: $my_name -u https://raw.githubusercontent.com/aselvan/public-domain-lists/master/opendns-top-domains.txt 
  example: $my_name -t yahoo.com
  
EOF
  exit 0
}

create_default_host_list() {
  cat << EOF > $default_host_list
1-courier.push.apple.com
1-courier.sandbox.push.apple.com
1.courier-push-apple.com.akadns.net
13-courier.push.apple.com
34z57co1uh.execute-api.us-east-1.amazonaws.com
4b64d6fa612f.us-east-1.playback.live-video.net
6-courier.push.apple.com
a1051.b.akamai.net
a1091.dscb.akamai.net
a1779.dscd.akamai.net
a1806.dscb.akamai.net
a1864.gi3.akamai.net
a1887.dscq.akamai.net
a1952.dspw65.akamai.net
a239.gi3.akamai.net
aa.google.com
accounts.google.com
acsegateway.fe.apple-dns.net
ad96fa6b6e8959657fe79649e815e7123.profile.cdg50-p1.cloudfront.net
addons-pa.clients6.google.com
adservice.google.com
ak.sail-horizon.com
alt.idgesg.net
amp-api.media.apple.com
api-reuters-reuters-prod.cdn.arcpublishing.com
api.amplitude.com
api.apple-cloudkit.com
api.apple-cloudkit.fe.apple-dns.net
api.fast.com
api.github.com
api.onedrive.com
api.perfops.net
api.smoot.apple.com
apis.google.com
apple-finance.query.yahoo.com
apple.com
appleid.apple.com
apps.mzstatic.com
assets.digg.com
assets.zephr.com
b.thumbs.redditmedia.com
bag-smoot.v.aaplimg.com
bag.itunes.apple.com
beta.darkreading.com
blob.bnz14prdstr11a.store.core.windows.net
blob.dsm07prdstr09a.store.core.windows.net
buy.itunes-apple.com.akadns.net
buy.itunes.apple.com
captive.apple.com
captive.g.aaplimg.com
ccpa.sp-prod.net
cd.connatix.com
cdn.ampproject.org
cdn.cookielaw.org
cdn.digg.com
cdn.jsdelivr.net
cdn.perfops.net
cdn.permutive.com
cf.iadsdk.apple.com
chat-dl.google.com
clients2.google.com
clients4.google.com
clients5.google.com
clients6.google.com
clientservices.googleapis.com
cloudsearch.clients6.google.com
cloudsearch.googleapis.com
cmpv2.networkworld.com
commerce.coinbase.com
completion.amazon.com
config.teams.microsoft.com
configuration.apple.com
configuration.apple.com.akadns.net
configuration.ls.apple.com
contacts.google.com
cs.emxdgt.com
cs9.wac.phicdn.net
cse.google.com
d23tl967axkois.cloudfront.net
d2ef20sk9hi1u3.cloudfront.net
d2in0p32vp1pij.cloudfront.net
d2zv5rkii46miq.cloudfront.net
d33wubrfki0l68.cloudfront.net
d37gvrvc0wt4s1.cloudfront.net
dashboard.tinypass.com
db._dns-sd._udp.selvans.net
digg.com
discourse.pi-hole.net
dit.whatsapp.net
dm2301.storage.live.com
docs.google.com
docs.pi-hole.net
doh.dns.apple.com
doh.dns.apple.com.v.aaplimg.com
dpm.demdex.net
dr3fr5q4g2ul9.cloudfront.net
drive-thirdparty.googleusercontent.com
drive.google.com
e.servebid.com
e.serverbid.com
e1.o.lencr.org
e10499.dsce9.akamaiedge.net
e1329.g.akamaiedge.net
e16126.dscg.akamaiedge.net
e17437.dsct.akamaiedge.net
e3528.dscg.akamaiedge.net
e3925.dscg.akamaiedge.net
e3925.dscx.akamaiedge.net
e4478.a.akamaiedge.net
e5977.dsce9.akamaiedge.net
e673.dsce9.akamaiedge.net
e6858.dscx.akamaiedge.net
e6987.a.akamaiedge.net
e6987.dsce9.akamaiedge.net
e7248.dscb.akamaiedge.net
e9659.dspg.akamaiedge.net
easylist.to
eb2.3lift.com
edge-chat.facebook.com
emoji.redditmedia.com
encrypted-tbn0.gstatic.com
escrowproxy.fe.apple-dns.net
espresso-pa.clients6.google.com
eu-cdn.contentstack.com
eu-images.contentstack.com
experiments.apple.com
fast.com
fbs.smoot.apple.com
fls-na.amazon.com
fmfmobile.fe.apple-dns.net
fmip.fe.apple-dns.net
fonts.googleapis.com
fonts.gstatic.com
forms.hsforms.com
g-msn-com-nsatc.trafficmanager.net
g.live.com
g.stripe.com
g.stripe.com.selvans.net
gateway.facebook.com
gateway.fe.apple-dns.net
gateway.icloud.com
gateway.reddit.com
gdmf.apple.com
gdmf.v.aaplimg.com
geekflare-com.webpkgcache.com
geo-applefinance-cache.internal.query.g03.yahoodns.net
geo.cnbc.com
geolocation.onetrust.com
get-bx.g.aaplimg.com
gitcdn.link
google.com
googleads.g.doubleclick.net
googleapis.com
googletagservices.com
googleusercontent.com
gql-realtime.reddit.com
gql.reddit.com
graph.microsoft.com
gsa.apple.com
gsa.idms-apple.com.akadns.net
gsas.apple.com
gsas.idms-apple.com.akadns.net
gsp-ssl.ls-apple.com.akadns.net
gsp-ssl.ls.apple.com
gsp64-ssl.ls-apple.com.akadns.net
gsp64-ssl.ls.apple.com
gspe1-ssl.ls.apple.com
gspe35-ssl.ls-apple.com.akadns.net
gspe35-ssl.ls.apple.com
gstatic.com
gum.criteo.com
i-bnz05p-cor001.api.p001.1drv.com
i.ytimg.com
i0.wp.com
i2.wp.com
iadsdk.apple.com
ibm.com
ichnaea-web.netflix.com
icloud.com
identity.ess-apple.com.akadns.net
identity.ess.apple.com
idge.staticworld.net
image.cnbcfm.com
images-na.ssl-images-amazon.com
images.idgesg.net
images.techhive.com
in.appcenter.ms
in1-gw2-01-ce7dd027.eastus2.cloudapp.azure.com
in2-prod-east-us2-23fa330.trafficmanager.net
informa-dark-reading.preview.zephr.com
init-cdn.itunes-apple.com.akadns.net
init-p01md-lb.push-apple.com.akadns.net
init-p01md.apple.com
init.ess.apple.com
init.itunes.apple.com
init.push-apple.com.akadns.net
init.push.apple.com
install.pi-hole.net
ipcdn-lb.apple.com.akadns.net
ipcdn.apple.com
ipcdn.g.aaplimg.com
ipv4-c029-iah001-ix.1.oca.nflxvideo.net
ipv4-c050-iah001-ix.1.oca.nflxvideo.net
ipv4-c303-atl001-ix.1.oca.nflxvideo.net
ipv4-c312-dfw001-ix.1.oca.nflxvideo.net
ipv4-c382-dfw001-ix.1.oca.nflxvideo.net
itunes.apple.com
jadserve.postrelease.com
jnn-pa.googleapis.com
js-agent.newrelic.com
js.createsend1.com
js.hsforms.net
js.stripe.com
jssdkcdns.mparticle.com
kasperskycontenthub.com
kt-prod.ess.apple.com
l-0003.l-msedge.net
lb._dns-sd._udp.selvans.net
lcdn-locator-usms11.apple.com.akadns.net
lcdn-locator.apple.com
lcdn-locator.apple.com.akadns.net
lh3.google.com
lh3.googleusercontent.com
lh4.googleusercontent.com
lh5.googleusercontent.com
lh6.googleusercontent.com
login.live.com
m.media-amazon.com
m.stripe.com
m.stripe.network
mail.google.com
maps.google.com
maps.googleapis.com
maps.gstatic.com
mask-api.fe.apple-dns.net
mask-api.icloud.com
match.adsrvr.org
match.sharethrough.com
media-dfw5-1.cdn.whatsapp.net
media.kaspersky.com
media.threatpost.com
mesu-cdn.origin-apple.com.akadns.net
mesu.apple.com
metrics.icloud.com
mmx-ds.cdn.whatsapp.net
motherboard.vice.com
mps.cnbc.com
mtalk.google.com
native.sharethrough.com
news.google.com
news.ycombinator.com
oauth.reddit.com
ocsp.digicert.com
ocsp.pki.goog
ocsp2-lb.apple.com.akadns.net
ocsp2.apple.com
ocsp2.g.aaplimg.com
oembed.vice.com
officecdn-microsoft-com.akamaized.net
officecdnmac.microsoft.com
officeci-mauservice.azurewebsites.net
ogs.google.com
oneclient.sfx.ms
onedriveclucprodbn20009.blob.core.windows.net
onedriveclucproddm20037.blob.core.windows.net
onedscolprdcus00.centralus.cloudapp.azure.com
onedscolprdcus04.centralus.cloudapp.azure.com
onedscolprdeus04.eastus.cloudapp.azure.com
onedscolprdeus06.eastus.cloudapp.azure.com
onedscolprdeus09.eastus.cloudapp.azure.com
onedscolprdneu02.northeurope.cloudapp.azure.com
onedscolprdneu03.northeurope.cloudapp.azure.com
onedscolprdneu06.northeurope.cloudapp.azure.com
onedscolprduks01.uksouth.cloudapp.azure.com
onedscolprdweu01.westeurope.cloudapp.azure.com
onedscolprdwus05.westus.cloudapp.azure.com
onedscolprdwus08.westus.cloudapp.azure.com
onedscolprdwus10.westus.cloudapp.azure.com
onedscolprdwus14.westus.cloudapp.azure.com
optimizationguide-pa.googleapis.com
oracle.com
p.typekit.net
p29-buy-lb.itunes-apple.com.akadns.net
p29-buy.itunes.apple.com
p34-acsegateway.icloud.com
p34-fmfmobile.icloud.com
p58-acsegateway.icloud.com
p58-escrowproxy.icloud.com
p58-fmfmobile.icloud.com
p58-fmip.icloud.com
pancake.apple.com
partiality.itunes.apple.com
pay.google.com
pay.sandbox.google.com
pbs.twimg.com
pd.itunes.apple.com
pds-init.ess.apple.com
people-pa.clients6.google.com
peoplestack-pa.clients6.google.com
peoplestackwebexperiments-pa.clients6.google.com
pgl.yoyo.org
photos.selvans.net
pi-hole.net
pki-goog.l.google.com
play.google.com
play.itunes.apple.com
player.live-video.net
player.stats.live-video.net
pps.whatsapp.net
prebid-match.dotomi.com
r.stripe.com
r3.o.lencr.org
r3.whistleout.com
redirect.prod.experiment.routing.cloudfront.aws.a2z.com
roaming.officeapps.live.com
s-0005.s-msedge.net
s.mzstatic.com
s.w.org
s3.amazonaws.com
safebrowsing.googleapis.com
sandbox.itunes-apple.com.akadns.net
sandbox.itunes.apple.com
sb.scorecardresearch.com
scontent-dfw5-1.xx.fbcdn.net
scontent-dfw5-2.xx.fbcdn.net
scontent.xx.fbcdn.net
scottlinux.com
securemetrics.apple.com
securepubads.g.doubleclick.net
self-events-data.trafficmanager.net
self.events.data.microsoft.com
selvans.net
setup.fe.apple-dns.net
setup.icloud.com
signaler-pa.clients6.google.com
skyapi.live.net
skydrive.wns.windows.com
smoot-feedback.v.aaplimg.com
sourcepoint.mgr.consensu.org
srv.buysellads.com
ssl.gstatic.com
static-redesign.cnbcfm.com
static.adsafeprotected.com
static.doubleclick.net
static.ess.apple.com
static.scroll.com
static.xx.fbcdn.net
staticess.g.aaplimg.com
stats.wp.com
stocks-data-service.apple.com
stocks-data-service.lb-apple.com.akadns.net
stocks-sparkline-lb.apple.com.akadns.net
stocks-sparkline.apple.com
styles.redditmedia.com
su.itunes.apple.com
support.apple.com
swscan.apple.com
sync.1rx.io
threatpost.com
time-osx.g.aaplimg.com
time.apple.com
timeline.google.com
tools.google.com
tools.l.google.com
tpc.googlesyndication.com
ublockorigin.github.io
ublockorigin.pages.dev
update.googleapis.com
us-prod-temp.s3.amazonaws.com
us-south-courier-4.push-apple.com.akadns.net
us2.roaming1.live.com.akadns.net
use.fontawesome.com
use.typekit.net
usermatch.targeting.unrulymedia.com
valid-apple.g.aaplimg.com
valid.apple.com
vice-dev-web-statics-cdn.vice.com
vice-dev-web-statics-cdn.vice.com.selvans.net
vice-web-statics-cdn.vice.com
video-dfw5-1.xx.fbcdn.net
video-images.vice.com
video-weaver.iah50.hls.live-video.net
video.xx.fbcdn.net
waws-prod-bay-045a.cloudapp.net
web.whatsapp.com
webql-redesign.cnbcfm.com
wns.notify.trafficmanager.net
wp-cdn.pi-hole.net
www-smarthomebeginner-com.webpkgcache.com
www.2checkout.com
www.amazon.com
www.apple.com
www.callcentric.com
www.cnbc.com
www.darkreading.com
www.dnsperf.com
www.facebook.com
www.google-analytics.com
www.google.com
www.googleadservices.com
www.googleapis.com
www.googletagmanager.com
www.grc.com
www.grctech.com
www.gstatic.com
www.icloud.com
www.linuxtoday.com
www.networkworld.com
www.paypal.com
www.reddit.com
www.redditstatic.com
www.reuters.com
www.serverwatch.com
www.tm.a.prd.aadg.akadns.net
www.tm.prd.ags.trafficmanager.net
www.vice.com
www.whistleout.com
www.whistleout.com.au
www.youtube.com
x.bidswitch.net
xp.apple.com
xp.itunes-apple.com.akadns.net
yahoo.com
yt3.ggpht.com
selvansoft.com
selvans.net
mypassword.us
EOF
}

do_single_host() {
  local host=$1
  dig $host +noall +answer +stats $dns_server | awk '$3 == "IN" && $4 == "A"{ip=$5}/Query time:/{t=$4 " " $5}END{print ip, t}'
}

get_default_dns() {
  local ds=""
  # figure out default DNS on different OS
  if [ $os_name == "Darwin" ] ; then
    ds=$(scutil --dns |grep nameserver|awk -F: 'FNR == 1 {print $2}'|tr -d ' ')
  elif [ $os_name == "Linux" ] ; then
    # figure out for linux, for now just empty line.
    ds=$(host -v foo.bar | awk -F "[ #]" '/Received /{print$5}' | uniq)
  fi
  
  if [ ! -z $ds ] ; then
    dns_server="@$ds" 
    log.stat "Using default DNS server: $dns_server"
  fi
}

# -------------------------------  main -------------------------------
# First, make sure scripts root path is set, we need it to include files
if [ ! -z "$scripts_github" ] && [ -d $scripts_github ] ; then
  # include logger, functions etc as needed 
  source $scripts_github/utils/logger.sh
  source $scripts_github/utils/functions.sh
else
  echo "ERROR: SCRIPTS_GITHUB env variable is either not set or has invalid path!"
  echo "The env variable should point to root dir of scripts i.e. $default_scripts_github"
  exit 1
fi
# init logs
log.init $my_logfile

# parse commandline options
while getopts $options opt ; do
  case $opt in
    f)
      host_list="${OPTARG}"
      ;;
    u)
      url_host_list="${OPTARG}"
      ;;
    s)
      single_host=${OPTARG}
      ;;
    d)
      dns_server="@${OPTARG}"
      log.stat "Using DNS server: $dns_server"
      ;;
    v)
      verbose=1
      ;;
    ?|h|*)
      usage
      ;;
  esac
done

if [ -z $dns_server ] ; then
  get_default_dns
fi

if [ ! -z $single_host ] ; then
  log.stat "DNS performance test for single host: $single_host" $green
  do_single_host
  exit 0
fi

log.stat "DNS perforamce test for list of hosts" $green
if [ ! -z $host_list ] ; then
  log.stat "Using host list file: $host_list"
  time -p dig -f $host_list +noall +answer $dns_server  >/dev/null
elif [ ! -z $url_host_list ] ; then
  # download the file first
  log.stat "Downloading host list from: $url_host_list"
  curl -s $url_host_list --output $default_host_list
  time -p dig -f $default_host_list +noall +answer $dns_server >/dev/null
else
  # no host list, use the built-in/hardcoded list
  create_default_host_list
  log.stat "Using host list file: $default_host_list"
  time -p dig -f $default_host_list +noall +answer $dns_server >/dev/null
fi

