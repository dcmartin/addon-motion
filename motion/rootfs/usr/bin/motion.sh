#!/usr/bin/with-contenv bashio

source /usr/bin/service-tools.sh
source /usr/bin/motion-tools.sh

###
## FUNCTIONS
###

## SAMBA

function motion::samba.start()
{
  hzn::log.trace "${FUNCNAME[0]}" "${*}"

  mkdir /data/samba && chmod 777 /data/samba
  echo '[share]' >> /etc/samba/smb.conf
  echo '    path = /data/samba' >> /etc/samba/smb.conf
  echo '    read only = no' >> /etc/samba/smb.conf
  echo '    public = yes' >> /etc/samba/smb.conf
  echo '    writable = yes' >> /etc/samba/smb.conf
  rc-service samba start
}

## APACHE

function motion::apache.start_foreground()
{
  hzn::log.trace "${FUNCNAME[0]}" "${*}"
  motion::apache.start true ${*}
}

function motion::apache.start_background()
{
  hzn::log.trace "${FUNCNAME[0]}" "${*}"
  motion::apache.start false ${*}
}

function motion::apache.start()
{
  hzn::log.trace "${FUNCNAME[0]}" "${*}"

  local foreground=${1}; shift

  local conf=${1}
  local host=${2}
  local port=${3}
  local admin="${4:-root@${host}}"
  local tokens="${5:-}"
  local signature="${6:-}"

  # edit defaults
  sed -i 's|^Listen .*|Listen '${port}'|' "${conf}"
  sed -i 's|^ServerName .*|ServerName '"${host}:${port}"'|' "${conf}"
  sed -i 's|^ServerAdmin .*|ServerAdmin '"${admin}"'|' "${conf}"

  # SSL
  if [ ! -z "${tokens:-}" ]; then
    sed -i 's|^ServerTokens.*|ServerTokens '"${tokens}"'|' "${conf}"
  fi
  if [ ! -z "${signature:-}" ]; then
    sed -i 's|^ServerSignature.*|ServerSignature '"${signature}"'|' "${conf}"
  fi

  # enable CGI
  sed -i 's|^\([^#]\)#LoadModule cgi|\1LoadModule cgi|' "${conf}"

  # export environment
  export MOTION_JSON_FILE=$(motion::configuration.file)
  export MOTION_SHARE_DIR=$(motion::configuration.share_dir)

  # pass environment
  echo 'PassEnv MOTION_JSON_FILE' >> "${conf}"
  echo 'PassEnv MOTION_SHARE_DIR' >> "${conf}"

  # make /run/apache2 for PID file
  mkdir -p /run/apache2

  # start HTTP daemon
  hzn::log.info "Starting Apache: ${conf} ${host} ${port}"

  if [ "${foreground:-false}" = 'true' ]; then
    MOTION_JSON_FILE=$(motion::configuration.file) httpd -E /tmp/hzn::log -e debug -f "${MOTION_APACHE_CONF}" -DFOREGROUND
  else
    MOTION_JSON_FILE=$(motion::configuration.file) httpd -E /tmp/hzn::log -e debug -f "${MOTION_APACHE_CONF}"
  fi
}

## CONFIGURE

# configure cameras
function motion::configure.cameras()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"

  local JSON=${*:-null}
  local MOTION_GROUP=$(echo "${JSON}" | jq -r '.group')
  local MOTION_DEVICE=$(echo "${JSON}" | jq -r '.device')
  local MOTION_CLIENT=$(echo "${JSON}" | jq -r '.client')
  local MOTION=$(echo "${JSON:-null}" | jq -c '.motion?')
  local WATSON=$(echo "${JSON:-null}" | jq -c '.watson?')
  local DIGITS=$(echo "${JSON:-null}" | jq -c '.digits?')
  local ncamera=$(jq '.cameras|length' "${CONFIG_PATH}")
  #local ncamera=$(bashio::config 'cameras' | jq '.|length'))
  local MOTION_COUNT=0
  local CNUM=0
  local CAMERAS=
  local VALUE=
  local CAMERA_CONF=
  local CAMERAS='[]'
  
  ## LOOP THROUGH ALL CAMERAS
  for (( i=0; i < ncamera; i++)); do
    hzn::log.debug "${FUNCNAME[0]}: processing camera; id: ${i}"

    # initialize
    local CAMERA=$(motion::configure.camera ${i})

    if [ "${CAMERA:-null}" != 'null' ]; then
      hzn::log.debug "${FUNCNAME[0]}: processed camera ${i}: $(echo "${CAMERA}" | jq -c '.')"
      CAMERAS=$(echo "${CAMERAS:-null}" | jq '.+=['"${CAMERA}"']')
    else
      hzn::log.error "${FUNCNAME[0]}: failed to process camera ${i}"
    fi
  done

  
  echo "${CAMERAS}"
}

