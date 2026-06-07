#!/usr/bin/env bash
# Pure generator: reads an "effective options" JSON document on stdin and writes
# a neolink.toml to stdout. No bashio / Supervisor dependency (unit-testable).
set -euo pipefail

OPTS="$(cat)"

# Fail closed: reject empty or malformed stdin. jq failures inside command
# substitutions are not caught by `set -e`, so guard the input up front.
jq -e . >/dev/null 2>&1 <<<"$OPTS" || { echo "gen-config: stdin is not valid JSON" >&2; exit 1; }

# jq helpers bound to the input document
jqr() { jq -r "$1" <<<"$OPTS"; }   # raw scalar
# Encode an arbitrary string as a TOML basic string. JSON string escaping is a
# superset-compatible subset of TOML basic-string escaping, so tojson is safe.
tomlstr() { jq -rn --arg v "$1" '$v | tojson'; }

# --- Server (top-level) ---
printf 'bind = %s\n' "$(tomlstr "$(jqr '.bind // "0.0.0.0"')")"
printf 'bind_port = %s\n' "$(jqr '.bind_port // 8554')"
cert="$(jqr '.certificate // empty')"
[ -n "$cert" ] && printf 'certificate = %s\n' "$(tomlstr "$cert")"
tca="$(jqr '.tls_client_auth // empty')"
[ -n "$tca" ] && printf 'tls_client_auth = %s\n' "$(tomlstr "$tca")"

# --- RTSP users ---
n_users="$(jqr '(.rtsp_users // []) | length')"
for ((i=0; i<n_users; i++)); do
  uname="$(jqr ".rtsp_users[$i].name")"
  upass="$(jqr ".rtsp_users[$i].pass // \"\"")"
  printf '\n[[users]]\n'
  printf 'name = %s\n' "$(tomlstr "$uname")"
  printf 'pass = %s\n' "$(tomlstr "$upass")"
done

# --- MQTT broker (resolved upstream into .mqtt_resolved) ---
if [ "$(jqr '.mqtt_resolved.enabled // false')" = "true" ]; then
  printf '\n[mqtt]\n'
  printf 'broker_addr = %s\n' "$(tomlstr "$(jqr '.mqtt_resolved.broker')")"
  printf 'port = %s\n' "$(jqr '.mqtt_resolved.port')"
  muser="$(jqr '.mqtt_resolved.username // empty')"
  if [ -n "$muser" ]; then
    mpass="$(jqr '.mqtt_resolved.password // ""')"
    printf 'credentials = [%s, %s]\n' "$(tomlstr "$muser")" "$(tomlstr "$mpass")"
  fi
fi

