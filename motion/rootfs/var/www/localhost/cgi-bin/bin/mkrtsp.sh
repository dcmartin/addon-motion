#!/bin/bash

myip()
{
  if [ "${DEBUG:-false}" = 'true' ]; then echo "${FUNCNAME[0]} ${*}" &> /dev/stderr; fi

  local ipaddrs=$(ip addr | egrep -A3 'UP' | egrep 'inet ' | awk '{ print $2 }' | awk -F/ 'BEGIN { x=0; printf("["); } { if (x++>0) printf(",\"%s\"", $1); else printf("\"%s\"",$1) } END { printf("]"); }')

  if [ "${ipaddrs:-null}" != 'null' ]; then
    local ips=$(echo "${ipaddrs}" | jq -r '.[]')

    for ip in ${ips}; do
      if [[ ${ip} =~ 127.* ]] || [[ ${ip} =~ 172.* ]]; then continue; fi
      echo ${ip}
      break
    done
  fi
}

find_rtsp()
{
  if [ "${DEBUG:-false}" = 'true' ]; then echo "${FUNCNAME[0]} ${*}" &> /dev/stderr; fi

  local result=$(find-rtsp.sh $(myip) 2> /dev/null)

  echo ${result:-null}
}

###
### MAIN
###

if [ -z "${1:-}" ] || [ ! -e "${1:-}" ]; then
  echo "*** ERROR -- $0 $$ -- provide fullpath for output file" &>  /dev/stderr
  exit 1
fi

output=${1:-}

temp=$(mktemp)
echo '{"rtsp":'$(find_rtsp)'}' | jq -c '.' > ${temp}
mv -f ${temp} ${output}
if [ "${DEBUG:-}" = true ]; then echo "--- INFO -- $0 $$ -- output:" $(cat ${output}) &> ${LOG}; fi