function motion::configure.camera()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"

  local i=${1:-0}
  local CAMERA='{}'
  local c=$(jq -c '.cameras['${i}']' "${CONFIG_PATH}")
  local CNAME
  local VALUE
  local WIDTH
  local HEIGHT
  local EVENT_GAP

  # id
  CAMERA=$(echo "${CAMERA}" | jq '.id="'${i}'"')
  
  # name
  VALUE=$(echo "${c}" | jq -r '.['${i}'].name')
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE="camera${i}"; fi
  hzn::log.debug "${FUNCNAME[0]}: set name to ${VALUE}"
  CAMERA=$(echo "${CAMERA}" | jq '.name="'${VALUE}'"')
  # set camera name for later use
  
  # width 
  VALUE=$(echo "${c}" | jq -r '.width')
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=$(motion::configuration | jq -r '.default.width'); fi
  CAMERA=$(echo "${CAMERA}" | jq '.width='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set width to ${VALUE}"
  
  # height 
  VALUE=$(echo "${c}" | jq -r '.height')
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=$(motion::configuration | jq -r '.default.height'); fi
  CAMERA=$(echo "${CAMERA}" | jq '.height='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set height to ${VALUE}"
  
  # framerate
  VALUE=$(echo "${c}" | jq -r '.framerate')
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=$(motion::configuration | jq -r '.default.framerate'); fi
  CAMERA=$(echo "${CAMERA}" | jq '.framerate='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set framerate to ${VALUE}"
  
  # event_gap
  VALUE=$(echo "${c}" | jq -r '.event_gap')
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=$(motion::configuration | jq -r '.default.event_gap'); fi
  CAMERA=$(echo "${CAMERA}" | jq '.event_gap='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set event_gap to ${VALUE}"
  
  # target_dir 
  VALUE=$(echo "${c}" | jq -r '.target_dir')
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=$(motion::configuration | jq -r '.motion.target_dir')/$(echo "${CAMERA}" | jq -r '.name'); fi
  CAMERA=$(echo "${CAMERA}" | jq '.target_dir="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set target_dir to ${VALUE}"
  # ensure directory exists
  if [ ! -d "${VALUE}" ]; then mkdir -p "${VALUE}"; fi
  
  # TYPE
  VALUE=$(jq -r '.cameras['${i}'].type' "${CONFIG_PATH}")
  case "${VALUE}" in
      local|netcam)
	## REAL CAMERA
        TYPE="${VALUE}"
        CAMERA=$(echo "${CAMERA}" | jq '.type="'${VALUE}'"')
        hzn::log.info "${FUNCNAME[0]}: camera: ${i}; type: ${TYPE}; number: ${CNUM}"
      ;;
      ftpd|mqtt)
	## VIRTUAL CAMERA
	local TYPE="${VALUE}"

	hzn::log.info "${FUNCNAME[0]}: camera: ${i}; type: ${VALUE}"
	CAMERA=$(echo "${CAMERA}" | jq '.type="'${VALUE}'"')

	# live
	VALUE=$(jq -r '.cameras['${i}'].netcam_url' "${CONFIG_PATH}")
	if [ "${VALUE}" != "null" ] || [ ! -z "${VALUE}" ]; then 
	  CAMERA=$(echo "${CAMERA}" | jq '.netcam_url="'${VALUE}'"')
	  hzn::log.debug "${FUNCNAME[0]}: set netcam_url:${VALUE}"
	  UP=$(jq -r '.cameras['${i}'].netcam_userpass' "${CONFIG_PATH}")
	  if [ "${UP}" != "null" ] && [ ! -z "${UP}" ]; then 
	    CAMERA=$(echo "${CAMERA}" | jq '.netcam_userpass="'${UP}'"')
	    hzn::log.debug "${FUNCNAME[0]}: set netcam_userpass: ${UP}"
	    VALUE="${VALUE%%//*}//${UP}@${VALUE##*://}"
	  fi
	fi
	hzn::log.debug "${FUNCNAME[0]}: set mjpeg_url to ${VALUE}"
	CAMERA=$(echo "${CAMERA}" | jq '.mjpeg_url="'${VALUE}'"')

	# icon
	VALUE=$(jq -r '.cameras['${i}'].icon' "${CONFIG_PATH}")
	if [ "${VALUE}" != "null" ] || [ ! -z "${VALUE}" ]; then 
	  hzn::log.debug "${FUNCNAME[0]}: set icon to ${VALUE}"
	  CAMERA=$(echo "${CAMERA}" | jq '.icon="'${VALUE}'"')
	fi

	# FTP share_dir
	if [ "${TYPE}" == 'ftpd' ]; then
          local sd=$(motion::configuration | jq -r '.share_dir')
	  local cn=$(echo "${CAMERA}" | jq -r '.name')

	  VALUE="${sd%/*}/ftp/${cn}"
	  hzn::log.debug "${FUNCNAME[0]}: set share_dir to ${VALUE}"
	  CAMERA=$(echo "${CAMERA}" | jq '.share_dir="'${VALUE}'"')
	fi
	return 0
      ;;
      *)
	## INVALID CAMERA
	hzn::log.error "${FUNCNAME[0]}: camera: ${i}; invalid camera type: ${VALUE}; skipping"
	return 1
      ;;
  esac
  
  ## CONFIGURE REAL CAMERA
  if (( CNUM / 10 )); then
      if (( CNUM % 10 == 0 )); then
        MOTION_COUNT=$((MOTION_COUNT + 1))
        MOTION_STREAM_PORT=$((MOTION_STREAM_PORT + MOTION_COUNT))
        CNUM=1
        CONF="${MOTION_CONF%%.*}.${MOTION_COUNT}.${MOTION_CONF##*.}"
        cp "${MOTION_CONF}" "${CONF}"
        sed -i 's|^camera|; camera|' "${CONF}"
        MOTION_CONF=${CONF}
        # get webcontrol_port (base)
        VALUE=$(jq -r ".webcontrol_port" "${CONFIG_PATH}")
        if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_CONTROL_PORT}; fi
        VALUE=$((VALUE + MOTION_COUNT))
        hzn::log.debug "${FUNCNAME[0]}: set webcontrol_port to ${VALUE}"
        sed -i "s/.*webcontrol_port\s[0-9]\+/webcontrol_port ${VALUE}/" "${MOTION_CONF}"
      else
        CNUM=$((CNUM+1))
      fi
  else
    if [ ${MOTION_COUNT} -eq 0 ]; then MOTION_COUNT=1; fi
    CNUM=$((CNUM+1))
  fi
  # create configuration file
  if [ ${MOTION_CONF%/*} != ${MOTION_CONF} ]; then 
    CAMERA_CONF="${MOTION_CONF%/*}/${CNAME}.conf"
  else
    CAMERA_CONF="${CNAME}.conf"
  fi

  # add to JSON
  CAMERA=$(echo "${CAMERA}" | jq '.server="'${MOTION_COUNT}'"')
  CAMERA=$(echo "${CAMERA}" | jq '.cnum='${CNUM})
  CAMERA=$(echo "${CAMERA}" | jq '.conf="'${CAMERA_CONF}'"')

  # calculate mjpeg_url for camera
  VALUE="http://127.0.0.1:${MOTION_STREAM_PORT}/${CNUM}"
  CAMERA=$(echo "${CAMERA}" | jq '.mjpeg_url="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set mjpeg_url to ${VALUE}"

  
    # rotate 
    VALUE=$(jq -r '.cameras['${i}'].rotate' "${CONFIG_PATH}")
    if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.rotate'); fi
    CAMERA=$(echo "${CAMERA}" | jq '.rotate='${VALUE})
    hzn::log.debug "${FUNCNAME[0]}: set rotate to ${VALUE}"
  
    # picture_quality 
    VALUE=$(jq -r '.cameras['${i}'].picture_quality' "${CONFIG_PATH}")
    if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.picture_quality'); fi
    CAMERA=$(echo "${CAMERA}" | jq '.picture_quality='${VALUE})
    hzn::log.debug "${FUNCNAME[0]}: set picture_quality to ${VALUE}"
  
    # stream_quality 
    VALUE=$(jq -r '.cameras['${i}'].stream_quality' "${CONFIG_PATH}")
    if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_quality'); fi
    CAMERA=$(echo "${CAMERA}" | jq '.stream_quality='${VALUE})
    hzn::log.debug "${FUNCNAME[0]}: set stream_quality to ${VALUE}"
  
    # threshold 
    VALUE=$(jq -r '.cameras['${i}'].threshold_percent' "${CONFIG_PATH}")
    if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ] || [ ${VALUE:-0} == 0 ]; then 
      VALUE=$(jq -r '.cameras['${i}'].threshold' "${CONFIG_PATH}")
      if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then 
        VALUE=$(echo "${MOTION}" | jq -r '.threshold_percent')
        if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ] || [ ${VALUE:-0} == 0 ]; then 
          VALUE=$(echo "${MOTION}" | jq -r '.threshold')
        else
          hzn::log.debug "${FUNCNAME[0]}: set threshold_percent to ${VALUE}"
	  CAMERA=$(echo "${CAMERA}" | jq '.threshold_percent='${VALUE})
          VALUE=$((VALUE * WIDTH * HEIGHT / 100))
        fi
      fi
    else
      # threshold as percent
      hzn::log.debug "${FUNCNAME[0]}: set threshold_percent to ${VALUE}"
      CAMERA=$(echo "${CAMERA}" | jq '.threshold_percent='${VALUE})
      VALUE=$((VALUE * WIDTH * HEIGHT / 100))
    fi
    hzn::log.debug "${FUNCNAME[0]}: set threshold to ${VALUE}"
    CAMERA=$(echo "${CAMERA}" | jq '.threshold='${VALUE})
  
    case ${TYPE} in
      netcam)
        # network camera
        VALUE=$(jq -r '.cameras['${i}'].netcam_url' "${CONFIG_PATH}")
        if [ ! -z "${VALUE:-}" ] && [ "${VALUE:-null}" != 'null' ]; then
          # network camera
          CAMERAS="${CAMERAS}"',"netcam_url":"'"${VALUE}"'"'
          hzn::log.debug "${FUNCNAME[0]}: set netcam_url to ${VALUE}"
          netcam_url=$(echo "${VALUE}" | sed 's/mjpeg:/http:/')
  
          # userpass 
          VALUE=$(jq -r '.cameras['${i}'].netcam_userpass' "${CONFIG_PATH}")
          if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_userpass'); fi
          CAMERAS="${CAMERAS}"',"netcam_userpass":"'"${VALUE}"'"'
          hzn::log.debug "${FUNCNAME[0]}: set netcam_userpass to ${VALUE}"
          netcam_userpass=${VALUE}
  
          # test netcam_url
          alive=$(curl -sL -w '%{http_code}' --connect-timeout 2 --retry-connrefused --retry 10 --retry-max-time 2 --max-time 15 -u ${netcam_userpass} ${netcam_url} -o /dev/null 2> /dev/null)
	  if [ "${alive:-000}" != '200' ]; then
	    hzn::log.notice "${FUNCNAME[0]}: Network camera at ${netcam_url}; userpass: ${netcam_userpass}; bad response: ${alive}"
	  else
	    hzn::log.info "${FUNCNAME[0]}: Network camera at ${netcam_url}; userpass: ${netcam_userpass}; good response: ${alive}"
	  fi
  
	  # keepalive 
	  VALUE=$(jq -r '.cameras['${i}'].keepalive' "${CONFIG_PATH}")
	  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_keepalive'); fi
	  CAMERAS="${CAMERAS}"',"keepalive":"'"${VALUE}"'"'
	  hzn::log.debug "${FUNCNAME[0]}: set netcam_keepalive to ${VALUE}"
	else
	  hzn::log.error "No netcam_url specified: ${VALUE}; skipping"
	fi
      ;;
    local)
      ## local camera
      VALUE=$(jq -r '.cameras['${i}'].device' "${CONFIG_PATH}")
      if [ "${VALUE:-null}" != 'null' ] ; then
        if [[ "${VALUE}" != /dev/video* ]]; then
          hzn::log.error "${FUNCNAME[0]}: camera: ${i}; invalid device: ${VALUE}"
          VALUE="/dev/video0"
        fi
      else
        VALUE="/dev/video0"
      fi
      CAMERA=$(echo "${CAMERA}" | jq '.videodevice='${VALUE})
      hzn::log.debug "${FUNCNAME[0]}: set videodevice to ${VALUE}"
      # palette
      VALUE=$(jq -r '.cameras['${i}'].palette' "${CONFIG_PATH}")
      if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.palette'); fi
      CAMERA=$(echo "${CAMERA}" | jq '.palette='${VALUE})
      hzn::log.debug "${FUNCNAME[0]}: set palette to ${VALUE}"
      ;;
    *)
      hzn::log.error "${FUNCNAME[0]}: Invalid camera type: ${TYPE}"
      ;;
  esac
}

function motion::configuration()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"

  jq -c '.' $(motion::configuration.file)
}

function motion::configuration.update.edit()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"
  local option=${1}
  local value=${2}

  sed -i "s/.*${option}.*/${option} ${value}/" ${MOTION_CONF}
}

function motion::configuration.update.camera()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"
  local cconf=${1}

  echo "camera ${cconf}" >> "${MOTION_CONF}"
}

function motion::configuration.update.authentication()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"

  local username=$(motion::configuration | jq -r '.motion.username')
  local password=$(motion::configuration | jq -r '.motion.password')

  if [ ! -z "${username:-}" ] && [ ! -z "${password:-}" ]; then
    hzn::log.debug "${FUNCNAME[0]}: username and password specified; username: ${username}; password: ${password}"
    motion::configuration.update.edit 'stream_authentication' "${username}:${password}"
    motion::configuration.update.edit 'webcontrol_authentication' "${username}:${password}"
    # turn off restriction to localhost-only
    motion::configuration.update.edit 'stream_localhost' 'off'
    motion::configuration.update.edit 'webcontrol_localhost' 'off'
  else
    hzn::log.warning "${FUNCNAME[0]}: username or password unspecified; username: ${username}; password: ${password}; localhost-only"
    # turn off restriction to localhost-only
    motion::configuration.update.edit 'stream_localhost' 'on'
    motion::configuration.update.edit 'webcontrol_localhost' 'on'
  fi
}

