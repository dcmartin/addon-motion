#!/usr/bin/with-contenv bashio

source /usr/bin/motion-tools.sh

###
### ftp_notifywait.sh
###

ftp_notifywait()
{
  hzn::log.debug "${FUNCNAME[0]} ${*}"

  local cameras=$(motion::configuration.cameras)

  for name in $(echo "${cameras}" | jq -r '.[]|.name'); do
    local type=$(echo "${cameras}" | jq -r '.[]|select(.name=="'"${name}"'").type')

    if [ "${type}" == 'ftpd' ]; then
      local dir=$(echo "${cameras}" | jq -r '.[]|select(.name=="'"${name}"'").share_dir')
      local input="${dir}.jpg"

      # prepare destination
      hzn::log.debug "cleaning directory: ${input%.*}"
      rm -fr "${input%.*}"

      # create destination
      hzn::log.debug "making directory: ${input%.*}"
      mkdir -p "${input%.*}"

      # make initial target
      hzn::log.debug "copying sample to ${input}"
      cp -f /etc/motion/sample.jpg "${input}"

      # setup notifywait
      hzn::log.debug "initiating do_ftp_notifywait.sh ${input%.*} ${input}"
      do_ftp_notifywait.sh "${input%.*}" "${input}" &

      # manually "find" camera
      hzn::log.debug "running on_camera_found.sh ${name} $($dateconv -f '%Y %m %d %H %M %S' -i '%s' $(date -u +%s))"
      on_camera_found.sh ${name} $($dateconv -f '%Y %m %d %H %M %S' -i "%s" $(date -u '+%s'))
    fi
  done
}

###
### MAIN
###

ftp_notifywait ${*}
