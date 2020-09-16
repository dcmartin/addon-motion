#!/bin/bash

if [ -d "/tmpfs" ]; then TMPDIR="/tmpfs"; else TMPDIR="/tmp"; fi

###
### MAIN
###

if [ -z "${1:-}" ] || [ ! -s "${1:-}" ] || [ -z "${2:-}" ]; then
  exit 1
fi

OUTPUT=${1}
PIDFILE=${2}

if [ -s ${PIDFILE} ]; then
  PID=$(cat ${PIDFILE})
  if [ ! -z "${PID:-}" ]; then
    PS=($(ps alxwww | egrep "^[ \t]*${PID} " | awk '{ print $1 }'))
    if [ "${PS:-}" = "${PID}" ]; then
      exit
    else
      rm -f ${PIDFILE}
    fi
  fi
fi


exec 0>&- # close stdin
exec 1>&- # close stdout
exec 2>&- # close stderr

${0%/*}/mkrtsp.sh ${OUTPUT} &
PID=$!
echo "${PID}" > ${PIDFILE}
wait ${PID}
rm -f ${PIDFILE}
