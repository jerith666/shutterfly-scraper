#!/usr/bin/env bash

SITE="${1}"; #scrape activity from this site (https://<site>.shutterfly.com)
PW="${2}"; #with this password
RECIPIENTS="${3}"; #send to these email addresses (quoted, space separated)

UA="Mozilla/5.0 (X11; Linux i686; rv:17.0) Gecko/20100101 Firefox/17.0";
COOKIEJAR=${SITE}-cookies
T=$(date +%s);

rm -f "${COOKIEJAR}";

# get site JS blob, containing initial "visitor" cookie:

curl -s -c "${COOKIEJAR}" -A "${UA}" -o /dev/null \
     "https://cmd.shutterfly.com/commands/format/js?site=${SITE}&page=${SITE}&v=1"

# login to get sflySID cookie

curl -s -b "${COOKIEJAR}" -c "${COOKIEJAR}" -A "${UA}" -o /dev/null \
     -d t=${T} -d pw="${PW}" -d h="" -d av=0 \
     "https://cmd.shutterfly.com/commands/sites/password?site=${SITE}&"

# page just does this:
# if (window.Shr && Shr.Page) { 
#        Shr.Page.render();
# so, retrieve JS containing page content

curl -s -b "${COOKIEJAR}" -c "${COOKIEJAR}" -A "${UA}" -o "${SITE}.js" \
     "https://cmd.shutterfly.com/commands/format/js?site=${SITE}&page=${SITE}&v=1"

rm "${COOKIEJAR}";

#extract Shr.P JSON blob containing site data
$(npm bin)/js-beautify "${SITE}.js" > "${SITE}-pp.js";
#rm "${SITE}.js";

PG_DATA_START=$(grep -n "^Shr\.P " "${SITE}-pp.js" | cut -d : -f 1);
PG_DATA_END=$(grep -n "^Shr\." "${SITE}-pp.js" | grep -A 1 "^[0-9]*:Shr\.P " | tail -n 1 | cut -d : -f 1);

head -n $((PG_DATA_END - 1)) "${SITE}-pp.js" | tail -n +${PG_DATA_START} > "${SITE}-data.js";

#rm "${SITE}-pp.js";

#construct a bit of JS that will deal with the Shr.P JSON blob and
#dump out the "recent posts" section in a readable way

echo "Shr = {};" > "${SITE}-dump.js";

cat "${SITE}-data.js" >> "${SITE}-dump.js";
#rm "${SITE}-data.js";

cat >> "${SITE}-dump.js" <<EOF
dumpEntry = function(ent, iEnt){
  var url = "https://${SITE}.shutterfly.com/" + "/" + ent.nodeId;
  console.log("<h3><a href=\"" + url + "\">" + ent.title + "</a></h3><hr/>");
  if(ent.text){
    console.log("<p>" + ent.text + "</p>");
  }
};

for(var iSect=0;iSect<Shr.P.sections.length;iSect++){
    if(Shr.P.sections[iSect].mid === "Journal"){
        for(var iEnt=0;iEnt<Shr.P.sections[iSect].items.length;iEnt++){
	    dumpEntry(Shr.P.sections[iSect].items[iEnt], iEnt);
        }
    }
}
EOF

node "${SITE}-dump.js" > "${SITE}-activity.html";
#rm "${SITE}-dump.js";

if diff "${SITE}-activity-last.html" "${SITE}-activity.html" > /dev/null; then
  true;#stay silent
else
  #send new content

  #'email --html' doesn't seem to work :(
  mail -a "Content-Type: text/html" \
       -a "From: ${SITE}@shutterfly.com" \
       -s "Recent activity for ${SITE} on Shutterfly" \
       "${RECIPIENTS}" < "${SITE}-activity.html";
fi;

mv -f "${SITE}-activity.html" "${SITE}-activity-last.html";
