#!/bin/bash

# {
#   "rtsp": [
#     { "ip": "192.168.1.115", "type": "rtsp", "code": 200 },
#     { "ip": "192.168.1.162", "type": "rtsp", "code": 200 },
#     { "ip": "192.168.1.163", "code": 503 },
#     { "ip": "192.168.1.165", "type": "rtsp", "code": 200 },
#     { "ip": "192.168.1.170", "type": "rtsp", "code": 200 },
#     { "ip": "192.168.1.182", "type": "rtsp", "code": 200 },
#     { "ip": "192.168.1.183", "type": "rtsp", "code": 200 },
#     { "ip": "192.168.1.222", "type": "rtsp", "code": 200 },
#     { "ip": "192.168.1.224", "type": "rtsp", "code": 200 },
#     { "ip": "192.168.1.225", "type": "rtsp", "code": 200 },
#     { "ip": "192.168.1.226", "type": "rtsp", "code": 200 }
#   ]
# }

function rtsp::make()
{
  local OUTPUT=${1:-}
  local PIDFILE=${2:-}

  ${0%/*}/mkrtsp.sh ${OUTPUT} ${PIDFILE} &
}

function rtsp()
{
  local output="${TMPDIR}/${CMD}.${DATE}.json"
  local pidfile="${TMPDIR}/${CMD}.pid"
  local BUFFER='null'

  if [ -s "${output}" ]; then
    jq -c '.' ${output}
    return
  fi

  # test for running process
  if [ -s ${pidfile}  ]; then
    local PID=$(cat ${pidfile})

    if [ ! -z "${PID:-}" ]; then
      local PS=$(ps alxwww | egrep "^[ \t]*${PID} " | awk '{ print $1 }')
      if [ "${PS:-}" != "${PID}" ]; then
        rm -f ${pidfile}
      fi
    fi
  fi

  # start iff not running
  if [ ! -s ${pidfile}  ]; then
    rtsp::make ${output} ${pidfile}
  fi

  local outputs=($(find ${TMPDIR} -name "${CMD}.*.json" -print))
  if [ ${#outputs[@]} -gt 0 ]; then
    output=${outputs[0]}
    if [ -s "${output}" ]; then
      AGE=${output%.*} && AGE=${AGE##*.}
      AGE=$((SECONDS-AGE))
      BUFFER=$(jq -c '.' ${output})
    else
      BUFFER='{"error":"empty","retry":30}'
    fi
    # cleanup old
    i=1; while [ ${i} -lt ${#outputs[@]} ]; do
      rm -f ${outputs[${i}]}
      i=$((i+1))
    done
  else
    BUFFER='{"error":"initializing","retry":60}'
  fi

  ## output
  echo "${BUFFER}"
}

###
### MAIN
###

if [ -d "/tmpfs" ]; then TMPDIR="/tmpfs"; else TMPDIR="/tmp"; fi

TTL=900
SECONDS=$(date +%s)
DATE=$(echo "${SECONDS} / ${TTL} * ${TTL}" | bc)

CMD=${0##*/} && CMD=${CMD%%.sh*} && ${CMD} ${*}