function motion::configuration.update.defaults()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"
  local defaults=$(motion::configuration | jq '.default')

  # set defaults for cameras
  motion::configuration.update.edit 'auto_brightness' $(echo "${defaults:-null}" | jq -r '.auto_brightness')
  motion::configuration.update.edit 'brightness' $(echo "${defaults:-null}" | jq -r '.brightness')
  motion::configuration.update.edit 'contrast' $(echo "${defaults:-null}" | jq -r '.contrast')
  motion::configuration.update.edit 'despeckle_filter' $(echo "${defaults:-null}" | jq -r '.despeckle_filter')
  motion::configuration.update.edit 'event_gap' $(echo "${defaults:-null}" | jq -r '.event_gap')
  motion::configuration.update.edit 'framerate' $(echo "${defaults:-null}" | jq -r '.framerate')
  motion::configuration.update.edit 'height' $(echo "${defaults:-null}" | jq -r '.height')
  motion::configuration.update.edit 'hue' $(echo "${defaults:-null}" | jq -r '.hue')
  motion::configuration.update.edit 'lightswitch' $(echo "${defaults:-null}" | jq -r '.lightswitch')
  motion::configuration.update.edit 'locate_motion_mode' $(echo "${defaults:-null}" | jq -r '.locate_motion_mode')
  motion::configuration.update.edit 'locate_motion_style' $(echo "${defaults:-null}" | jq -r '.locate_motion_style')
  motion::configuration.update.edit 'minimum_motion_frames' $(echo "${defaults:-null}" | jq -r '.minimum_motion_frames')
  motion::configuration.update.edit 'movie_output' $(echo "${defaults:-null}" | jq -r '.movie_output')
  motion::configuration.update.edit 'movie_output_motion' $(echo "${defaults:-null}" | jq -r '.movie_output_motion')
  motion::configuration.update.edit 'netcam_keepalive' $(echo "${defaults:-null}" | jq -r '.netcam_keepalive')
  motion::configuration.update.edit 'netcam_userpass' $(echo "${defaults:-null}" | jq -r '.netcam_userpass')
  motion::configuration.update.edit 'picture_output' $(echo "${defaults:-null}" | jq -r '.picture_output')
  motion::configuration.update.edit 'picture_quality' $(echo "${defaults:-null}" | jq -r '.picture_quality')
  motion::configuration.update.edit 'picture_type' $(echo "${defaults:-null}" | jq -r '.picture_type')
  motion::configuration.update.edit 'post_capture' $(echo "${defaults:-null}" | jq -r '.post_capture')
  motion::configuration.update.edit 'pre_capture' $(echo "${defaults:-null}" | jq -r '.pre_capture')
  motion::configuration.update.edit 'rotate' $(echo "${defaults:-null}" | jq -r '.rotate')
  motion::configuration.update.edit 'saturation' $(echo "${defaults:-null}" | jq -r '.saturation')
  motion::configuration.update.edit 'stream_quality' $(echo "${defaults:-null}" | jq -r '.stream_quality')
  motion::configuration.update.edit 'text_changes' $(echo "${defaults:-null}" | jq -r '.text_changes')
  motion::configuration.update.edit 'text_scale' $(echo "${defaults:-null}" | jq -r '.text_scale')
  motion::configuration.update.edit 'threshold' $(echo "${defaults:-null}" | jq -r '.threshold')
  motion::configuration.update.edit 'threshold_tune' $(echo "${defaults:-null}" | jq -r '.threshold_tune')
  motion::configuration.update.edit 'v4l2_palette' $(echo "${defaults:-null}" | jq -r '.v4l2_palette')
  motion::configuration.update.edit 'width' $(echo "${defaults:-null}" | jq -r '.width')
}

