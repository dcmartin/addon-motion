#!/bin/bash

DIR=${MOTION_APACHE_HTDOCS:-/var/www/localhost/htdocs}/cameras

if [ -d "${DIR}" ]; then
  if [ ! -z "${1:-}" ]; then
    camera=${1}
    if [ ! -z "${2:-}" ]; then
      event=${camera}/${2}
    fi
    if [ -s "${DIR}/${event}.json" ]; then
      id=($(jq -r '.movie.file' ${DIR}/${event}.json))
      if [ ${#id[@]} -gt 0 ]; then
        mp4="${DIR}/${camera}/${id[0]##*/}"
        if [ -s ${mp4} ]; then
          cat ${mp4}
        fi
      fi
    fi
  fi
fi
