#!/usr/bin/env bash
# Pure generator: reads an "effective options" JSON document on stdin and writes
# a neolink.toml to stdout. No bashio / Supervisor dependency (unit-testable).
set -euo pipefail

OPTS="$(cat)"

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
