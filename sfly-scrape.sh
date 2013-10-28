#!/usr/bin/env bash

SITE="${1}";
PW="${2}";

UA="Mozilla/5.0 (X11; Linux i686; rv:17.0) Gecko/20100101 Firefox/17.0";
COOKIEJAR=${SITE}-cookies
T=$(date +%s);

rm ${COOKIEJAR};

# get site JS blob, containing initial "visitor" cookie:

curl -c ${COOKIEJAR} -A "${UA}" -o /dev/null \
     "https://cmd.shutterfly.com/commands/format/js?site=${SITE}&page=${SITE}&v=1"

# login to get sflySID cookie

curl -b ${COOKIEJAR} -c ${COOKIEJAR} -A "${UA}" -o /dev/null \
     -d t=${T} -d pw="${PW}" -d h="" -d av=0 \
     "https://cmd.shutterfly.com/commands/sites/password?site=${SITE}&"

# retrieve JS containing page content

curl -b ${COOKIEJAR} -c ${COOKIEJAR} -A "${UA}" -o "${SITE}.js" \
     "https://cmd.shutterfly.com/commands/format/js?site=${SITE}&page=${SITE}"

