#!/usr/bin/with-contenv bashio

source ${USRBIN:-/usr/bin}/motion-tools.sh

hzn::log.trace "START"

image="${1:-}"
output="${2:-}"

if [ ! -z "${image}" ] && [ ! -z "${output}" ]; then
  hzn::log.trace "moving $image to $output"
  mv -f "$image" "$output"
fi

hzn::log.trace "FINISH"
