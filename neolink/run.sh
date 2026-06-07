#!/usr/bin/env bash
# Home Assistant add-on entrypoint for neolink.
# Reads add-on options, resolves the MQTT broker, generates /etc/neolink.toml
# via gen-config.sh, then execs neolink in the right mode.
set -euo pipefail
# shellcheck source=/dev/null
source /usr/lib/bashio/lib/bashio.sh

CONFIG=/etc/neolink.toml

# Log level -> RUST_LOG
level="$(bashio::config 'log_level')"
case "$level" in
  trace|debug) export RUST_LOG="info,neolink_core::bc_protocol::connection::udpsource=debug,neolink=${level}" ;;
  *)           export RUST_LOG="${level:-info}" ;;
esac

# Start from the raw options document.
opts="$(bashio::addon.config)"

# --- Resolve MQTT into .mqtt_resolved ---
mqtt_enabled="$(bashio::config 'mqtt.enabled')"
mqtt_resolved='{"enabled":false}'
if [ "$mqtt_enabled" = "true" ]; then
  broker="$(bashio::config 'mqtt.broker_override')"; [ "$broker" = "null" ] && broker=""
  port="$(bashio::config 'mqtt.port_override')";     [ "$port" = "null" ] && port=""
  user="$(bashio::config 'mqtt.username_override')";  [ "$user" = "null" ] && user=""
  pass="$(bashio::config 'mqtt.password_override')";  [ "$pass" = "null" ] && pass=""
  if [ -z "$broker" ] || [ "$broker" = "null" ]; then
    if bashio::services.available 'mqtt'; then
      broker="$(bashio::services 'mqtt' 'host')"
      port="$(bashio::services 'mqtt' 'port')"
      user="$(bashio::services 'mqtt' 'username')"
      pass="$(bashio::services 'mqtt' 'password')"
    else
      bashio::log.warning "MQTT enabled but no broker override and no HA MQTT service available; starting RTSP-only."
      broker=""
    fi
  fi
  if [ -n "$broker" ] && [ "$broker" != "null" ]; then
    discovery="$(bashio::config 'mqtt.discovery')"
    topic="$(bashio::config 'mqtt.discovery_topic')"
    mqtt_resolved="$(jq -n \
      --arg b "$broker" --argjson p "${port:-1883}" \
      --arg u "${user:-}" --arg pw "${pass:-}" \
      --argjson disc "${discovery:-false}" --arg topic "${topic:-homeassistant}" \
      '{enabled:true, broker:$b, port:$p, discovery:$disc, discovery_topic:$topic}
       + (if $u == "" then {} else {username:$u, password:$pw} end)')"
  fi
fi

# Build the effective options and generate the config.
effective="$(jq -c --argjson m "$mqtt_resolved" '. + {mqtt_resolved:$m}' <<<"$opts")"
printf '%s' "$effective" | /usr/bin/neolink-gen-config > "$CONFIG"

if [ "$level" = "debug" ] || [ "$level" = "trace" ]; then
  bashio::log.info "Generated neolink.toml (passwords redacted):"
  bashio::log.info "$(sed -E 's/(password|pass|credentials)[^=]*=.*/\1 = <redacted>/I' "$CONFIG")"
fi

# Mode: mqtt-rtsp if we wrote an [mqtt] block, else rtsp.
mode="rtsp"
grep -q '^\[mqtt\]' "$CONFIG" && mode="mqtt-rtsp"
bashio::log.info "Starting neolink in '${mode}' mode."
exec neolink "$mode" --config "$CONFIG"
