#!/usr/bin/with-contenv bashio

###
### motion-tools.sh
###

##
## DATEUTILS
##

if [ -e /usr/bin/dateutils.dconv ]; then
  dateconv=/usr/bin/dateutils.dconv
elif [ -e /usr/bin/dateconv ]; then
  dateconv=/usr/bin/dateconv
elif [ -e /usr/local/bin/dateconv ]; then
  dateconv=/usr/local/bin/dateconv
else
  exit 1
fi

###
### UTILITY
###

motion::util.dateconv()
{
  hzn::log.trace "${FUNCNAME[0]}; args: ${*}"

  local dateconv

  if [ -e /usr/bin/dateutils.dconv ]; then
    dateconv=/usr/bin/dateutils.dconv
  elif [ -e /usr/bin/dateconv ]; then
    dateconv=/usr/bin/dateconv
  elif [ -e /usr/local/bin/dateconv ]; then
    dateconv=/usr/local/bin/dateconv
  fi
  if [ ! -z "${dateconv:-}" ]; then
    result=$(${dateconv} ${*})
  else
    hzn::log.error "failure; no dateutils installed ${*}"
  fi
  echo "${result:-}"
}

###
### CONFIGURATION
###

motion::config.target_dir()
{
  hzn::log.trace "${FUNCNAME[0]}"

  local file=$(motion::config.file)
  local result=""

  if [ -s "${file}" ]; then
    result=$(jq -r '.motion::target_dir' ${file})
  else
    hzn::log.warn "no configuration JSON: ${file}"
  fi
  echo "${result:-}"
}

motion::config.share_dir()
{
  hzn::log.trace "${FUNCNAME[0]}"

  local file=$(motion::config.file)
  local result=""

  if [ -s "${file}" ]; then
    result=$(jq -r '.share_dir' ${file})
  else
    hzn::log.warn "no configuration file"
  fi
  echo "${result:-}"
}

motion::config.group()
{
  hzn::log.trace "${FUNCNAME[0]}"

  local file=$(motion::config.file)
  local result=""

  if [ -s "${file}" ]; then
    result=$(jq -r '.group' ${file})
  else
    hzn::log.warn "no configuration file"
  fi
  echo "${result:-}"
}

motion::config.device()
{
  hzn::log.trace "${FUNCNAME[0]}"

  local file=$(motion::config.file)
  local result=""

  if [ -s "${file}" ]; then
    result=$(jq -r '.device' ${file})
  else
    hzn::log.warn "no configuration file"
  fi
  echo "${result:-}"
}

motion::config.mqtt()
{
  hzn::log.trace "${FUNCNAME[0]}"

  local file=$(motion::config.file)
  local result="null"

  if [ -s "${file}" ]; then
    result=$(jq -c '.mqtt?' ${file})
  else
    hzn::log.warn "no configuration file"
  fi
  echo "${result:-}"
}

motion::config.cameras()
{
  hzn::log.trace "${FUNCNAME[0]}"

  local file=$(motion::config.file)
  local result="null"

  if [ -s "${file}" ]; then
    result=$(jq -c '.cameras?' ${file})
  fi
  echo "${result:-}"
}

motion::config.post_pictures()
{
  hzn::log.trace "${FUNCNAME[0]}"

  local file=$(motion::config.file)
  local result=""

  if [ -s "${file}" ]; then
    result=$(jq -r '.motion::post_pictures' ${file})
  fi
  echo "${result:-}"
}

motion::config.file()
{
  hzn::log.trace "${FUNCNAME[0]}"

  local conf="${MOTION_CONF:-}"
  if [ ! -z "${conf:-}" ]; then
    conf="${MOTION_CONF%/*}/motion::json"
  else
    conf="/etc/motion/motion::json"
    hzn::log.warn "using default, static, motion configuration JSON file: ${conf}"
  fi
  echo "${conf:-}"
}