# --- Cameras ---
n_cams="$(jqr '(.cameras // []) | length')"
for ((i=0; i<n_cams; i++)); do
  cam="$(jq -c ".cameras[$i]" <<<"$OPTS")"
  cj() { jq -r "$1" <<<"$cam"; }          # raw from camera
  cname="$(cj '.name // empty')"
  { [ -z "$cname" ] || [ "$cname" = "null" ]; } && { echo "Camera entry is missing a name" >&2; exit 1; }
  uname="$(cj '.username // empty')"
  { [ -z "$uname" ] || [ "$uname" = "null" ]; } && { echo "Camera '$cname': missing a username" >&2; exit 1; }
  uid="$(cj '.uid // empty')"
  addr="$(cj '.address // empty')"
  if [ -n "$uid" ] && [ -n "$addr" ]; then
    echo "Camera '$cname': set only one of uid or address" >&2; exit 1
  fi
  if [ -z "$uid" ] && [ -z "$addr" ]; then
    echo "Camera '$cname': must set uid or address" >&2; exit 1
  fi

  printf '\n[[cameras]]\n'
  printf 'name = %s\n' "$(tomlstr "$cname")"
  printf 'username = %s\n' "$(tomlstr "$(cj '.username')")"
  pw="$(cj '.password // empty')"; [ -n "$pw" ] && printf 'password = %s\n' "$(tomlstr "$pw")"
  [ -n "$uid" ]  && printf 'uid = %s\n' "$(tomlstr "$uid")"
  [ -n "$addr" ] && printf 'address = %s\n' "$(tomlstr "$addr")"

  # Optional string scalars (top-level camera fields)
  for k in stream discovery connect_mode relay_server_region; do
    v="$(jq -r --arg k "$k" '.[$k] // empty' <<<"$cam")"
    [ -n "$v" ] && printf '%s = %s\n' "$k" "$(tomlstr "$v")"
  done

  # channel_id always emitted (anchors the scalar block; default 0)
  printf 'channel_id = %s\n' "$(cj '.channel_id // 0')"

  # permitted_users: a JSON array of strings is valid TOML when compact
  if [ "$(jq -r '(.permitted_users // []) | length' <<<"$cam")" -gt 0 ]; then
    printf 'permitted_users = %s\n' "$(jq -c '.permitted_users' <<<"$cam")"
  fi

  adv="$(jq -c '.advanced // {}' <<<"$cam")"
  # Presence-based read: distinguishes an absent key from a present boolean
  # `false` (jq's `// empty` would drop a literal false, so we use `has`).
  aj() { jq -r --arg k "$1" 'if has($k) then .[$k] else empty end' <<<"$adv"; }
  # numeric advanced scalars (emitted unquoted)
  for k in buffer_duration idle_timeout_secs relay_warm_seconds udp_gap_skip_ms max_discovery_retries; do
    v="$(aj "$k")"; [ -n "$v" ] && printf '%s = %s\n' "$k" "$v"
  done
  # string advanced scalars
  for k in max_encryption splash_pattern; do
    v="$(aj "$k")"; [ -n "$v" ] && printf '%s = %s\n' "$k" "$(tomlstr "$v")"
  done
  # boolean advanced scalars (emitted as true/false)
  for k in strict update_time use_splash debug enabled; do
    v="$(aj "$k")"; [ -n "$v" ] && printf '%s = %s\n' "$k" "$v"
  done

  # [cameras.mqtt] — per-camera enable toggles + update intervals
  mqtt_bools=(enable_motion enable_light enable_battery enable_preview enable_floodlight)
  mqtt_ints=(battery_update preview_update floodlight_update)
  mqtt_lines=""
  for k in "${mqtt_bools[@]}"; do
    v="$(aj "$k")"; [ -n "$v" ] && mqtt_lines+="$k = $v"$'\n'
  done
  for k in "${mqtt_ints[@]}"; do
    v="$(aj "$k")"; [ -n "$v" ] && mqtt_lines+="$k = $v"$'\n'
  done
  if [ -n "$mqtt_lines" ]; then
    printf '\n[cameras.mqtt]\n%s' "$mqtt_lines"
  fi

  # [cameras.mqtt.discovery] — only when MQTT discovery is enabled and features set
  feats="$(jq -c '.mqtt_discovery_features // []' <<<"$cam")"
  if [ "$(jqr '.mqtt_resolved.discovery // false')" = "true" ] && [ "$(jq 'length' <<<"$feats")" -gt 0 ]; then
    printf '\n[cameras.mqtt.discovery]\n'
    printf 'topic = %s\n' "$(tomlstr "$(jqr '.mqtt_resolved.discovery_topic // "homeassistant"')")"
    printf 'features = %s\n' "$feats"
  fi

  # [cameras.pause]
  p_motion="$(aj 'pause_on_motion')"
  p_disc="$(aj 'pause_on_disconnect')"
  p_to="$(aj 'pause_motion_timeout')"
  p_mode="$(aj 'pause_mode')"
  if [ -n "$p_motion$p_disc$p_to$p_mode" ]; then
    printf '\n[cameras.pause]\n'
    [ -n "$p_motion" ] && printf 'on_motion = %s\n' "$p_motion"
    [ -n "$p_disc" ]   && printf 'on_disconnect = %s\n' "$p_disc"
    [ -n "$p_to" ]     && printf 'motion_timeout = %s\n' "$p_to"
    [ -n "$p_mode" ]   && printf 'mode = %s\n' "$(tomlstr "$p_mode")"
  fi
done
