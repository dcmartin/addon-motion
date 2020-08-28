#!/usr/bin/with-contenv bashio

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
  export MOTION_JSON_FILE=$(motion::config.file)
  export MOTION_SHARE_DIR=$(motion::config.share_dir)

  # pass environment
  echo 'PassEnv MOTION_JSON_FILE' >> "${conf}"
  echo 'PassEnv MOTION_SHARE_DIR' >> "${conf}"

  # make /run/apache2 for PID file
  mkdir -p /run/apache2

  # start HTTP daemon
  hzn::log.info "Starting Apache: ${conf} ${host} ${port}"

  if [ "${foreground:-false}" = 'true' ]; then
    MOTION_JSON_FILE=$(motion::config.file) httpd -E /tmp/hzn::log -e debug -f "${MOTION_APACHE_CONF}" -DFOREGROUND
  else
    MOTION_JSON_FILE=$(motion::config.file) httpd -E /tmp/hzn::log -e debug -f "${MOTION_APACHE_CONF}"
  fi
}

## CONFIG

function motion::config.process.camera.ftpd()
{
  hzn::log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

function motion::config.process.camera.mjpeg()
{
  hzn::log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

function motion::config.process.camera.http()
{
  hzn::log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

function motion::config.process.camera.v4l2()
{
  hzn::log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json='null'
  local value
  
  # set v4l2_pallette
  value=$(echo "${config:-null}" | jq -r ".v4l2_pallette")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=15; fi
  json=$(echo "${json}" | jq '.v4l2_palette='${value})
  sed -i "s/.*v4l2_palette\s[0-9]\+/v4l2_palette ${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"v4l2_palette":'"${value}"
  hzn::log.debug "Set v4l2_palette to ${value}"
  
  # set brightness
  value=$(echo "${config:-null}" | jq -r ".v4l2_brightness")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/brightness=[0-9]\+/brightness=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"brightness":'"${value}"
  hzn::log.debug "Set brightness to ${value}"
  
  # set contrast
  value=$(jq -r ".v4l2_contrast" "${CONFIG_PATH}")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/contrast=[0-9]\+/contrast=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"contrast":'"${value}"
  hzn::log.debug "Set contrast to ${value}"
  
  # set saturation
  value=$(jq -r ".v4l2_saturation" "${CONFIG_PATH}")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/saturation=[0-9]\+/saturation=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"saturation":'"${value}"
  hzn::log.debug "Set saturation to ${value}"
  
  # set hue
  value=$(jq -r ".v4l2_hue" "${CONFIG_PATH}")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=0; fi
  sed -i "s/hue=[0-9]\+/hue=${value}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"hue":'"${value}"
  hzn::log.debug "Set hue to ${value}"

  echo "${json:-null}"
}

## cameras
function motion::config.process.cameras()
{
  hzn::log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

## defaults
function motion::process.config.defaults()
{
  hzn::log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local json

  echo "${json:-null}"
}

## mqtt
function motion::config.process.mqtt()
{
  hzn::log.debug "${FUNCNAME[0]}" "${*}"

  local config="${*}"
  local result=
  local value
  local json

  # local json server (hassio addon)
  value=$(echo "${config}" | jq -r ".host")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value="core-mosquitto"; fi
  hzn::log.debug "Using MQTT host: ${value}"
  json='{"host":"'"${value}"'"'

  # username
  value=$(echo "${config}" | jq -r ".username")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=""; fi
  hzn::log.debug "Using MQTT username: ${value}"
  json="${json}"',"username":"'"${value}"'"'

  # password
  value=$(echo "${config}" | jq -r ".password")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=""; fi
  hzn::log.debug "Using MQTT password: ${value}"
  json="${json}"',"password":"'"${value}"'"'

  # port
  value=$(echo "${config}" | jq -r ".port")
  if [ "${value}" == "null" ] || [ -z "${value}" ]; then value=1883; fi
  hzn::log.debug "Using MQTT port: ${value}"
  json="${json}"',"port":'"${value}"'}'

  echo "${json:-null}"
}

## process configuration 
motion::config.process.system()
{
  hzn::log.debug "${FUNCNAME[0]}" "${*}"

  local timestamp=$(date -u +%FT%TZ)
  local hostname="$(hostname)"
  local json='{"ipaddr":"'$(hostname -i)'","hostname":"'${hostname}'","arch":"'$(arch)'","date":'$(date -u +%s)',"timestamp":"'${timestamp}'"}'

  echo "${json:-null}"
}

## process configuration 
motion::config.process()
{
  hzn::log.debug "${FUNCNAME[0]}" "${*}"

  local path=${1}
  local json

  json=$(echo "${json:-null}" | jq '.+='$(motion::config.process.system ${path}))
  json=$(echo "${json:-null}" | jq '.+='$(motion::config.process.mqtt ${path}))
  json=$(echo "${json:-null}" | jq '.+='$(motion::process.config.defaults ${path}))
  json=$(echo "${json:-null}" | jq '.+='$(motion::config.process.cameras ${path}))

  echo "${json:-null}"
}

function motion::start()
{
  hzn::log.debug "${FUNCNAME[0]}" "${*}"

  local path=${1}
  local json

  json=$(motion::config.process ${path})
  
  echo "${json:-null}"
}

###
### MAIN
###

## initiate logging
export MOTION_LOG_LEVEL="${1}"

###
### PRE-FLIGHT
###

## motion command
MOTION_CMD=$(command -v motion)
if [ ! -s "${MOTION_CMD}" ]; then
  hzn::log.error "Motion not installed; command: ${MOTION_CMD}"
  exit 1
fi

hzn::log.notice "Reseting configuration to default: ${MOTION_CONF}"
cp -f ${MOTION_CONF%%.*}.default ${MOTION_CONF}

## defaults
if [ -z "${MOTION_CONTROL_PORT:-}" ]; then MOTION_CONTROL_PORT=8080; fi
if [ -z "${MOTION_STREAM_PORT:-}" ]; then MOTION_STREAM_PORT=8090; fi

## apache
if [ ! -s "${MOTION_APACHE_CONF}" ]; then
  hzn::log.error "Missing Apache configuration"
  exit 1
fi
if [ -z "${MOTION_APACHE_HOST:-}" ]; then
  hzn::log.error "Missing Apache ServerName"
  exit 1
fi
if [ -z "${MOTION_APACHE_HOST:-}" ]; then
  hzn::log.error "Missing Apache ServerAdmin"
  exit 1
fi
if [ -z "${MOTION_APACHE_HTDOCS:-}" ]; then
  hzn::log.error "Missing Apache HTML documents directory"
  exit 1
fi

## build internal configuration
JSON='{"config_path":"'"${CONFIG_PATH}"'","ipaddr":"'$(hostname -i)'","hostname":"'"$(hostname)"'","arch":"'$(arch)'","date":'$(date -u +%s)

# device name
VALUE=$(jq -r ".device" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
  VALUE="$(hostname -s)"
  hzn::log.warn "device unspecifieid; setting device: ${VALUE}"
fi
JSON="${JSON}"',"device":"'"${VALUE}"'"'
hzn::log.info "MOTION_DEVICE: ${VALUE}"
MOTION_DEVICE="${VALUE}"

# device group
VALUE=$(jq -r ".group" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
  VALUE="motion"
  hzn::log.warn "group unspecifieid; setting group: ${VALUE}"
fi
JSON="${JSON}"',"group":"'"${VALUE}"'"'
hzn::log.info "MOTION_GROUP: ${VALUE}"
MOTION_GROUP="${VALUE}"

# client
VALUE=$(jq -r ".client" "${CONFIG_PATH}")
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
  VALUE="+"
  hzn::log.warn "client unspecifieid; setting client: ${VALUE}"
fi
JSON="${JSON}"',"client":"'"${VALUE}"'"'
hzn::log.info "MOTION_CLIENT: ${VALUE}"
MOTION_CLIENT="${VALUE}"

## time zone
VALUE=$(jq -r ".timezone" "${CONFIG_PATH}")
# Set the correct timezone
if [ -z "${VALUE}" ] || [ "${VALUE}" == "null" ]; then 
  VALUE="GMT"
  hzn::log.warn "timezone unspecified; defaulting to ${VALUE}"
else
  hzn::log.info "TIMEZONE: ${VALUE}"
fi
if [ -s "/usr/share/zoneinfo/${VALUE}" ]; then
  cp /usr/share/zoneinfo/${VALUE} /etc/localtime
  echo "${VALUE}" > /etc/timezone
else
  hzn::log.error "No known timezone: ${VALUE}"
fi
JSON="${JSON}"',"timezone":"'"${VALUE}"'"'

# set unit_system for events
VALUE=$(jq -r '.unit_system' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="imperial"; fi
hzn::log.info "Set unit_system to ${VALUE}"
JSON="${JSON}"',"unit_system":"'"${VALUE}"'"'

# set latitude for events
VALUE=$(jq -r '.latitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
hzn::log.info "Set latitude to ${VALUE}"
JSON="${JSON}"',"latitude":'"${VALUE}"

# set longitude for events
VALUE=$(jq -r '.longitude' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0.0; fi
hzn::log.info "Set longitude to ${VALUE}"
JSON="${JSON}"',"longitude":'"${VALUE}"

# set elevation for events
VALUE=$(jq -r '.elevation' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
hzn::log.info "Set elevation to ${VALUE}"
JSON="${JSON}"',"elevation":'"${VALUE}"

##
## MQTT
##

# local MQTT server (hassio addon)
VALUE=$(jq -r ".mqtt.host" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="mqtt"; fi
hzn::log.info "Using MQTT at ${VALUE}"
MQTT='{"host":"'"${VALUE}"'"'
# username
VALUE=$(jq -r ".mqtt.username" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
hzn::log.info "Using MQTT username: ${VALUE}"
MQTT="${MQTT}"',"username":"'"${VALUE}"'"'
# password
VALUE=$(jq -r ".mqtt.password" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
hzn::log.info "Using MQTT password: ${VALUE}"
MQTT="${MQTT}"',"password":"'"${VALUE}"'"'
# port
VALUE=$(jq -r ".mqtt.port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1883; fi
hzn::log.info "Using MQTT port: ${VALUE}"
MQTT="${MQTT}"',"port":'"${VALUE}"'}'

## finish
JSON="${JSON}"',"mqtt":'"${MQTT}"

###
## WATSON
###

if [ -n "${WATSON:-}" ]; then
  JSON="${JSON}"',"watson":'"${WATSON}"
else
  hzn::log.debug "Watson Visual Recognition not specified"
  JSON="${JSON}"',"watson":null'
fi

###
## DIGITS
###

if [ -n "${DIGITS:-}" ]; then
  JSON="${JSON}"',"digits":'"${DIGITS}"
else
  hzn::log.debug "DIGITS not specified"
  JSON="${JSON}"',"digits":null'
fi

## MOTION

MOTION='{'

# set log_type (FIRST ENTRY)
VALUE=$(jq -r ".log_motion_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="ALL"; fi
sed -i "s|.*log_type.*|log_type ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"'"log_type":"'"${VALUE}"'"'
hzn::log.debug "Set hzn::log_type to ${VALUE}"

# set log_level
VALUE=$(jq -r ".log_motion_level" "${CONFIG_PATH}")
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
sed -i "s/.*log_level.*/log_level ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_level":'"${VALUE}"
hzn::log.debug "Set hzn::log_level to ${VALUE}"

# set log_file
VALUE=$(jq -r ".log_file" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/tmp/hzn::log"; fi
sed -i "s|.*log_file.*|log_file ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"',"log_file":"'"${VALUE}"'"'
hzn::log.debug "Set log_file to ${VALUE}"

# shared directory for results (not images and JSON)
VALUE=$(jq -r ".share_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="/share/${MOTION_GROUP}"; fi
hzn::log.debug "Set share_dir to ${VALUE}"
JSON="${JSON}"',"share_dir":"'"${VALUE}"'"'
MOTION_SHARE_DIR="${VALUE}"

# base target_dir
VALUE=$(jq -r ".default.target_dir" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_APACHE_HTDOCS}/cameras"; fi
hzn::log.debug "Set target_dir to ${VALUE}"
sed -i "s|.*target_dir.*|target_dir ${VALUE}|" "${MOTION_CONF}"
MOTION="${MOTION}"',"target_dir":"'"${VALUE}"'"'
MOTION_TARGET_DIR="${VALUE}"

# set auto_brightness
VALUE=$(jq -r ".default.auto_brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/.*auto_brightness.*/auto_brightness ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"auto_brightness":"'"${VALUE}"'"'
hzn::log.debug "Set auto_brightness to ${VALUE}"

# set locate_motion_mode
VALUE=$(jq -r ".default.locate_motion_mode" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="off"; fi
sed -i "s/.*locate_motion_mode.*/locate_motion_mode ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_mode":"'"${VALUE}"'"'
hzn::log.debug "Set locate_motion_mode to ${VALUE}"

# set locate_motion_style (box, redbox, cross, redcross)
VALUE=$(jq -r ".default.locate_motion_style" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="box"; fi
sed -i "s/.*locate_motion_style.*/locate_motion_style ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"locate_motion_style":"'"${VALUE}"'"'
hzn::log.debug "Set locate_motion_style to ${VALUE}"

# set post_pictures; enumerated [on,center,first,last,best,most]
VALUE=$(jq -r '.default.post_pictures' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="center"; fi
hzn::log.debug "Set post_pictures to ${VALUE}"
MOTION="${MOTION}"',"post_pictures":"'"${VALUE}"'"'
export MOTION_POST_PICTURES="${VALUE}"

# set picture_output (on, off, first, best)
case "${MOTION_POST_PICTURES}" in
  'on'|'center'|'most')
    SPEC="on"
    hzn::log.debug "process all images; picture_output: ${SPEC}"
  ;;
  'best'|'first')
    SPEC="${MOTION_POST_PICTURES}"
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
sed -i "s/^picture_output .*/picture_output ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_output":"'"${VALUE}"'"'
hzn::log.info "Set picture_output to ${VALUE}"
PICTURE_OUTPUT=${VALUE}

# set movie_output (on, off)
if [ "${PICTURE_OUTPUT:-}" = 'best' ] || [ "${PICTURE_OUTPUT:-}" = 'first' ]; then
  hzn::log.notice "Picture output: ${PICTURE_OUTPUT}; setting movie_output: on"
  VALUE='on'
else
  VALUE=$(jq -r '.default.movie_output' "${CONFIG_PATH}")
  if [ "${VALUE:-null}" = 'null' ]; then 
    hzn::log.debug "movie_output unspecified; defaulting: off"
    VALUE="off"
  else
    case ${VALUE} in
      '3gp')
        hzn::log.notice "movie_output: video type ${VALUE}; ensure camera type: ftpd"
        MOTION_VIDEO_CODEC="${VALUE}"
        VALUE='off'
      ;;
      'on'|'mp4')
        hzn::log.debug "movie_output: supported codec: ${VALUE}; - MPEG-4 Part 14 H264 encoding"
        MOTION_VIDEO_CODEC="${VALUE}"
        VALUE='on'
      ;;
      'mpeg4'|'swf'|'flv'|'ffv1'|'mov'|'mkv'|'hevc')
        hzn::log.warn "movie_output: unsupported option: ${VALUE}"
        MOTION_VIDEO_CODEC="${VALUE}"
        VALUE='on'
      ;;
      'off')
        hzn::log.debug "movie_output: off defined"
        MOTION_VIDEO_CODEC=
        VALUE='off'
      ;;
      '*')
        hzn::log.error "movie_output: unknown option for movie_output: ${VALUE}"
        MOTION_VIDEO_CODEC=
        VALUE='off'
      ;;
    esac
  fi
fi
sed -i "s/^movie_output .*/movie_output ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"movie_output":"'"${VALUE}"'"'
hzn::log.info "Set movie_output to ${VALUE}"
if [ "${VALUE:-null}" != 'null' ]; then
  sed -i "s/^movie_output_motion .*/movie_output_motion ${VALUE}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"movie_output_motion":"'"${VALUE}"'"'
  hzn::log.info "Set movie_output_motion to ${VALUE}"
fi

# set picture_type (jpeg, ppm)
VALUE=$(jq -r ".default.picture_type" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="jpeg"; fi
sed -i "s/.*picture_type .*/picture_type ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_type":"'"${VALUE}"'"'
hzn::log.debug "Set picture_type to ${VALUE}"

# set netcam_keepalive (off,force,on)
VALUE=$(jq -r ".default.netcam_keepalive" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/.*netcam_keepalive .*/netcam_keepalive ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"netcam_keepalive":"'"${VALUE}"'"'
hzn::log.debug "Set netcam_keepalive to ${VALUE}"

# set netcam_userpass 
VALUE=$(jq -r ".default.netcam_userpass" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=""; fi
sed -i "s/.*netcam_userpass .*/netcam_userpass ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"netcam_userpass":"'"${VALUE}"'"'
hzn::log.debug "Set netcam_userpass to ${VALUE}"

## numeric values

# set v4l2_palette
VALUE=$(jq -r ".default.palette" "${CONFIG_PATH}")
if [ "${VALUE}" != "null" ] && [ ! -z "${VALUE}" ]; then
  sed -i "s/.*v4l2_palette\s[0-9]\+/v4l2_palette ${VALUE}/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"palette":'"${VALUE}"
  hzn::log.debug "Set palette to ${VALUE}"
fi

# set pre_capture
VALUE=$(jq -r ".default.pre_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/.*pre_capture\s[0-9]\+/pre_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"pre_capture":'"${VALUE}"
hzn::log.debug "Set pre_capture to ${VALUE}"

# set post_capture
VALUE=$(jq -r ".default.post_capture" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/.*post_capture\s[0-9]\+/post_capture ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"post_capture":'"${VALUE}"
hzn::log.debug "Set post_capture to ${VALUE}"

# set event_gap
VALUE=$(jq -r ".default.event_gap" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=5; fi
sed -i "s/.*event_gap\s[0-9]\+/event_gap ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"event_gap":'"${VALUE}"
hzn::log.debug "Set event_gap to ${VALUE}"

# set fov
VALUE=$(jq -r ".default.fov" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=60; fi
MOTION="${MOTION}"',"fov":'"${VALUE}"
hzn::log.debug "Set fov to ${VALUE}"

# set minimum_motion_frames
VALUE=$(jq -r ".default.minimum_motion_frames" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1; fi
sed -i "s/.*minimum_motion_frames\s[0-9]\+/minimum_motion_frames ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"minimum_motion_frames":'"${VALUE}"
hzn::log.debug "Set minimum_motion_frames to ${VALUE}"

# set quality
VALUE=$(jq -r ".default.picture_quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=100; fi
sed -i "s/.*picture_quality\s[0-9]\+/picture_quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"picture_quality":'"${VALUE}"
hzn::log.debug "Set picture_quality to ${VALUE}"

# set framerate
VALUE=$(jq -r ".default.framerate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=5; fi
sed -i "s/.*framerate\s[0-9]\+/framerate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"framerate":'"${VALUE}"
hzn::log.debug "Set framerate to ${VALUE}"

# set text_changes
VALUE=$(jq -r ".default.changes" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE='off'; fi
sed -i "s/.*text_changes\s[0-9]\+/text_changes ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"changes":"'"${VALUE}"'"'
hzn::log.debug "Set text_changes to ${VALUE}"

# set text_scale
VALUE=$(jq -r ".default.text_scale" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=1; fi
sed -i "s/.*text_scale\s[0-9]\+/text_scale ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"text_scale":'"${VALUE}"
hzn::log.debug "Set text_scale to ${VALUE}"

# set despeckle_filter
VALUE=$(jq -r ".default.despeckle" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE='EedDl'; fi
sed -i "s/.*despeckle_filter\s[0-9]\+/despeckle_filter ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"despeckle_filter":"'"${VALUE}"'"'
hzn::log.debug "Set despeckle_filter to ${VALUE}"

## vid_control_params

## ps3eye 
# ---------Controls---------
#   V4L2 ID   Name and Range
# ID09963776 Brightness, 0 to 255
# ID09963777 Contrast, 0 to 255
# ID09963778 Saturation, 0 to 255
# ID09963779 Hue, -90 to 90
# ID09963788 White Balance, Automatic, 0 to 1
# ID09963793 Exposure, 0 to 255
# ID09963794 Gain, Automatic, 0 to 1
# ID09963795 Gain, 0 to 63
# ID09963796 Horizontal Flip, 0 to 1
# ID09963797 Vertical Flip, 0 to 1
# ID09963800 Power Line Frequency, 0 to 1
#   menu item: Value 0 Disabled
#   menu item: Value 1 50 Hz
# ID09963803 Sharpness, 0 to 63
# ID10094849 Auto Exposure, 0 to 1
#   menu item: Value 0 Auto Mode
#   menu item: Value 1 Manual Mode
# --------------------------

# set brightness
VALUE=$(jq -r ".default.brightness" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/brightness=[0-9]\+/brightness=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"brightness":'"${VALUE}"
hzn::log.debug "Set brightness to ${VALUE}"

# set contrast
VALUE=$(jq -r ".default.contrast" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/contrast=[0-9]\+/contrast=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"contrast":'"${VALUE}"
hzn::log.debug "Set contrast to ${VALUE}"

# set saturation
VALUE=$(jq -r ".default.saturation" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/saturation=[0-9]\+/saturation=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"saturation":'"${VALUE}"
hzn::log.debug "Set saturation to ${VALUE}"

# set hue
VALUE=$(jq -r ".default.hue" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
sed -i "s/hue=[0-9]\+/hue=${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"hue":'"${VALUE}"
hzn::log.debug "Set hue to ${VALUE}"

## other

# set rotate
VALUE=$(jq -r ".default.rotate" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
hzn::log.debug "Set rotate to ${VALUE}"
sed -i "s/.*rotate\s[0-9]\+/rotate ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"rotate":'"${VALUE}"

# set webcontrol_port
VALUE=$(jq -r ".default.webcontrol_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_CONTROL_PORT}; fi
hzn::log.debug "Set webcontrol_port to ${VALUE}"
sed -i "s/.*webcontrol_port\s[0-9]\+/webcontrol_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"webcontrol_port":'"${VALUE}"

# set stream_port
VALUE=$(jq -r ".default.stream_port" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_STREAM_PORT}; fi
hzn::log.debug "Set stream_port to ${VALUE}"
sed -i "s/.*stream_port\s[0-9]\+/stream_port ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_port":'"${VALUE}"

# set stream_quality
VALUE=$(jq -r ".default.stream_quality" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=100; fi
hzn::log.debug "Set stream_quality to ${VALUE}"
sed -i "s/.*stream_quality\s[0-9]\+/stream_quality ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"stream_quality":'"${VALUE}"

# set width
VALUE=$(jq -r ".default.width" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=640; fi
sed -i "s/.*width\s[0-9]\+/width ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"width":'"${VALUE}"
WIDTH=${VALUE}
hzn::log.debug "Set width to ${VALUE}"

# set height
VALUE=$(jq -r ".default.height" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=480; fi
sed -i "s/.*height\s[0-9]\+/height ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"height":'"${VALUE}"
HEIGHT=${VALUE}
hzn::log.debug "Set height to ${VALUE}"

# set threshold_tune (on/off)
VALUE=$(jq -r ".default.threshold_tune" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="on"; fi
sed -i "s/.*threshold_tune .*/threshold_tune ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold_tune":"'"${VALUE}"'"'
hzn::log.debug "Set threshold_tune to ${VALUE}"

# set threshold_percent
VALUE=$(jq -r ".default.threshold_percent" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [ ${VALUE:-0} == 0 ]; then 
  VALUE=$(jq -r ".default.threshold" "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    VALUE=10
    hzn::log.debug "DEFAULT threshold_percent to ${VALUE}"
    MOTION="${MOTION}"',"threshold_percent":'"${VALUE}"
    VALUE=$((VALUE * WIDTH * HEIGHT / 100))
  fi
else
  hzn::log.debug "Set threshold_percent to ${VALUE}"
  MOTION="${MOTION}"',"threshold_percent":'"${VALUE}"
  VALUE=$((VALUE * WIDTH * HEIGHT / 100))
fi
# set threshold
hzn::log.debug "Set threshold to ${VALUE}"
sed -i "s/.*threshold.*/threshold ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"threshold":'"${VALUE}"

# set lightswitch
VALUE=$(jq -r ".default.lightswitch" "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=0; fi
hzn::log.debug "Set lightswitch to ${VALUE}"
sed -i "s/.*lightswitch.*/lightswitch ${VALUE}/" "${MOTION_CONF}"
MOTION="${MOTION}"',"lightswitch":'"${VALUE}"

# set interval for events
VALUE=$(jq -r '.default.interval' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=3600; fi
hzn::log.debug "Set watchdog interval to ${VALUE}"
MOTION="${MOTION}"',"interval":'${VALUE}
# used in MAIN
MOTION_WATCHDOG_INTERVAL=${VALUE}

# set type
VALUE=$(jq -r '.default.type' "${CONFIG_PATH}")
if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="netcam"; fi
hzn::log.debug "Set type to ${VALUE}"
MOTION="${MOTION}"',"type":"'"${VALUE}"'"'

## ALL CAMERAS SHARE THE SAME USERNAME:PASSWORD CREDENTIALS

# set username and password
USERNAME=$(jq -r ".default.username" "${CONFIG_PATH}")
PASSWORD=$(jq -r ".default.password" "${CONFIG_PATH}")
if [ "${USERNAME}" != "null" ] && [ "${PASSWORD}" != "null" ] && [ ! -z "${USERNAME}" ] && [ ! -z "${PASSWORD}" ]; then
  hzn::log.debug "Set authentication to Basic for both stream and webcontrol"
  sed -i "s/.*stream_auth_method.*/stream_auth_method 1/" "${MOTION_CONF}"
  sed -i "s/.*stream_authentication.*/stream_authentication ${USERNAME}:${PASSWORD}/" "${MOTION_CONF}"
  sed -i "s/.*webcontrol_authentication.*/webcontrol_authentication ${USERNAME}:${PASSWORD}/" "${MOTION_CONF}"
  hzn::log.debug "Enable access for any host"
  sed -i "s/.*stream_localhost .*/stream_localhost off/" "${MOTION_CONF}"
  sed -i "s/.*webcontrol_localhost .*/webcontrol_localhost off/" "${MOTION_CONF}"
  MOTION="${MOTION}"',"stream_auth_method":"Basic"'
else
  hzn::log.debug "WARNING: no username and password; stream and webcontrol limited to localhost only"
  sed -i "s/.*stream_localhost .*/stream_localhost on/" "${MOTION_CONF}"
  sed -i "s/.*webcontrol_localhost .*/webcontrol_localhost on/" "${MOTION_CONF}"
fi

# add username and password to configuration
MOTION="${MOTION}"',"username":"'"${USERNAME}"'"'
MOTION="${MOTION}"',"password":"'"${PASSWORD}"'"'

## end motion structure; cameras section depends on well-formed JSON for $MOTION
MOTION="${MOTION}"'}'

## append to configuration JSON
JSON="${JSON}"',"motion":'"${MOTION}"

hzn::log.debug "MOTION: $(echo "${MOTION}" | jq -c '.')"

###
### process cameras 
###

ncamera=$(jq '.cameras|length' "${CONFIG_PATH}")

MOTION_COUNT=0
CNUM=0

##
## LOOP THROUGH ALL CAMERAS
##

for (( i=0; i < ncamera; i++)); do

  hzn::log.debug "+++ CAMERA ${i}"

  ## TOP-LEVEL
  if [ -z "${CAMERAS:-}" ]; then CAMERAS='['; else CAMERAS="${CAMERAS}"','; fi
  hzn::log.debug "CAMERA #: $i"
  CAMERAS="${CAMERAS}"'{"id":'${i}

  # process camera type
  VALUE=$(jq -r '.cameras['${i}'].type' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    VALUE=$(jq -r '.default.type' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="wcv80n"; fi
  fi
  hzn::log.debug "Set type to ${VALUE}"
  CAMERAS="${CAMERAS}"',"type":"'"${VALUE}"'"'

  # name
  VALUE=$(jq -r '.cameras['${i}'].name' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="camera-name${i}"; fi
  hzn::log.debug "Set name to ${VALUE}"
  CAMERAS="${CAMERAS}"',"name":"'"${VALUE}"'"'
  CNAME=${VALUE}

  # process models string to array of strings
  VALUE=$(jq -r '.cameras['${i}'].models' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
    W=$(echo "${WATSON:-}" | jq -r '.models[]'| sed 's/\([^,]*\)\([,]*\)/"wvr:\1"\2/g' | fmt -1000)
    # hzn::log.debug "WATSON: ${WATSON} ${W}"
    D=$(echo "${DIGITS:-}" | jq -r '.models[]'| sed 's/\([^,]*\)\([,]*\)/"digits:\1"\2/g' | fmt -1000)
    # hzn::log.debug "DIGITS: ${DIGITS} ${D}"
    VALUE=$(echo ${W} ${D})
    VALUE=$(echo "${VALUE}" | sed "s/ /,/g")
  else
    VALUE=$(echo "${VALUE}" | sed 's/\([^,]*\)\([,]*\)/"\1"\2/g')
  fi
  hzn::log.debug "Set models to ${VALUE}"
  CAMERAS="${CAMERAS}"',"models":['"${VALUE}"']'

  # process camera fov; WCV80n is 61.5 (62); 56 or 75 degrees for PS3 Eye camera
  VALUE=$(jq -r '.cameras['${i}'].fov' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [ ${VALUE} -lt 1 ]; then VALUE=$(echo "${MOTION}" | jq -r '.fov'); fi
  hzn::log.debug "Set fov to ${VALUE}"
  CAMERAS="${CAMERAS}"',"fov":'"${VALUE}"

  # width 
  VALUE=$(jq -r '.cameras['${i}'].width' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.width'); fi
  CAMERAS="${CAMERAS}"',"width":'"${VALUE}"
  hzn::log.debug "Set width to ${VALUE}"
  WIDTH=${VALUE}

  # height 
  VALUE=$(jq -r '.cameras['${i}'].height' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.height'); fi
  CAMERAS="${CAMERAS}"',"height":'"${VALUE}"
  hzn::log.debug "Set height to ${VALUE}"
  HEIGHT=${VALUE}

  # process camera framerate; set on wcv80n web GUI; default 6
  VALUE=$(jq -r '.cameras['${i}'].framerate' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then 
    VALUE=$(jq -r '.framerate' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=$(echo "${MOTION}" | jq -r '.framerate'); fi
  fi
  hzn::log.debug "Set framerate to ${VALUE}"
  CAMERAS="${CAMERAS}"',"framerate":'"${VALUE}"
  FRAMERATE=${VALUE}

  # process camera event_gap; set on wcv80n web GUI; default 6
  VALUE=$(jq -r '.cameras['${i}'].event_gap' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then 
    VALUE=$(jq -r '.event_gap' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [[ ${VALUE} < 1 ]]; then VALUE=$(echo "${MOTION}" | jq -r '.event_gap'); fi
  fi
  hzn::log.debug "Set event_gap to ${VALUE}"
  CAMERAS="${CAMERAS}"',"event_gap":'"${VALUE}"
  EVENT_GAP=${VALUE}

  # target_dir 
  VALUE=$(jq -r '.cameras['${i}'].target_dir' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE="${MOTION_TARGET_DIR}/${CNAME}"; fi
  hzn::log.debug "Set target_dir to ${VALUE}"
  if [ ! -d "${VALUE}" ]; then mkdir -p "${VALUE}"; fi
  CAMERAS="${CAMERAS}"',"target_dir":"'"${VALUE}"'"'
  TARGET_DIR="${VALUE}"

  # TYPE
  VALUE=$(jq -r '.cameras['${i}'].type' "${CONFIG_PATH}")
  case "${VALUE}" in
    local|netcam)
        TYPE="${VALUE}"
        hzn::log.info "Camera: ${CNAME}; number: ${CNUM}; type: ${TYPE}"
        CAMERAS="${CAMERAS}"',"type":"'"${TYPE}"'"'
	;;
    ftpd|mqtt)
        TYPE="${VALUE}"
        hzn::log.info "Camera: ${CNAME}; number: ${CNUM}; type: ${TYPE}"
        CAMERAS="${CAMERAS}"',"type":"'"${TYPE}"'"'

        # live
        VALUE=$(jq -r '.cameras['${i}'].netcam_url' "${CONFIG_PATH}")
        if [ "${VALUE}" != "null" ] || [ ! -z "${VALUE}" ]; then 
          CAMERAS="${CAMERAS}"',"netcam_url":"'"${VALUE}"'"'
          UP=$(jq -r '.cameras['${i}'].netcam_userpass' "${CONFIG_PATH}")
          if [ "${UP}" != "null" ] && [ ! -z "${UP}" ]; then 
            CAMERAS="${CAMERAS}"',"netcam_userpass":"'"${UP}"'"'
            VALUE="${VALUE%%//*}//${UP}@${VALUE##*://}"
          fi
        fi
        hzn::log.debug "Set mjpeg_url to ${VALUE}"
        CAMERAS="${CAMERAS}"',"mjpeg_url":"'"${VALUE}"'"'

        # icon
        VALUE=$(jq -r '.cameras['${i}'].icon' "${CONFIG_PATH}")
        if [ "${VALUE}" != "null" ] || [ ! -z "${VALUE}" ]; then 
          hzn::log.debug "Set icon to ${VALUE}"
          CAMERAS="${CAMERAS}"',"icon":"'"${VALUE}"'"'
        fi

        # FTP share_dir
        if [ "${TYPE}" == 'ftpd' ]; then
          VALUE="${MOTION_SHARE_DIR%/*}/ftp/${CNAME}"
          hzn::log.debug "Set share_dir to ${VALUE}"
          CAMERAS="${CAMERAS}"',"share_dir":"'"${VALUE}"'"'
        fi

        # complete
        CAMERAS="${CAMERAS}"'}'
        continue
	;;
    *)
        TYPE="unknown"
        hzn::log.error "Camera: ${CNAME}; number: ${CNUM}; invalid camera type: ${VALUE}; setting to ${TYPE}; skipping"
        CAMERAS="${CAMERAS}"',"type":"'"${TYPE}"'"'
        # complete
        CAMERAS="${CAMERAS}"'}'
        continue
	;;
  esac

  ##
  ## handle more than one motion process (10 camera/process)
  ##

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
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=${MOTION_CONTROL_PORT}; fi
      VALUE=$((VALUE + MOTION_COUNT))
      hzn::log.debug "Set webcontrol_port to ${VALUE}"
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
  CAMERAS="${CAMERAS}"',"server":'"${MOTION_COUNT}"
  CAMERAS="${CAMERAS}"',"cnum":'"${CNUM}"
  CAMERAS="${CAMERAS}"',"conf":"'"${CAMERA_CONF}"'"'

  # calculate mjpeg_url for camera
  VALUE="http://127.0.0.1:${MOTION_STREAM_PORT}/${CNUM}"
  hzn::log.debug "Set mjpeg_url to ${VALUE}"
  CAMERAS="${CAMERAS}"',"mjpeg_url":"'${VALUE}'"'

  ##
  ## make camera configuration file
  ##

  # basics
  echo "camera_id ${CNUM}" > "${CAMERA_CONF}"
  echo "camera_name ${CNAME}" >> "${CAMERA_CONF}"
  echo "target_dir ${TARGET_DIR}" >> "${CAMERA_CONF}"
  echo "width ${WIDTH}" >> "${CAMERA_CONF}"
  echo "height ${HEIGHT}" >> "${CAMERA_CONF}"
  echo "framerate ${FRAMERATE}" >> "${CAMERA_CONF}"
  echo "event_gap ${EVENT_GAP}" >> "${CAMERA_CONF}"

  # rotate 
  VALUE=$(jq -r '.cameras['${i}'].rotate' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.rotate'); fi
  hzn::log.debug "Set rotate to ${VALUE}"
  echo "rotate ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"rotate":'"${VALUE}"

  # picture_quality 
  VALUE=$(jq -r '.cameras['${i}'].picture_quality' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.picture_quality'); fi
  echo "picture_quality ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"picture_quality":'"${VALUE}"
  hzn::log.debug "Set picture_quality to ${VALUE}"

  # stream_quality 
  VALUE=$(jq -r '.cameras['${i}'].stream_quality' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.stream_quality'); fi
  echo "stream_quality ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"stream_quality":'"${VALUE}"
  hzn::log.debug "Set stream_quality to ${VALUE}"

  # threshold 
  VALUE=$(jq -r '.cameras['${i}'].threshold_percent' "${CONFIG_PATH}")
  if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [ ${VALUE:-0} == 0 ]; then 
    VALUE=$(jq -r '.cameras['${i}'].threshold' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then 
      VALUE=$(echo "${MOTION}" | jq -r '.threshold_percent')
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ] || [ ${VALUE:-0} == 0 ]; then 
        VALUE=$(echo "${MOTION}" | jq -r '.threshold')
      else
        hzn::log.debug "Set threshold_percent to ${VALUE}"
        CAMERAS="${CAMERAS}"',"threshold_percent":'"${VALUE}"
        VALUE=$((VALUE * WIDTH * HEIGHT / 100))
      fi
    fi
  else
    # threshold as percent
    hzn::log.debug "Set threshold_percent to ${VALUE}"
    CAMERAS="${CAMERAS}"',"threshold_percent":'"${VALUE}"
    VALUE=$((VALUE * WIDTH * HEIGHT / 100))
  fi
  hzn::log.debug "Set threshold to ${VALUE}"
  echo "threshold ${VALUE}" >> "${CAMERA_CONF}"
  CAMERAS="${CAMERAS}"',"threshold":'"${VALUE}"

  if [ "${TYPE}" == 'netcam' ]; then
    # network camera
    VALUE=$(jq -r '.cameras['${i}'].netcam_url' "${CONFIG_PATH}")
    if [ ! -z "${VALUE:-}" ] && [ "${VALUE:-null}" != 'null' ]; then
      # network camera
      CAMERAS="${CAMERAS}"',"netcam_url":"'"${VALUE}"'"'
      echo "netcam_url ${VALUE}" >> "${CAMERA_CONF}"
      hzn::log.debug "Set netcam_url to ${VALUE}"
      netcam_url=$(echo "${VALUE}" | sed 's/mjpeg:/http:/')

      # userpass 
      VALUE=$(jq -r '.cameras['${i}'].netcam_userpass' "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_userpass'); fi
      echo "netcam_userpass ${VALUE}" >> "${CAMERA_CONF}"
      CAMERAS="${CAMERAS}"',"netcam_userpass":"'"${VALUE}"'"'
      hzn::log.debug "Set netcam_userpass to ${VALUE}"
      netcam_userpass=${VALUE}

      # test netcam_url
      alive=$(curl -sL -w '%{http_code}' --connect-timeout 2 --retry-connrefused --retry 10 --retry-max-time 2 --max-time 15 -u ${netcam_userpass} ${netcam_url} -o /dev/null 2> /dev/null)
      if [ "${alive:-000}" != '200' ]; then
        hzn::log.notice "Network camera at ${netcam_url}; userpass: ${netcam_userpass}; bad response: ${alive}"
      else
        hzn::log.info "Network camera at ${netcam_url}; userpass: ${netcam_userpass}; good response: ${alive}"
      fi

      # keepalive 
      VALUE=$(jq -r '.cameras['${i}'].keepalive' "${CONFIG_PATH}")
      if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.netcam_keepalive'); fi
      echo "netcam_keepalive ${VALUE}" >> "${CAMERA_CONF}"
      CAMERAS="${CAMERAS}"',"keepalive":"'"${VALUE}"'"'
      hzn::log.debug "Set netcam_keepalive to ${VALUE}"
    else
      hzn::log.error "No netcam_url specified: ${VALUE}; skipping"
      # close CAMERAS structure
      CAMERAS="${CAMERAS}"'}'
      continue;
    fi
  elif [ "${TYPE}" == 'local' ]; then
    # local camera
    VALUE=$(jq -r '.cameras['${i}'].device' "${CONFIG_PATH}")
    if [ "${VALUE:-null}" != 'null' ] ; then
      if [[ "${VALUE}" != /dev/video* ]]; then
        hzn::log.error "Camera: ${i}; name: ${CNAME}; invalid videodevice ${VALUE}; exiting"
        exit 1
      fi
    else
      VALUE="/dev/video0"
    fi
    echo "videodevice ${VALUE}" >> "${CAMERA_CONF}"
    hzn::log.debug "Set videodevice to ${VALUE}"
    # palette
    VALUE=$(jq -r '.cameras['${i}'].palette' "${CONFIG_PATH}")
    if [ "${VALUE}" == "null" ] || [ -z "${VALUE}" ]; then VALUE=$(echo "${MOTION}" | jq -r '.palette'); fi
    CAMERAS="${CAMERAS}"',"palette":'"${VALUE}"
    echo "v4l2_palette ${VALUE}" >> "${CAMERA_CONF}"
    hzn::log.debug "Set palette to ${VALUE}"
  else
    hzn::log.error "Invalid camera type: ${TYPE}"
  fi

  # close CAMERAS structure
  CAMERAS="${CAMERAS}"'}'

  # add new camera configuration
  echo "camera ${CAMERA_CONF}" >> "${MOTION_CONF}"
done
# finish CAMERAS
if [ -n "${CAMERAS:-}" ]; then 
  CAMERAS="${CAMERAS}"']'
else
  CAMERAS='null'
fi

hzn::log.debug "CAMERAS: $(echo "${CAMERAS}" | jq -c '.')"

###
## append camera, finish JSON configuration, and validate
###

JSON="${JSON}"',"cameras":'"${CAMERAS}"'}'
echo "${JSON}" | jq -c '.' > "$(motion::config.file)"
if [ ! -s "$(motion::config.file)" ]; then
  hzn::log.error "INVALID CONFIGURATION; metadata: ${JSON}"
  exit 1
fi
hzn::log.debug "CONFIGURATION; file: $(motion::config.file); metadata: $(jq -c '.' $(motion::config.file))"

###
## configure inotify() for any 'ftpd' cameras
###

hzn::log.debug "Settting up notifywait for FTPD cameras"
ftp_notifywait.sh "$(motion::config.file)"

###
## start all motion daemons
###

PID_FILES=()
CONF="${MOTION_CONF%%.*}.${MOTION_CONF##*.}"
# process all motion configurations
for (( i = 1; i <= MOTION_COUNT;  i++)); do
  # test for configuration file
  if [ ! -s "${CONF}" ]; then
     hzn::log.error "missing configuration for daemon ${i} with ${CONF}"
     exit 1
  fi
  hzn::log.debug "Starting motion configuration ${i}: ${CONF}"
  PID_FILE="${MOTION_CONF%%.*}.${i}.pid"
  motion -b -c "${CONF}" -p ${PID_FILE}
  PID_FILES=(${PID_FILES[@]} ${PID_FILE})

  # get next configuration
  CONF="${MOTION_CONF%%.*}.${i}.${MOTION_CONF##*.}"
done

if [ ${#PID_FILES[@]} -le 0 ]; then
  hzn::log.info "ZERO motion daemons"
  hzn::log.info "STARTING APACHE (foreground); ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}"
  motion::apache.start_foreground ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}
else 
  hzn::log.info "${#PID_FILES[@]} motion daemons"
  hzn::log.info "STARTING APACHE (background); ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}"
  motion::apache.start_background ${MOTION_APACHE_CONF} ${MOTION_APACHE_HOST} ${MOTION_APACHE_PORT}

  ## monitor motion daemons
  hzn::log.info "STARTING MOTION WATCHDOG; ${PID_FILES}"
  ## forever
  while true; do
    ## publish configuration
    hzn::log.notice "PUBLISHING CONFIGURATION; topic: $(motion::config.group)/$(motion::config.device)/start"
    motion::mqtt.pub -r -q 2 -t "$(motion::config.group)/$(motion::config.device)/start" -f "$(motion::config.file)"

    i=0
    for PID_FILE in ${PID_FILES[@]}; do
      if [ ! -z "${PID_FILE:-}" ] && [ -s "${PID_FILE}" ]; then
        pid=$(cat ${PID_FILE})
        if [ "${pid:-null}" != 'null' ]; then
          found=$(ps alxwww | grep 'motion -b' | awk '{ print $1 }' | egrep ${pid})
          if [ -z "${found:-}" ]; then
            hzn::log.notice "Daemon with PID: ${pid} is not found; restarting"
            if [ ${i} -gt 0 ]; then
              CONF="${MOTION_CONF%%.*}.${i}.${MOTION_CONF##*.}"
            else
              CONF="${MOTION_CONF%%.*}.${MOTION_CONF##*.}"
            fi
            motion -b -c "${CONF}" -p ${PID_FILE}
          else
            hzn::log.info "motion daemon running with PID: ${pid}"
          fi
        else
          hzn::log.error "PID file contents invalid: ${PID_FILE}"
        fi
      else
        hzn::log.error "No motion daemon PID file: ${PID_FILE}"
      fi
      i=$((i+1))
    done
    hzn::log.info "watchdog sleeping..."
    sleep ${MOTION_WATCHDOG_INTERVAL:-3600}
  done
fi
