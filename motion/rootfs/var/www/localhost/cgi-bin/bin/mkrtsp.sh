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
  local result=$(sudo find-rtsp.sh $(myip) 2> /dev/null)

  echo ${result:-null}
}

###
### MAIN
###

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  echo "*** ERROR -- $0 $$ -- provide fullpath for output file and pidfile" &>  /dev/stderr
  exit 1
fi

output=${1:-}
pidfile=${2:-}
temp=$(mktemp)

echo $$ > ${pidfile}

exec 0>&- # close stdin
exec 1>&- # close stdout
exec 2>&- # close stderr

# doit
echo '{"rtsp":'$(find_rtsp)'}' | jq -c '.' > ${temp}

mv -f ${temp} ${output}
rm -f ${pidfile}