motion::restart.camera()
{
  hzn::log.debug "${FUNCNAME[0]} ${*}"

  local camera=${1:-}
  local host=${2:-localhost}
  local port=${3:-8080}

  local cameras=($(motion::status ${host} ${port} | jq -r '.cameras[].camera'))

  echo -n '{"host":"'${host}'","port":'${port}',"cameras":['
  if [ ${#cameras[@]} -gt 0 ]; then
    i=1; j=0
    for c in ${cameras[@]}; do
      if [ -z "${camera:-}" ] || [ "${c:-}" = "${camera}" ]; then
        if [ ${j} -gt 1 ]; then echo ','; fi
        r=$(curl -sqSL --connect-timeout 10 ${host}:${port}/${i}/action/restart &> /dev/null && echo '{}' | jq '.id='${i}'|.camera="'${c}'"|.status="restarted"')
        echo -n "${r}"
        j=$((j+1))
      fi
      i=$((i+1))
    done
  fi
  echo ']}'
}

motion::status()
{
  hzn::log.debug "${FUNCNAME[0]} ${*}"

  local host=${1:-localhost}
  local port=${2:-8080}

  local cameras=($(curl --connect-timeout 10 -qsSL http://${host}:${port}/0/detection/status 2> /dev/null | awk '{ print $5 }'))

  echo -n '{"host":"'${host}'","port":'${port}',"cameras":['
  if [ ${#cameras[@]} -gt 0 ]; then
    i=1
    for c in ${cameras[@]}; do
      if [ ${i} -gt 1 ]; then echo ','; fi
      if [ "${c:-}" = 'ACTIVE' ]; then
        r=$(curl --connect-timeout 10 -sqSL ${host}:${port}/${i}/detection/connection 2> /dev/null \
             | tail +2 \
             | awk '{ printf("{\"camera\":\"%s\",\"status\":\"%s\"}\n",$4,$6) }' \
             | jq '.id='${i}'|.status=(.status=="OK")')
          echo -n "${r}"
      fi
      i=$((i+1))
    done
  fi
  echo ']}'
}

##
## MQTT
##

motion::_mqtt.pub()
{
  local ARGS=${*}
  local code
  local err

  if [ ! -z "$(motion::config.file)" ] && [ -s $(motion::config.file) ]; then
    local username=$(echo $(motion::config.mqtt) | jq -r '.username')
    local port=$(echo $(motion::config.mqtt) | jq -r '.port')
    local host=$(echo $(motion::config.mqtt) | jq -r '.host')
    local password=$(echo $(motion::config.mqtt) | jq -r '.password')
    local temp=$(mktemp)

    if [ ! -z "${ARGS}" ]; then
      if [ ! -z "${username}" ] && [ "${username}" != 'null' ]; then
	ARGS='-u '"${username}"' '"${ARGS}"
      fi
      if [ ! -z "${password}" ] && [ "${password}" != 'null' ]; then
	ARGS='-P '"${password}"' '"${ARGS}"
      fi
      mosquitto_pub -i "$(motion::config.device)" -h "${host}" -p "${port}" ${ARGS} &> ${temp}
      code=$?
      if [ -s "${temp}" ]; then err=$(cat ${temp}); fi
      rm -f ${temp}
    else
      code=1
      err="invalid arguments"
    fi
  else
    code=1
    err="motion configuration; file not found or empty"
  fi
  echo ${err:-null}
  return ${code:-1}
}

motion::mqtt.pub()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"
  local result=$(motion::_mqtt.pub ${*})
  local code=$?

  if [ ${code:-1} -ne 0 ]; then
    hzn::log.error "${FUNCNAME[0]}: failed to publish MQTT message; args: ${*}; code: ${code}; result: ${result:-}"
  else
    hzn::log.debug "${FUNCNAME[0]}: published MQTT message; args: ${*}; code: ${code}; result: ${result:-}"
  fi
  return code
}
