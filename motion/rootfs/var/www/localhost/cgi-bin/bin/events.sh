#!/bin/bash

###
### THIS SCRIPT LISTS EVENTS FOR THE DEVICE
###
### CONSUMES THE FOLLOWING ENVIRONMENT VARIABLES:
###
### + MOTION_APACHE_HTDOCS
###

DIR=${MOTION_APACHE_HTDOCS:-/var/www/localhost/htdocs}/cameras

if [ ! -z "${1:-}" ]; then DIR=${DIR}/${1}; fi
if [ -d "${DIR:-}" ]; then
  echo '{"timestamp":"'$(date -u +%FZ%TZ)'",'
  if [ ! -z "${1:-}" ]; then echo '"camera":"'${1}'",'; fi
  if [ ! -z "${2:-}" ]; then echo '"event":"'${2}'",'; target="${2}.json"; else target='[0-9][0-9]*-[0-9][0-9]*.json'; fi
  echo '"events":['
  i=0; find ${DIR} -name "${target}" -print | while read; do
    c="${REPLY#*/cameras/}"
    c="${c%%/*}"
    r="${REPLY##*/}"
    r="${r%%.*}"
    t=${r##*-}
    u=${r#*-}
    if [ "${t}" != "${u}" ]; then continue; fi
    if [ ${i} -gt 0 ]; then echo ','; fi
    echo '{"id":"'${r}'","event":'
    if [ ! -z "${2:-}" ]; then
      jq -c '.' ${REPLY}
    else
      jq -c '.|.image=(.image!=null)' ${REPLY}
    fi
    echo '}'
    i=$((i+1))
  done
  echo ']}'
else
  echo 'null'
fi