function motion::configuration.update.cameras()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"

  local ncamera=$(motion::configuration | jq '.cameras|length')

  for (( i=0; i < ncamera; i++ )); do
    local camera=$(echo "${config}" | jq '.cameras['${i}']')
    local cnum
    local cname

    if [ "${camera:-null}" = 'null' ]; then
      hzn::log.error "${FUNCNAME[0]}: invalid camera: ${i}"
      continue
    fi

    local ctype=$(echo "${camera}" | jq -r '.type')
    local cconf=$(echo "${camera}" | jq -r '.conf')

    case ${ctype:-null} in
      mqtt|ftp)
	hzn::log.debug "${FUNCNAME[0]}: virtual camera: skipping; camera ${i}:" $(echo "${camera}" | jq -c '.')
	continue
	;;
      local|netcam)
	hzn::log.debug "${FUNCNAME[0]}: motion camera: camera ${i}"
	;;
      *)
	hzn::log.error "${FUNCNAME[0]}: invalid camera; type: ${ctype}"
	continue
	;;
    esac

    if [ "${cconf:-null}" = 'null' ]; then
       hzn::log.error "${FUNCNAME[0]}: invalid configuration; skipping; file: ${cconf:-null}"
       continue
    fi

    ## create individual camera configuration file
    echo "camera_id" $(echo "${camera}" | jq -r '.cnum') > "${cconf}"
    echo "camera_name" $(echo "${camera}" | jq -r '.name') >> "${cconf}"
    echo "target_dir" $(echo "${camera}" | jq -r '.target_dir') >> "${cconf}"
    echo "width" $(echo "${camera}" | jq -r '.width') >> "${cconf}"
    echo "height" $(echo "${camera}" | jq -r '.height') >> "${cconf}"
    echo "framerate" $(echo "${camera}" | jq -r '.framerate') >> "${cconf}"
    echo "event_gap" $(echo "${camera}" | jq -r '.event_gap') >> "${cconf}"
    echo "rotate" $(echo "${camera}" | jq -r '.rotate') >> "${cconf}"
    echo "picture_quality" $(echo "${camera}" | jq -r '.picture_quality') >> "${cconf}"
    echo "stream_quality" $(echo "${camera}" | jq -r '.stream_quality') >> "${cconf}"
    echo "threshold" $(echo "${camera}" | jq -r '.threshold') >> "${cconf}"

    case ${ctype:-null} in
      netcam)
	echo "netcam_url $(echo "${camera}" | jq -r '.netcam_url')" >> "${cconf}"
	echo "netcam_userpass $(echo "${camera}" | jq -r '.netcam_userpass')" >> "${cconf}"
	echo "netcam_keepalive $(echo "${camera}" | jq -r '.netcam_keepalive')" >> "${cconf}"
	;;
      local)
	echo "videodevice $(echo "${camera}" | jq -r '.videodevice')" >> "${cconf}"
	echo "v4l2_palette $(echo "${camera}" | jq -r '.v4l2_palette')" >> "${cconf}"
	;;
    esac

    # add new camera configuration
    motion:configuration.update.camera ${cconf}

  done
}

function motion::configuration.update()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"

  local config=$(motion::configuration)

  cp -f ${MOTION_CONF%%.*}.default ${MOTION_CONF}

  motion::configuration.update.edit 'log_level' $(echo "${config:-null}" | jq -r '.motion.log_level')
  motion::configuration.update.edit 'log_type' $(echo "${config:-null}" | jq -r '.motion.log_type')
  motion::configuration.update.edit 'log_file' $(echo "${config:-null}" | jq -r '.motion.log_file')
  motion::configuration.update.edit 'target_dir' $(echo "${config:-null}" | jq -r '.motion.target_dir')

  motion::configuration.update.authentication

  motion::configuration.update.defaults

  motion::configuration.update.cameras
}

