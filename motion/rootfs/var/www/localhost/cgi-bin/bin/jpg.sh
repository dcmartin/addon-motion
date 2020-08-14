#!/bin/bash

DIR=${MOTION_APACHE_HTDOCS:-/var/www/localhost/htdocs}/cameras

if [ -d "${DIR}" ]; then
  if [ ! -z "${1:-}" ]; then
    camera=${1}
    if [ ! -z "${2:-}" ]; then
      event=${camera}/${2}
    fi
    if [ -s "${DIR}/${event}.json" ]; then
      id=($(jq -r '.images[].id' ${DIR}/${event}.json))
      if [ ${#id[@]} -gt 0 ]; then
        jpg="${DIR}/${camera}/${id[0]}.jpg"
        if [ -s ${jpg} ]; then
          cat ${jpg}
        fi
      fi
    fi
  fi
fi
