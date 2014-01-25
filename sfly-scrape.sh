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

getSite() {
  GSITE=$1;
  PAGE=$2;
  ID="${GSITE}${PAGE}";

  # page just does this:
  # if (window.Shr && Shr.Page) { 
  #        Shr.Page.render();
  # so, retrieve JS containing page content

  curl -s -b "${COOKIEJAR}" -c "${COOKIEJAR}" -A "${UA}" -o "${ID}.js" \
       "https://cmd.shutterfly.com/commands/format/js?site=${GSITE}&page=${GSITE}${PAGE}&v=1";

  #extract Shr.S JSON blob containing site data
  #and Shr.P JSON blob containing page data
  $(npm bin)/js-beautify "${ID}.js" > "${ID}-pp.js";
  rm "${ID}.js";

  rm -f "${ID}-rawdata.js";
  for sect in S P; do
    PG_DATA_START=$(grep -n "^Shr\.${sect} " "${ID}-pp.js" | cut -d : -f 1);
    PG_DATA_END=$(grep -n "^Shr\." "${ID}-pp.js" | grep -A 1 "^[0-9]*:Shr\.${sect} " | tail -n 1 | cut -d : -f 1);

    head -n $((PG_DATA_END - 1)) "${ID}-pp.js" | tail -n +${PG_DATA_START} >> "${ID}-rawdata.js";
  done;

  rm "${ID}-pp.js";

  #construct a bit of JS that will deal with the Shr.S and Shr.P JSON blobs
  echo "Shr = {};" > "${ID}-data.js";

  cat "${ID}-rawdata.js" >> "${ID}-data.js";
  rm "${ID}-rawdata.js";
}

#get main site
getSite "${SITE}" "";

#look for activity feed
cat "${SITE}-data.js" > "${SITE}-hasaf.js";
cat >> "${SITE}-hasaf.js" <<EOF
var foundActivityFeed = false;
for(var iSect=0;iSect<Shr.P.sections.length;iSect++){
    if(Shr.P.sections[iSect].mid === "ActivityFeed"){
        foundActivityFeed = true;
        break;
    }
}

console.log(foundActivityFeed);

EOF

HASAF=$(node ${SITE}-hasaf.js);
rm "${SITE}-hasaf.js";


if [ "$HASAF" == "true" ]; then
  #activity feed found; use it
  cat "${SITE}-data.js" > "${SITE}-dump.js";
  cat >> "${SITE}-dump.js" <<EOF

dumpActivityFeedEntry = function(ent, iEnt){
  var url = "https://${SITE}.shutterfly.com/" + ent.pageId.replace("${SITE}","") + "/" + ent.content.nodeId;
  console.log("<h3><a href=\"" + url + "\">" + ent.content.title + "</a></h3><hr/>");
  if(ent.content.summary){
    console.log("<p>" + ent.content.summary + "</p>");
  }
}

for(var iSect=0;iSect<Shr.P.sections.length;iSect++){
    if(Shr.P.sections[iSect].mid === "ActivityFeed"){
        for(var iEnt=0;iEnt<Shr.P.sections[iSect].entries.length;iEnt++){
           dumpActivityFeedEntry(Shr.P.sections[iSect].entries[iEnt], iEnt);
        }
    }
}
EOF

else
  #no activity feed; retrieve list of sub-pages
  cat "${SITE}-data.js" > "${SITE}-dumppages.js";
  cat >> "${SITE}-dumppages.js" <<EOF
var pages = [];
for(var iPage=0; iPage < Shr.S.pages.length; iPage++){
    console.log(Shr.S.pages[iPage].name);
}
EOF

  PAGES=$(node "${SITE}-dumppages.js");
  rm "${SITE}-dumppages.js";

  #retrieve raw data for all sub-pages
  cat "${SITE}-data.js" > "${SITE}-dump.js";
  echo "pages = {};" >> "${SITE}-dump.js";
  for page in ${PAGES}; do
    getSite "${SITE}" "%2f${page}";
    echo "pages.${page} = {}; pages.${page}.Shr = {};" >> "${SITE}-dump.js";
    sed "s/^Shr\./pages.${page}.Shr./" "${SITE}%2f${page}-data.js" | \
        sed "s/^Shr = {};$//" >> "${SITE}-dump.js";
    rm "${SITE}%2f${page}-data.js";
  done;

  #retrieve journal data from main page and all sub-pages
  cat >> "${SITE}-dump.js" <<EOF

dumpJournalEntry = function(ent, iEnt){
  var oneDayAgo = new Date();
  oneDayAgo.setFullYear(oneDayAgo.getFullYear(),
                        oneDayAgo.getMonth(),
                        oneDayAgo.getDate() - 1);
  var entryDate = new Date(ent.publishDateUtc * 1000);
  var url = "https://${SITE}.shutterfly.com/" + "/" + ent.nodeId;
  console.log("<h3><a href=\"" + url + "\">" + ent.title + "</a></h3><hr/>");
  if(entryDate <= oneDayAgo){
    console.log("<p>text of entry older than one day omitted</p>");
  }
  else if(ent.text){
    console.log("<p>" + ent.text + "</p>");
  }
};

var pagePs = [Shr.P];
for(page in pages){
    if(pages.hasOwnProperty(page)){
        pagePs.push(pages[page].Shr.P);
    }
}

for(var iPagePs=0; iPagePs < pagePs.length; iPagePs++){
    var p = pagePs[iPagePs];
    console.log("<h1>" + p.title + "</h1>");

    for(var iSect=0;iSect<p.sections.length;iSect++){
        if(p.sections[iSect].mid === "Journal"){
            for(var iEnt=0;iEnt<p.sections[iSect].items.length;iEnt++){
                dumpJournalEntry(p.sections[iSect].items[iEnt], iEnt);
            }
        }
    }
}
EOF

fi;

rm "${COOKIEJAR}";
rm "${SITE}-data.js";


#finally, run the generated script to dump the activity
node "${SITE}-dump.js" > "${SITE}-activity.html";
rm "${SITE}-dump.js";

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