## MOTION
function motion::configure.motion()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"
  
  local JSON=${*}
  local MOTION='null'
  
  # set log_type
  VALUE=$(jq -r ".motion.log_type" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE="ALL"; fi
  MOTION=$(echo "${MOTION}" | jq '.log_type="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: ${FUNCNAME[0]}: set motion log_type to ${VALUE}"
  
  # set log_level
  VALUE=$(jq -r ".motion.log_level" "${CONFIG_PATH}")
  case ${VALUE} in
    emergency)
      VALUE=1
      ;;
    alert)
      VALUE=2
      ;;
    critical)
      VALUE=3
      ;;
    error)
      VALUE=4
      ;;
    warn)
      VALUE=5
      ;;
    info)
      VALUE=7
      ;;
    debug)
      VALUE=8
      ;;
    all)
      VALUE=9
      ;;
    *|notice)
      VALUE=6
      ;;
  esac
  MOTION=$(echo "${MOTION}" | jq '.log_level='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set motion log_level to ${VALUE}"
  
  # set log_file
  VALUE=$(jq -r ".motion.log_file" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_DEFAULT_LOG_FILE:-/tmp/motion.log}; fi
  MOTION=$(echo "${MOTION}" | jq '.log_file="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set motion log_file to ${VALUE}"
  
  # set webcontrol_port
  VALUE=$(jq -r ".motion.webcontrol_port" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_CONTROL_PORT}; fi
  MOTION=$(echo "${MOTION}" | jq '.webcontrol_port='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set webcontrol_port to ${VALUE}"
  
  # set stream_port
  VALUE=$(jq -r ".motion.stream_port" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_STREAM_PORT}; fi
  MOTION=$(echo "${MOTION}" | jq '.stream_port='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set stream_port to ${VALUE}"

  ## ALL CAMERAS SHARE THE SAME USERNAME:PASSWORD CREDENTIALS
  
  # set username and password
  USERNAME=$(jq -r ".motion.username" "${CONFIG_PATH}")
  PASSWORD=$(jq -r ".motion.password" "${CONFIG_PATH}")
  if [ "${USERNAME:-null}" != "null" ] && [ "${PASSWORD:-null}" != "null" ]; then
    MOTION=$(echo "${MOTION}" | jq '.username="'${USERNAME}'"')
    MOTION=$(echo "${MOTION}" | jq '.password="'${PASSWORD}'"')
    MOTION=$(echo "${MOTION}" | jq '.stream_auth_method="Basic"')
    hzn::log.debug "${FUNCNAME[0]}: set authentication to Basic for both stream and webcontrol"
  else
    MOTION=$(echo "${MOTION}" | jq '.stream_auth_method="localhost"')
    hzn::log.warning "${FUNCNAME[0]}: no username and password; stream and webcontrol limited to localhost only"
  fi

  # set auto_brightness
  VALUE=$(jq -r ".default.auto_brightness" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
  MOTION=$(echo "${MOTION}" | jq '.auto_brightness="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set auto_brightness to ${VALUE}"

  # set locate_motion_mode
  VALUE=$(jq -r ".default.locate_motion_mode" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE="off"; fi
  MOTION=$(echo "${MOTION}" | jq '.locate_motion_mode="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set locate_motion_mode to ${VALUE}"
  
  # set locate_motion_style (box, redbox, cross, redcross)
  VALUE=$(jq -r ".default.locate_motion_style" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE="box"; fi
  MOTION=$(echo "${MOTION}" | jq '.locate_motion_style="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set locate_motion_style to ${VALUE}"
  
  echo "${MOTION:-null}"
}

motion::configure.defaults()  
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"

  local defaults='null'
  local VALUE

  # set netcam_keepalive (off,force,on)
  VALUE=$(jq -r ".default.netcam_keepalive" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
  defaults=$(echo "${defaults}" | jq '.netcam_keepalive="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set netcam_keepalive to ${VALUE}"

  # set netcam_userpass 
  VALUE=$(jq -r ".default.netcam_userpass" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=""; fi
  defaults=$(echo "${defaults}" | jq '.netcam_userpass="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set netcam_userpass to ${VALUE}"
  
  # set v4l2_palette
  VALUE=$(jq -r ".default.palette" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_V4L2_PALETTE:-null}; fi
  defaults=$(echo "${defaults}" | jq '.v4l2_palette='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set v4l2_palette to ${VALUE}"
  
  # set pre_capture
  VALUE=$(jq -r ".default.pre_capture" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_PRE_CAPURE:-0}; fi
  defaults=$(echo "${defaults}" | jq '.pre_capture='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set pre_capture to ${VALUE}"
  
  # set post_capture
  VALUE=$(jq -r ".default.post_capture" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_POST_CAPTURE:-0}; fi
  defaults=$(echo "${defaults}" | jq '.post_capture='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set post_capture to ${VALUE}"
  
  # set event_gap
  VALUE=$(jq -r ".default.event_gap" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_EVENT_GAP:-5}; fi
  defaults=$(echo "${defaults}" | jq '.event_gap='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set event_gap to ${VALUE}"
  
  # set fov
  VALUE=$(jq -r ".default.fov" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_FOV:-60}; fi
  defaults=$(echo "${defaults}" | jq '.fov='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set fov to ${VALUE}"
  
  # set minimum_motion_frames
  VALUE=$(jq -r ".default.minimum_motion_frames" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_MINIMUM_defaults_FRAMES:-5}; fi
  defaults=$(echo "${defaults}" | jq '.minimum_motion_frames='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set minimum_motion_frames to ${VALUE}"
  
  # set picture_quality
  VALUE=$(jq -r ".default.picture_quality" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_PICTURE_QUALITY:-100}; fi
  defaults=$(echo "${defaults}" | jq '.picture_quality='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set picture_quality to ${VALUE}"

  # set stream_quality
  VALUE=$(jq -r ".default.stream_quality" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_STREAM_QUALITY:-100}; fi
  defaults=$(echo "${defaults}" | jq '.stream_quality='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set stream_quality to ${VALUE}"

  # set framerate
  VALUE=$(jq -r ".default.framerate" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_FRAMERATE:-5}; fi
  defaults=$(echo "${defaults}" | jq '.framerate='${VALUE})
  defaults="${defaults}"',"framerate":'"${VALUE}"
  hzn::log.debug "${FUNCNAME[0]}: set framerate to ${VALUE}"
  
  # set text_changes
  VALUE=$(jq -r ".default.text_changes" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_TEXT_CHANGES:-off}; fi
  defaults=$(echo "${defaults}" | jq '.text_changes="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set text_changes to ${VALUE}"
  
  # set text_scale
  VALUE=$(jq -r ".default.text_scale" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_TEXT_SCALE:-1}; fi
  defaults=$(echo "${defaults}" | jq '.text_scale='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set text_scale to ${VALUE}"
  
  # set despeckle_filter
  VALUE=$(jq -r ".default.despeckle_filter" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_DESPECKLE_FILTER:-EedDl}; fi
  defaults=$(echo "${defaults}" | jq '.despeckle_filter="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set despeckle_filter to ${VALUE}"
  
  # set brightness
  VALUE=$(jq -r ".default.brightness" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_BRIGHTNESS:-0}; fi
  defaults=$(echo "${defaults}" | jq '.brightness='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set brightness to ${VALUE}"
  
  # set contrast
  VALUE=$(jq -r ".default.contrast" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_CONTRAST:-0}; fi
  defaults=$(echo "${defaults}" | jq '.contrast='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set contrast to ${VALUE}"
  
  # set saturation
  VALUE=$(jq -r ".default.saturation" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_SATURATION:-0}; fi
  defaults=$(echo "${defaults}" | jq '.saturation='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set saturation to ${VALUE}"
  
  # set hue
  VALUE=$(jq -r ".default.hue" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_HUE:-0}; fi
  defaults=$(echo "${defaults}" | jq '.hue='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set hue to ${VALUE}"
  
  # set rotate
  VALUE=$(jq -r ".default.rotate" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_ROTATE:-0}; fi
  defaults=$(echo "${defaults}" | jq '.rotate='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set rotate to ${VALUE}"
  
  # set width
  VALUE=$(jq -r ".default.width" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_WIDTH:-640}; fi
  defaults=$(echo "${defaults}" | jq '.width='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set width to ${VALUE}"
  
  # set height
  VALUE=$(jq -r ".default.height" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_HEIGHT:-480}; fi
  defaults=$(echo "${defaults}" | jq '.height='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set height to ${VALUE}"
  
  # set threshold_percent
  VALUE=$(jq -r ".default.threshold_percent" "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ] || [ ${VALUE:-0} == 0 ]; then 
    VALUE=$(jq -r ".default.threshold" "${CONFIG_PATH}")
    if [ "${VALUE:-null}" = 'null' ]; then 
      VALUE=${defaults_DEFAULT_THRESHOLD_PERCENT:-10}
      defaults=$(echo "${defaults}" | jq '.threshold_percent="'${VALUE}'"')
      hzn::log.debug "DEFAULT threshold_percent to ${VALUE}"
    fi
  else
    defaults=$(echo "${defaults}" | jq '.threshold_percent="'${VALUE}'"')
    hzn::log.debug "${FUNCNAME[0]}: set threshold_percent to ${VALUE}"
  fi

  # set threshold
  VALUE=$(jq -r ".default.threshold" "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then
    local percent=$(echo "${defaults}" | jq -r '.threshold_percent');
    local width=$(echo "${defaults}" | jq -r '.width');
    local height=$(echo "${defaults}" | jq -r '.height');

    VALUE=$((percent * width * height / 100))
  fi
  defaults=$(echo "${defaults}" | jq '.threshold='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set threshold to ${VALUE}"
  
  # set threshold_tune (on/off)
  VALUE=$(jq -r ".default.threshold_tune" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${defaults_DEFAULT_THRESHOLD_TUNE:-on}; fi
  defaults=$(echo "${defaults}" | jq '.threshold_tune="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set threshold_tune to ${VALUE}"
  
  # set lightswitch
  VALUE=$(jq -r ".default.lightswitch" "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then VALUE=${defaults_DEFAULT_LIGHTSWITCH:-0}; fi
  defaults=$(echo "${defaults}" | jq '.lightswitch='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set lightswitch to ${VALUE}"
  
  # set interval for events
  VALUE=$(jq -r '.default.interval' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then VALUE=${defaults_DEFAULT_INTERVAL:-3600}; fi
  defaults=$(echo "${defaults}" | jq '.interval='${VALUE})
  hzn::log.debug "${FUNCNAME[0]}: set interval to ${VALUE}"

  # set post_pictures; enumerated [on,center,first,last,best,most]
  VALUE=$(jq -r '.default.post_pictures' "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE="best"; fi
  defaults=$(echo "${defaults}" | jq '.post_pictures="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set post_pictures to ${VALUE}"
  
  # set picture_output (on, off, first, best)
  case "${VALUE}" in
    'on'|'center'|'most')
      SPEC="on"
      hzn::log.debug "process all images; picture_output: ${SPEC}"
    ;;
    'best'|'first')
      SPEC="${VALUE}"
      hzn::log.debug "process one image; picture_output: ${SPEC}"
    ;;
    'off')
      SPEC="off"
      hzn::log.debug "process no image; picture_output: ${SPEC}"
    ;;
  esac

  # check specified for over-ride
  VALUE=$(jq -r ".default.picture_output" "${CONFIG_PATH}")
  if [ "${VALUE:-}" != 'null' ] && [ ! -z "${VALUE:-}" ]; then
    if [ "${VALUE}" != "${SPEC}" ]; then
      hzn::log.notice "picture_output; specified ${VALUE} does not match expected: ${SPEC}"
    else
      hzn::log.debug "picture_output; specified ${VALUE} matches expected: ${SPEC}"
    fi
  else
    VALUE="${SPEC}"
    hzn::log.debug "picture_output; unspecified; using: ${VALUE}"
  fi
  defaults=$(echo "${defaults}" | jq '.picture_output="'${VALUE}'"')
  hzn::log.info "${FUNCNAME[0]}: set picture_output to ${VALUE}"
  local PICTURE_OUTPUT=${VALUE}

  # set movie_output (on, off)
  if [ "${PICTURE_OUTPUT:-}" = 'best' ] || [ "${PICTURE_OUTPUT:-}" = 'first' ]; then
    hzn::log.notice "${FUNCNAME[0]}: picture output: ${PICTURE_OUTPUT}; setting movie_output: on"
    VALUE='on'
  else
    VALUE=$(jq -r '.default.movie_output' "${CONFIG_PATH}")
    if [ "${VALUE:-null}" = 'null' ]; then 
      hzn::log.debug "${FUNCNAME[0]}: movie_output unspecified; defaulting: off"
      VALUE="off"
    else
      case ${VALUE} in
        '3gp')
          hzn::log.notice "${FUNCNAME[0]}: movie_output: video type ${VALUE}; ensure camera type: ftpd"
          defaults_VIDEO_CODEC="${VALUE}"
          VALUE='off'
        ;;
        'on'|'mp4')
          hzn::log.debug "${FUNCNAME[0]}: movie_output: supported codec: ${VALUE}; - MPEG-4 Part 14 H264 encoding"
          defaults_VIDEO_CODEC="${VALUE}"
          VALUE='on'
        ;;
        'mpeg4'|'swf'|'flv'|'ffv1'|'mov'|'mkv'|'hevc')
          hzn::log.warning "${FUNCNAME[0]}: movie_output: unsupported option: ${VALUE}"
          defaults_VIDEO_CODEC="${VALUE}"
          VALUE='on'
        ;;
        'off')
          hzn::log.debug "${FUNCNAME[0]}: movie_output: off defined"
          defaults_VIDEO_CODEC=
          VALUE='off'
        ;;
        '*')
          hzn::log.error "${FUNCNAME[0]}: movie_output: unknown option for movie_output: ${VALUE}"
          defaults_VIDEO_CODEC=
          VALUE='off'
        ;;
      esac
    fi
  fi
  defaults=$(echo "${defaults}" | jq '.movie_output="'${VALUE}'"')
  hzn::log.info "${FUNCNAME[0]}: set movie_output to ${VALUE}"
  if [ "${VALUE:-null}" != 'null' ]; then
    defaults=$(echo "${defaults}" | jq '.movie_output_motion="'${VALUE}'"')
    hzn::log.info "${FUNCNAME[0]}: set movie_output_motion to ${VALUE}"
  fi
  
  # set picture_type (jpeg, ppm)
  VALUE=$(jq -r ".default.picture_type" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE="jpeg"; fi
  defaults=$(echo "${defaults}" | jq '.picture_type="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set picture_type to ${VALUE}"

  echo "${defaults:-null}"
}

## MQTT
function motion::configure.mqtt()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"  

  local MQTT='{}'
  local VALUE

  # local MQTT server (hassio addon)
  VALUE=$(jq -r ".mqtt.host" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE="mqtt"; fi
  hzn::log.info "Using MQTT at ${VALUE}"
  MQTT=$(echo "${MQTT}" | jq -c '.host="'${VALUE}'"')
  # username
  VALUE=$(jq -r ".mqtt.username" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=""; fi
  hzn::log.info "Using MQTT username: ${VALUE}"
  MQTT=$(echo "${MQTT}" | jq -c '.username="'${VALUE}'"')
  # password
  VALUE=$(jq -r ".mqtt.password" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=""; fi
  hzn::log.info "Using MQTT password: ${VALUE}"
  MQTT=$(echo "${MQTT}" | jq -c '.password="'${VALUE}'"')
  # port
  VALUE=$(jq -r ".mqtt.port" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=1883; fi
  hzn::log.info "Using MQTT port: ${VALUE}"
  MQTT=$(echo "${MQTT}" | jq -c '.port='${VALUE})

  echo "${MQTT:-null}"
}

function motion::configure.system()
{
  hzn::log.trace "${FUNCNAME[0]}" "${*}"

  local ipaddrs=$(ip addr | egrep -A2 'UP' | egrep 'inet ' | awk '{ print $2 }' | awk -F/ 'BEGIN { x=0; printf("["); } { if (x++>0) printf(",\"%s\"", $1); else printf("\"%s\"",$1) } END { printf("]"); }')
  local config='{"ipaddrs":'${ipaddrs:-null}',"hostname":"'$(hostname)'","arch":"'$(arch)'","timestamp":"'$(date -u +%FT%TZ)'","date":'$(date -u +%s)'}'
  local timezone=$(bashio::config 'timezone')
  local result

  if [ -z "${timezone:-}" ] || [ "${timezone:-null}" == "null" ] && [ ! -s "/usr/share/zoneinfo/${timezone:-null}" ]; then
    hzn::log.warning "${FUNCNAME[0]}: timezone invalid; defaulting to GMT; timezone: ${timezone:-unspecified}"
    timezone="GMT"
  fi
  cp /usr/share/zoneinfo/${timezone} /etc/localtime
  echo "${timezone}" > /etc/timezone
  hzn::log.info "${FUNCNAME[0]}: timezone: ${timezone}"
  config=$(echo "${config:-null}" | jq '.timezone="'${timezone}'"')
  echo "${config:-null}"
}

function motion::configure()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"

  local VALUE=''
  local JSON=$(motion::configure.system)

  # shared directory for results (not images and JSON)
  VALUE=$(jq -r ".share_dir" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_DEFAULT_SHARE_DIR:-/share/$(echo "${JSON}" | jq -r '.group')}; fi
  JSON=$(echo "${JSON}" | jq -c '.share_dir="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set share_dir to ${VALUE}"

  # device group
  VALUE=$(jq -r ".motion.group" "${CONFIG_PATH}")
  if [ -z "${VALUE}" ] || [ "${VALUE}" = 'null' ]; then 
    VALUE="motion"
    hzn::log.warning "${FUNCNAME[0]}: group unspecifieid; setting group: ${VALUE}"
  fi
  JSON=$(echo "${JSON}" | jq -c '.group="'${VALUE}'"')
  hzn::log.info "${FUNCNAME[0]}: MOTION_GROUP: ${VALUE}"

  # device name
  VALUE=$(jq -r ".motion.device" "${CONFIG_PATH}")
  if [ -z "${VALUE}" ] || [ "${VALUE}" = 'null' ]; then 
    VALUE="$(hostname -s)"
    hzn::log.warning "${FUNCNAME[0]}: device unspecifieid; setting device: ${VALUE}"
  fi
  JSON=$(echo "${JSON}" | jq -c '.device="'${VALUE}'"')
  hzn::log.info "${FUNCNAME[0]}: MOTION_DEVICE: ${VALUE}"

  # client
  VALUE=$(jq -r ".motion.client" "${CONFIG_PATH}")
  if [ -z "${VALUE}" ] || [ "${VALUE}" = 'null' ]; then 
    VALUE="+"
    hzn::log.warning "${FUNCNAME[0]}: client unspecifieid; setting client: ${VALUE}"
  fi
  JSON=$(echo "${JSON}" | jq -c '.client="'${VALUE}'"')
  hzn::log.info "${FUNCNAME[0]}: MOTION_CLIENT: ${VALUE}"

  # base target_dir
  VALUE=$(jq -r ".motion.target_dir" "${CONFIG_PATH}")
  if [ "${VALUE}" = 'null' ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_APACHE_HTDOCS}/cameras"; fi
  JSON=$(echo "${JSON}" | jq '.target_dir="'${VALUE}'"')
  hzn::log.debug "${FUNCNAME[0]}: set target_dir to ${VALUE}"

  ## MQTT
  VALUE=$(motion::configure.mqtt ${JSON})
  hzn::log.debug "${FUNCNAME[0]}: set mqtt to ${VALUE}"
  JSON=$(echo "${JSON}" | jq -c '.mqtt='${VALUE})
  
  ## MOTION
  VALUE=$(motion::configure.motion ${JSON})
  hzn::log.debug "${FUNCNAME[0]}: set motion to ${VALUE}"
  JSON=$(echo "${JSON}" | jq -c '.motion='"${VALUE}")

  ## CAMERA DEFAULTS
  VALUE=$(motion::configure.defaults ${JSON})
  hzn::log.debug "${FUNCNAME[0]}: set defaults to ${VALUE}"
  JSON=$(echo "${JSON}" | jq -c '.default='"${VALUE}")
  
  ## CAMERAS
  VALUE=$(motion::configure.cameras ${JSON})
  hzn::log.debug "${FUNCNAME[0]}: set cameras to ${VALUE}"
  JSON=$(echo "${JSON}" | jq -c '.cameras='"${VALUE}")
  
  ### update configuration file
  echo "${JSON}" | jq -c '.' > "$(motion::configuration.file)" || hzn::log.error "${FUNCNAME[0]}: INVALID CONFIGURATION; metadata: ${JSON}"
}

# poll forever
function motion::poll()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"
  local PID_FILES=(${*})

  if [ ${#PID_FILES[@]} -le 0 ]; then
    hzn::log.info "${FUNCNAME[0]}: ZERO motion daemons"
    hzn::log.info "${FUNCNAME[0]}: STARTING APACHE (foreground); ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}"
    motion::apache.start_foreground ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}
  else 
    hzn::log.info "${FUNCNAME[0]}: ${#PID_FILES[@]} motion daemons"
    hzn::log.info "${FUNCNAME[0]}: STARTING APACHE (background); ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}"
    motion::apache.start_background ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}
  
    ## monitor motion daemons
    hzn::log.info "${FUNCNAME[0]}: STARTING MOTION WATCHDOG; ${PID_FILES[@]}"
    ## forever
    while [ ${#PID_FILES[@]} -gt 0 ]; do
      i=0; for PID_FILE in ${PID_FILES[@]}; do
        if [ ! -z "${PID_FILE:-}" ] && [ -s "${PID_FILE}" ]; then
          pid=$(cat ${PID_FILE})
          if [ "${pid:-null}" != 'null' ]; then
            found=$(ps alxwww | grep 'motion -b' | awk '{ print $1 }' | egrep ${pid})
            if [ -z "${found:-}" ]; then
              hzn::log.notice "${FUNCNAME[0]}: Daemon with PID: ${pid} is not found; restarting"
              if [ ${i} -gt 0 ]; then
                CONF="${MOTION_CONF%%.*}.${i}.${MOTION_CONF##*.}"
              else
                CONF="${MOTION_CONF%%.*}.${MOTION_CONF##*.}"
              fi
              motion -b -c "${CONF}" -p ${PID_FILE}
            else
              hzn::log.info "${FUNCNAME[0]}: motion daemon running with PID: ${pid}"
            fi
          else
            hzn::log.error "${FUNCNAME[0]}: PID file contents invalid: ${PID_FILE}"
          fi
        else
          hzn::log.error "${FUNCNAME[0]}: No motion daemon PID file: ${PID_FILE}"
        fi
        i=$((i+1))
      done
      hzn::log.info "${FUNCNAME[0]}: watchdog sleeping..."
      sleep ${MOTION_WATCHDOG_INTERVAL:-3600}
    done
  fi
}

function motion::start()
{
  hzn::log.trace "${FUNCNAME[0]} ${*}"

  # configure motion
  motion::configure

  # update motion configuration
  motion::configuration.update

  # publish configuration
  hzn::log.info "${FUNCNAME[0]}: publishing on MQTT; topic: $(motion::configuration.group)/$(motion::configuration.device)/start"
  motion::mqtt.pub -r -q 2 -t "$(motion::configuration.group)/$(motion::configuration.device)/start" -f "$(motion::configuration.file)"
  
  # configure inotify() for any 'ftpd' cameras
  hzn::log.info "${FUNCNAME[0]}: settting up inotifywait for FTPD cameras"
  ftp_notifywait.sh "$(motion::configuration.file)"
  
  local PID_FILES=()
  local MOTION_COUNT=$(motion::configuration | jq -r '.motion.count')
  local CONF="${MOTION_CONF%%.*}.${MOTION_CONF##*.}"

  # process all motion configurations
  for (( i = 1; i <= MOTION_COUNT;  i++)); do
    # test for configuration file
    if [ ! -s "${CONF}" ]; then
      hzn::log.error "${FUNCNAME[0]}: missing configuration for daemon ${i} with ${CONF}"
      continue
    fi
      hzn::log.debug "${FUNCNAME[0]}: Starting motion configuration ${i}: ${CONF}"
      PID_FILE="${MOTION_CONF%%.*}.${i}.pid"
      motion -b -c "${CONF}" -p ${PID_FILE}
      PID_FILES=(${PID_FILES[@]} ${PID_FILE})
      # get next configuration
      CONF="${MOTION_CONF%%.*}.${i}.${MOTION_CONF##*.}"
  done

  motion::poll ${PID_FILES[@]}
}

###
### MAIN
###

# hzn
if [ -z "${SERVICE_LABEL}" ]; then 
  SERVICE_LABEL=${T##*/} export SERVICE_LABEL=${SERVICE_LABEL%%.sh*}
  hzn::log.warning "SERVICE_LABEL environment variable undefined; using ${SERVICE_LABEL}"
fi

if [ -z "${SERVICE_PORT}" ]; then 
  export SERVICE_PORT='8082'
  hzn::log.warning "SERVICE_PORT environment variable undefined; using ${SERVICE_PORT}"
fi

# defaults
if [ -z "${MQTT_HOST:-}" ]; then export MQTT_HOST='mqtt'; fi
if [ -z "${MQTT_PORT:-}" ]; then export MQTT_PORT=1883; fi
if [ -z "${MOTION_CONTROL_PORT:-}" ]; then export MOTION_CONTROL_PORT=8080; fi
if [ -z "${MOTION_STREAM_PORT:-}" ]; then export MOTION_STREAM_PORT=8090; fi

# motion command
if [ -z "$(command -v motion)" ]; then
  hzn::log.error "${0}: Command not installed; command: motion"
  exit 1
fi

# default configuration
MOTION_CONF=${MOTION_CONF:-'/etc/motion/motion.conf'}
if [ ! -s ${MOTION_CONF%%.*}.default ]; then
  hzn::log.error "${0}: Default configuration not found; file:: ${MOTION_CONF%%.*}.default"
  exit 1
fi

## apache

if [ -z "${APACHE_PID_FILE:-}" ]; then export APACHE_PID_FILE="/var/run/apache2.pid"; fi
if [ -z "${APACHE_RUN_DIR:-}" ]; then export APACHE_RUN_DIR="/var/run/apache2"; fi
if [ -z "${APACHE_ADMIN:-}" ]; then export APACHE_ADMIN="${HZN_ORG_ID:-root@localhost}"; fi

if [ ! -s "${MOTION_APACHE_CONF}" ]; then
  hzn::log.error "Missing Apache configuration"
  exit 1
fi
if [ -z "${MOTION_APACHE_HOST:-}" ]; then
  hzn::log.error "Missing Apache ServerName"
  exit 1
fi
if [ -z "${MOTION_APACHE_ADMIN:-}" ]; then
  hzn::log.error "Missing Apache ServerAdmin"
  exit 1
fi
if [ -z "${MOTION_APACHE_HTDOCS:-}" ]; then
  hzn::log.error "Missing Apache HTML documents directory"
  exit 1
fi

# TMPDIR
if [ -d '/tmpfs' ]; then export TMPDIR=${TMPDIR:-/tmpfs}; else export TMPDIR=${TMPDIR:-/tmp}; fi

hzn::log.notice "Starting ${0} ${*}: ${SERVICE_LABEL:-null}; version: ${SERVICE_VERSION:-null}"

motion::start ${*}

exit 1
