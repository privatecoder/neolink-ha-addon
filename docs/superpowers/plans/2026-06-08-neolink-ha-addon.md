# Neolink Home Assistant Add-on — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Home Assistant add-on (its own repo at `reolink-streaming/neolink-ha-addon/`) that runs neolink, is 100% configurable through the HA UI, wraps the multi-arch `ghcr.io/privatecoder/neolink:0.7.0` image, and auto-wires HA MQTT + discovery.

**Architecture:** A thin wrapper image (`FROM` the neolink image + `bashio` + `jq`). `run.sh` (bashio) reads `/data/options.json`, resolves the MQTT broker (HA service or UI override), and produces an "effective options" JSON; a pure `gen-config.sh` (bash + jq, no bashio) turns that JSON into `/etc/neolink.toml`; `run.sh` then `exec`s `neolink mqtt-rtsp|rtsp`. The config-generation logic lives in `gen-config.sh` so it is unit-testable with plain bash + jq.

**Tech Stack:** Home Assistant add-on (config.yaml/build.yaml), Docker, bash, `jq`, `bashio`, `shellcheck`.

**Spec:** `docs/superpowers/specs/2026-06-07-neolink-ha-addon-design.md`

**Prerequisite (already satisfied):** `ghcr.io/privatecoder/neolink:0.7.0` is published as a multi-arch (amd64+aarch64) manifest.

---

## File structure

```
neolink-ha-addon/
  repository.yaml                 # HA add-on repository metadata
  README.md                       # add the repo + install + quick start
  .gitignore
  neolink/                        # the add-on (slug: neolink)
    config.yaml                   # manifest: meta, arch, services, options, schema
    build.yaml                    # build_from per arch -> pinned neolink image
    Dockerfile                    # ARG BUILD_FROM; add bashio + jq; COPY scripts
    run.sh                        # bashio entrypoint (MQTT resolve, mode, exec)
    gen-config.sh                 # PURE: effective-options JSON (stdin) -> neolink.toml (stdout)
    DOCS.md                       # add-on "Documentation" tab
    CHANGELOG.md
    translations/en.yaml          # UI labels/help for top-level options
    tests/
      run-tests.sh                # runs all fixture cases, diffs output
      cases/<name>/options.json   # input fixture (effective options)
      cases/<name>/expected.toml  # expected neolink.toml
  docs/superpowers/{specs,plans}/ # this plan + the spec (already committed)
```

Responsibilities: `gen-config.sh` = deterministic JSON→TOML (all tested logic). `run.sh` = HA glue (untestable parts; covered by shellcheck + integration). `config.yaml` = the UI schema. Everything else is packaging/docs.

**Commit conventions:** end commit messages with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`. All work happens in the `neolink-ha-addon` git repo (already initialised; the spec is committed).

---

## Task 1: Repo scaffolding

**Files:**
- Create: `.gitignore`
- Create: `neolink/tests/run-tests.sh`

- [ ] **Step 1: Create `.gitignore`**

```gitignore
*.swp
.DS_Store
/tmp/
```

- [ ] **Step 2: Create the test runner `neolink/tests/run-tests.sh`**

```bash
#!/usr/bin/env bash
# Runs every fixture case under tests/cases/ and diffs gen-config.sh output
# against the expected TOML. Cases whose name starts with "fail-" must exit
# non-zero instead.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
gen="$here/../gen-config.sh"
fail=0
for dir in "$here"/cases/*/; do
  name="$(basename "$dir")"
  if [[ "$name" == fail-* ]]; then
    if out="$("$gen" < "$dir/options.json" 2>/dev/null)"; then
      echo "FAIL $name: expected non-zero exit"; fail=1
    else
      echo "ok   $name (rejected as expected)"
    fi
    continue
  fi
  got="$("$gen" < "$dir/options.json")"
  if diff -u "$dir/expected.toml" <(printf '%s\n' "$got") >/dev/null; then
    echo "ok   $name"
  else
    echo "FAIL $name:"; diff -u "$dir/expected.toml" <(printf '%s\n' "$got"); fail=1
  fi
done
exit "$fail"
```

- [ ] **Step 3: Make it executable and commit**

```bash
chmod +x neolink/tests/run-tests.sh
git add .gitignore neolink/tests/run-tests.sh
git commit -m "chore: scaffold add-on repo + test runner

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `gen-config.sh` — server (top-level) keys

**Files:**
- Create: `neolink/gen-config.sh`
- Test: `neolink/tests/cases/server-only/{options.json,expected.toml}`

- [ ] **Step 1: Write the failing test fixture**

`neolink/tests/cases/server-only/options.json`:
```json
{ "bind": "0.0.0.0", "bind_port": 8554, "certificate": "/ssl/neolink.pem", "tls_client_auth": "require" }
```

`neolink/tests/cases/server-only/expected.toml`:
```toml
bind = "0.0.0.0"
bind_port = 8554
certificate = "/ssl/neolink.pem"
tls_client_auth = "require"
```

- [ ] **Step 2: Run the tests; verify this case fails**

Run: `bash neolink/tests/run-tests.sh`
Expected: FAIL (gen-config.sh does not exist yet).

- [ ] **Step 3: Create `neolink/gen-config.sh` with the helper + server section**

```bash
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
```

- [ ] **Step 4: Make executable, run tests; verify pass**

Run: `chmod +x neolink/gen-config.sh && bash neolink/tests/run-tests.sh`
Expected: `ok   server-only`

- [ ] **Step 5: Commit**

```bash
git add neolink/gen-config.sh neolink/tests/cases/server-only
git commit -m "feat(gen-config): emit server top-level keys

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: `gen-config.sh` — `[[users]]`

**Files:**
- Modify: `neolink/gen-config.sh` (append users section)
- Test: `neolink/tests/cases/with-users/{options.json,expected.toml}`

- [ ] **Step 1: Write the failing test fixture**

`with-users/options.json`:
```json
{ "rtsp_users": [ { "name": "me", "pass": "mepass" }, { "name": "guest", "pass": "g\"p" } ] }
```

`with-users/expected.toml`:
```toml
bind = "0.0.0.0"
bind_port = 8554

[[users]]
name = "me"
pass = "mepass"

[[users]]
name = "guest"
pass = "g\"p"
```

- [ ] **Step 2: Run tests; verify `with-users` fails** (`bash neolink/tests/run-tests.sh`).

- [ ] **Step 3: Append the users section to `gen-config.sh`** (after the server section):

```bash
# --- RTSP users ---
n_users="$(jqr '(.rtsp_users // []) | length')"
for ((i=0; i<n_users; i++)); do
  uname="$(jqr ".rtsp_users[$i].name")"
  upass="$(jqr ".rtsp_users[$i].pass // \"\"")"
  printf '\n[[users]]\n'
  printf 'name = %s\n' "$(tomlstr "$uname")"
  printf 'pass = %s\n' "$(tomlstr "$upass")"
done
```

- [ ] **Step 4: Run tests; verify pass** (`ok with-users`, `ok server-only`).

- [ ] **Step 5: Commit**

```bash
git add neolink/gen-config.sh neolink/tests/cases/with-users
git commit -m "feat(gen-config): emit [[users]]

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: `gen-config.sh` — `[mqtt]`

The MQTT broker is resolved by `run.sh` into a `mqtt_resolved` object before this runs.

**Files:**
- Modify: `neolink/gen-config.sh` (append mqtt section)
- Test: `neolink/tests/cases/with-mqtt/{options.json,expected.toml}`

- [ ] **Step 1: Write the failing test fixture**

`with-mqtt/options.json`:
```json
{ "mqtt_resolved": { "enabled": true, "broker": "core-mosquitto", "port": 1883, "username": "addons", "password": "secret" } }
```

`with-mqtt/expected.toml`:
```toml
bind = "0.0.0.0"
bind_port = 8554

[mqtt]
broker_addr = "core-mosquitto"
port = 1883
credentials = ["addons", "secret"]
```

- [ ] **Step 2: Run tests; verify `with-mqtt` fails.**

- [ ] **Step 3: Append the mqtt section to `gen-config.sh`:**

```bash
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
```

- [ ] **Step 4: Run tests; verify pass.**

- [ ] **Step 5: Commit**

```bash
git add neolink/gen-config.sh neolink/tests/cases/with-mqtt
git commit -m "feat(gen-config): emit [mqtt] from resolved broker

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: `gen-config.sh` — `[[cameras]]` scalars + uid/address validation

**Files:**
- Modify: `neolink/gen-config.sh` (append cameras loop)
- Test: `neolink/tests/cases/uid-camera/`, `address-camera/`, `fail-both-addr-uid/`, `fail-neither/`

- [ ] **Step 1: Write the failing test fixtures**

`uid-camera/options.json`:
```json
{ "cameras": [ { "name": "Front Door", "username": "admin", "password": "pw", "uid": "ABCDEF0123456789",
  "stream": "Both", "discovery": "relay", "connect_mode": "on_demand", "relay_server_region": "Europe (France)",
  "permitted_users": ["me"], "advanced": { "idle_timeout_secs": 0, "buffer_duration": 3000, "max_encryption": "aes", "debug": false } } ] }
```

`uid-camera/expected.toml`:
```toml
bind = "0.0.0.0"
bind_port = 8554

[[cameras]]
name = "Front Door"
username = "admin"
password = "pw"
uid = "ABCDEF0123456789"
stream = "Both"
discovery = "relay"
connect_mode = "on_demand"
relay_server_region = "Europe (France)"
channel_id = 0
permitted_users = ["me"]
buffer_duration = 3000
idle_timeout_secs = 0
max_encryption = "aes"
debug = false
```

`address-camera/options.json`:
```json
{ "cameras": [ { "name": "Shed", "username": "admin", "password": "pw", "address": "192.168.1.10:9000" } ] }
```

`address-camera/expected.toml`:
```toml
bind = "0.0.0.0"
bind_port = 8554

[[cameras]]
name = "Shed"
username = "admin"
password = "pw"
address = "192.168.1.10:9000"
channel_id = 0
```

`fail-both-addr-uid/options.json`:
```json
{ "cameras": [ { "name": "Bad", "username": "a", "uid": "X", "address": "1.2.3.4:9000" } ] }
```

`fail-neither/options.json`:
```json
{ "cameras": [ { "name": "Bad", "username": "a" } ] }
```

> Note on ordering: every camera scalar is emitted **before** any `[cameras.*]` sub-table (TOML requirement). `channel_id` is always emitted (defaults to 0) to anchor the scalar block. The field order above is exactly what the implementation in Step 3 produces — keep fixtures in sync with that order.

- [ ] **Step 2: Run tests; verify the four new cases fail.**

- [ ] **Step 3: Append the cameras loop to `gen-config.sh`:**

```bash
# --- Cameras ---
n_cams="$(jqr '(.cameras // []) | length')"
for ((i=0; i<n_cams; i++)); do
  cam="$(jq -c ".cameras[$i]" <<<"$OPTS")"
  cj() { jq -r "$1" <<<"$cam"; }          # raw from camera
  cname="$(cj '.name')"
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
  aj() { jq -r --arg k "$1" '.[$k] // empty' <<<"$adv"; }
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
done
```

> The numeric/string/bool advanced groups are emitted in that fixed order; the `uid-camera/expected.toml` reflects it (`buffer_duration`, then `idle_timeout_secs`, then `max_encryption`, then `debug`). Only fields present in `advanced` are emitted.

- [ ] **Step 4: Run tests; verify `uid-camera`, `address-camera` pass and both `fail-*` cases are rejected.**

- [ ] **Step 5: Commit**

```bash
git add neolink/gen-config.sh neolink/tests/cases/uid-camera neolink/tests/cases/address-camera neolink/tests/cases/fail-both-addr-uid neolink/tests/cases/fail-neither
git commit -m "feat(gen-config): emit [[cameras]] scalars + validate uid/address

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: `gen-config.sh` — `[cameras.mqtt]` + `[cameras.mqtt.discovery]`

**Files:**
- Modify: `neolink/gen-config.sh` (inside the camera loop, after the scalar/advanced blocks)
- Test: `neolink/tests/cases/camera-mqtt/`

- [ ] **Step 1: Write the failing test fixture**

`camera-mqtt/options.json`:
```json
{ "mqtt_resolved": { "enabled": true, "broker": "b", "port": 1883, "discovery": true, "discovery_topic": "homeassistant" },
  "cameras": [ { "name": "Cam", "username": "admin", "uid": "X",
    "mqtt_discovery_features": ["motion","battery"],
    "advanced": { "enable_preview": false, "battery_update": 5000 } } ] }
```

`camera-mqtt/expected.toml`:
```toml
bind = "0.0.0.0"
bind_port = 8554

[mqtt]
broker_addr = "b"
port = 1883

[[cameras]]
name = "Cam"
username = "admin"
uid = "X"
channel_id = 0

[cameras.mqtt]
enable_preview = false
battery_update = 5000

[cameras.mqtt.discovery]
topic = "homeassistant"
features = ["motion","battery"]
```

- [ ] **Step 2: Run tests; verify `camera-mqtt` fails.**

- [ ] **Step 3: Append, inside the camera loop (after the advanced bool block, before the loop's closing `done`):**

```bash
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
```

> `[cameras.mqtt.discovery]` after `[cameras.mqtt]` is valid TOML; if only discovery is present, emitting `[cameras.mqtt.discovery]` alone implicitly creates `[cameras.mqtt]` (neolink fills the rest from defaults).

- [ ] **Step 4: Run tests; verify pass.**

- [ ] **Step 5: Commit**

```bash
git add neolink/gen-config.sh neolink/tests/cases/camera-mqtt
git commit -m "feat(gen-config): emit per-camera [cameras.mqtt] and discovery

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 7: `gen-config.sh` — `[cameras.pause]`

**Files:**
- Modify: `neolink/gen-config.sh` (camera loop, after the discovery block)
- Test: `neolink/tests/cases/camera-pause/`

- [ ] **Step 1: Write the failing test fixture**

`camera-pause/options.json`:
```json
{ "cameras": [ { "name": "Cam", "username": "admin", "uid": "X",
  "advanced": { "pause_on_motion": true, "pause_on_disconnect": true, "pause_motion_timeout": 2.5, "pause_mode": "still" } } ] }
```

`camera-pause/expected.toml`:
```toml
bind = "0.0.0.0"
bind_port = 8554

[[cameras]]
name = "Cam"
username = "admin"
uid = "X"
channel_id = 0

[cameras.pause]
on_motion = true
on_disconnect = true
motion_timeout = 2.5
mode = "still"
```

- [ ] **Step 2: Run tests; verify `camera-pause` fails.**

- [ ] **Step 3: Append, inside the camera loop (after the discovery block, before `done`):**

```bash
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
```

- [ ] **Step 4: Run tests; verify all cases pass.**

- [ ] **Step 5: Lint the generator and commit**

```bash
shellcheck neolink/gen-config.sh neolink/tests/run-tests.sh
git add neolink/gen-config.sh neolink/tests/cases/camera-pause
git commit -m "feat(gen-config): emit [cameras.pause]

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
Expected: shellcheck reports no errors (fix any it raises, e.g. add `# shellcheck disable=` only with justification).

---

## Task 8: `run.sh` — bashio entrypoint

`run.sh` is HA-coupled (needs the Supervisor for MQTT service + options), so it is verified with shellcheck here and exercised in the Task 12 integration build.

**Files:**
- Create: `neolink/run.sh`

- [ ] **Step 1: Create `neolink/run.sh`**

```bash
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
  broker="$(bashio::config 'mqtt.broker_override')"
  port="$(bashio::config 'mqtt.port_override')"
  user="$(bashio::config 'mqtt.username_override')"
  pass="$(bashio::config 'mqtt.password_override')"
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
  sed -E 's/(password|pass|credentials)[^=]*=.*/\1 = <redacted>/I' "$CONFIG" | bashio::log.info
fi

# Mode: mqtt-rtsp if we wrote an [mqtt] block, else rtsp.
mode="rtsp"
grep -q '^\[mqtt\]' "$CONFIG" && mode="mqtt-rtsp"
bashio::log.info "Starting neolink in '${mode}' mode."
exec neolink "$mode" --config "$CONFIG"
```

- [ ] **Step 2: Lint with shellcheck**

Run: `shellcheck -e SC1091 neolink/run.sh`
Expected: no errors (SC1091 = the bashio source path, not resolvable on the host).

- [ ] **Step 3: Commit**

```bash
git add neolink/run.sh
git commit -m "feat: bashio entrypoint (MQTT resolve, config gen, exec)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 9: Add-on manifest `config.yaml`

**Files:**
- Create: `neolink/config.yaml`

- [ ] **Step 1: Create `neolink/config.yaml`**

```yaml
name: Neolink
slug: neolink
version: "0.7.0"
description: Bridge Reolink Baichuan (P2P) cameras to RTSP + MQTT, configured from the UI.
url: https://github.com/privatecoder/neolink-ha-addon
arch:
  - amd64
  - aarch64
init: false
startup: application
boot: auto
host_network: true
services:
  - mqtt:want
map:
  - ssl:ro
options:
  log_level: info
  bind: "0.0.0.0"
  bind_port: 8554
  mqtt:
    enabled: true
    discovery: true
    discovery_topic: homeassistant
  cameras:
    - name: Camera01
      username: admin
      password: ""
      uid: ""
schema:
  log_level: list(trace|debug|info|warn|error)
  bind: str
  bind_port: port
  certificate: str?
  tls_client_auth: list(none|request|require)?
  rtsp_users:
    - name: str
      pass: password
  mqtt:
    enabled: bool
    discovery: bool
    discovery_topic: str
    broker_override: str?
    port_override: port?
    username_override: str?
    password_override: password?
  cameras:
    - name: str
      username: str
      password: password?
      uid: str?
      address: str?
      channel_id: int(0,31)?
      stream: list(Main|Sub|Both|All|Extern|None)?
      discovery: list(local|remote|map|relay|cellular|debug)?
      relay_server_region: str?
      connect_mode: list(always|on_demand)?
      permitted_users:
        - str?
      mqtt_discovery_features:
        - list(floodlight|camera|motion|led|ir|reboot|pt|battery|siren)?
      advanced:
        enabled: bool?
        idle_timeout_secs: int(0,86400)?
        relay_warm_seconds: int(0,3600)?
        udp_gap_skip_ms: int(0,5000)?
        buffer_duration: int(1,15000)?
        max_encryption: list(none|bcencrypt|aes)?
        strict: bool?
        update_time: bool?
        max_discovery_retries: int?
        use_splash: bool?
        splash_pattern: str?
        debug: bool?
        enable_motion: bool?
        enable_light: bool?
        enable_battery: bool?
        enable_preview: bool?
        enable_floodlight: bool?
        battery_update: int(500,)?
        preview_update: int(500,)?
        floodlight_update: int(500,)?
        pause_on_motion: bool?
        pause_on_disconnect: bool?
        pause_motion_timeout: float?
        pause_mode: list(black|still|test|none)?
```

- [ ] **Step 2: Validate it parses as YAML**

Run: `python3 -c "import sys; print('ok')" ; yq '.slug' neolink/config.yaml` (or `ruby -ryaml -e 'YAML.load_file("neolink/config.yaml"); puts "ok"'`)
Expected: prints `neolink` / `ok` with no parse error.

- [ ] **Step 3: Commit**

```bash
git add neolink/config.yaml
git commit -m "feat: add-on manifest with full UI schema (A+C)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 10: `build.yaml` + `Dockerfile`

**Files:**
- Create: `neolink/build.yaml`
- Create: `neolink/Dockerfile`

- [ ] **Step 1: Create `neolink/build.yaml`**

```yaml
build_from:
  amd64: ghcr.io/privatecoder/neolink:0.7.0
  aarch64: ghcr.io/privatecoder/neolink:0.7.0
```

- [ ] **Step 2: Create `neolink/Dockerfile`**

```dockerfile
ARG BUILD_FROM
FROM ${BUILD_FROM}

# bashio (options + MQTT service API) and jq (config generation)
ARG BASHIO_VERSION=v0.16.2
RUN apt-get update \
 && apt-get install -y --no-install-recommends jq curl bash ca-certificates tar \
 && apt-get clean && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /usr/lib/bashio \
 && curl -fL -s "https://github.com/hassio-addons/bashio/archive/refs/tags/${BASHIO_VERSION}.tar.gz" \
      | tar -xzf - --strip-components=1 -C /usr/lib/bashio \
 && ln -sf /usr/lib/bashio/lib/bashio.sh /usr/bin/bashio

COPY gen-config.sh /usr/bin/neolink-gen-config
COPY run.sh /run.sh
RUN chmod a+x /usr/bin/neolink-gen-config /run.sh

CMD [ "/run.sh" ]
```

- [ ] **Step 3: Verify the pinned bashio tag exists**

Run: `curl -fsI "https://github.com/hassio-addons/bashio/releases/tag/v0.16.2" >/dev/null && echo ok || echo "pick a valid tag from https://github.com/hassio-addons/bashio/releases"`
If not `ok`, set `BASHIO_VERSION` to the latest release tag and update this step.

- [ ] **Step 4: Commit**

```bash
git add neolink/build.yaml neolink/Dockerfile
git commit -m "feat: wrapper image (pinned neolink 0.7.0 + bashio + jq)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 11: Docs (`repository.yaml`, `README.md`, `DOCS.md`, `CHANGELOG.md`, `translations/en.yaml`)

**Files:**
- Create: `repository.yaml`, `README.md`, `neolink/DOCS.md`, `neolink/CHANGELOG.md`, `neolink/translations/en.yaml`

- [ ] **Step 1: Create `repository.yaml`**

```yaml
name: Neolink Add-ons
url: https://github.com/privatecoder/neolink-ha-addon
maintainer: privatecoder
```

- [ ] **Step 2: Create top-level `README.md`**

````markdown
# Neolink Home Assistant Add-on

Run [neolink](https://github.com/privatecoder/neolink) as a Home Assistant add-on
to bridge Reolink "Baichuan" (P2P) cameras to RTSP, with MQTT control/discovery —
all configured from the Home Assistant UI.

## Install

1. Settings → Add-ons → Add-on Store → ⋮ → **Repositories**.
2. Add `https://github.com/privatecoder/neolink-ha-addon` and reload.
3. Install **Neolink**, open **Configuration**, add your cameras, and start it.

## Cameras

Each camera needs a `name`, `username`, `password`, and **either** a `uid`
(P2P/relay — for battery/remote cameras) **or** an `address` (`ip:9000` on your
LAN). Advanced per-camera options live under the `advanced` section.

## MQTT

With the Mosquitto broker add-on installed, MQTT is auto-wired and camera
entities appear in Home Assistant via MQTT discovery. Override the broker in the
add-on options if you use an external one.

## RTSP

The RTSP server is exposed on the host at the configured `bind_port` (default
`8554`): `rtsp://<home-assistant-host>:8554/<camera-name>/main`.
````

- [ ] **Step 3: Create `neolink/DOCS.md`** (shown in the add-on's Documentation tab):

````markdown
# Neolink

Bridges Reolink Baichuan/P2P cameras to RTSP + MQTT.

## Options

- **log_level** — `trace|debug|info|warn|error`.
- **bind / bind_port** — RTSP server bind address / port (host network).
- **certificate / tls_client_auth** — optional RTSP TLS (use `rtsps://`).
- **rtsp_users** — RTSP login accounts; omit for anonymous access.
- **mqtt** — `enabled`/`discovery`/`discovery_topic` and optional broker
  overrides. Empty overrides = use the Home Assistant MQTT service.
- **cameras** — one entry per camera:
  - `name`, `username`, `password`
  - `uid` (P2P/relay) **or** `address` (`ip:9000`) — exactly one
  - `stream`, `discovery`, `connect_mode`, `relay_server_region`,
    `permitted_users`, `mqtt_discovery_features`
  - `advanced` — timeouts, buffer, encryption, splash, per-camera MQTT toggles,
    pause behaviour.

## Notes

- Battery/remote cameras: use `uid` with `discovery = relay` (default) and
  `connect_mode = on_demand`.
- See the upstream docs for option meanings:
  <https://github.com/privatecoder/neolink#camera-configuration-reference>.
````

- [ ] **Step 4: Create `neolink/CHANGELOG.md`**

```markdown
# Changelog

## 0.7.0

- Initial release. Wraps neolink 0.7.0 (multi-arch amd64 + aarch64).
- 100% UI-configurable; auto-wires Home Assistant MQTT + discovery.
```

- [ ] **Step 5: Create `neolink/translations/en.yaml`** (UI labels for top-level options):

```yaml
configuration:
  log_level:
    name: Log level
    description: Verbosity of the add-on log.
  bind:
    name: Bind address
    description: Interface the RTSP server binds to (0.0.0.0 = all).
  bind_port:
    name: RTSP port
    description: Port for the RTSP server (default 8554).
  certificate:
    name: TLS certificate
    description: Path to a PEM (cert + key) to enable rtsps://. Optional.
  tls_client_auth:
    name: TLS client auth
    description: Require a client certificate (none / request / require).
  rtsp_users:
    name: RTSP users
    description: Username/password accounts for RTSP. Empty = anonymous.
  mqtt:
    name: MQTT
    description: MQTT integration. Leave overrides empty to use the HA broker.
  cameras:
    name: Cameras
    description: One entry per camera. Use uid (P2P) or address (ip:9000).
network:
  8554/tcp: RTSP server
```

- [ ] **Step 6: Commit**

```bash
git add repository.yaml README.md neolink/DOCS.md neolink/CHANGELOG.md neolink/translations/en.yaml
git commit -m "docs: repository metadata, README, DOCS, changelog, translations

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 12: Integration — local build + smoke test

This host is Apple Silicon (arm64), so `linux/arm64` builds natively.

**Files:** none (verification only)

- [ ] **Step 1: Run the full unit test suite + shellcheck**

Run:
```bash
bash neolink/tests/run-tests.sh
shellcheck neolink/gen-config.sh neolink/tests/run-tests.sh
shellcheck -e SC1091 neolink/run.sh
```
Expected: all cases `ok`, shellcheck clean.

- [ ] **Step 2: Build the wrapper image locally (arm64)**

Run:
```bash
docker build --platform linux/arm64 \
  --build-arg BUILD_FROM=ghcr.io/privatecoder/neolink:0.7.0 \
  -t neolink-addon:test neolink/
```
Expected: build succeeds (pulls the arm64 layer of the multi-arch base, installs bashio+jq).

- [ ] **Step 3: Smoke-test config generation in the image**

Run:
```bash
echo '{"bind":"0.0.0.0","bind_port":8554,"mqtt_resolved":{"enabled":true,"broker":"b","port":1883,"discovery":true,"discovery_topic":"homeassistant"},"cameras":[{"name":"Cam","username":"admin","password":"pw","uid":"ABCDEF0123456789","mqtt_discovery_features":["motion"]}]}' \
  | docker run --rm -i neolink-addon:test neolink-gen-config
```
Expected: prints a valid `neolink.toml` with `[mqtt]`, `[[cameras]]`, and `[cameras.mqtt.discovery]`.

- [ ] **Step 4: Confirm the wrapped binary runs**

Run: `docker run --rm neolink-addon:test neolink --version`
Expected: `neolink 0.7.0`.

- [ ] **Step 5: Final commit (tag the add-on baseline)**

```bash
git add -A
git commit -m "test: integration build + smoke test pass" --allow-empty
```

---

## Self-review

**Spec coverage:**
- 100% UI config / full typed schema + grouped advanced → Task 9 (schema), Tasks 2–7 (generation). ✅
- UID **and** address cameras, exactly-one validation → Task 5. ✅
- Auto-wire HA MQTT + discovery, broker override → Task 8 (resolve), Task 4 & 6 (emit). ✅
- Wrap pinned multi-arch `0.7.0`, amd64+aarch64 → Task 10, config.yaml `arch` (Task 9). ✅
- host_network, services mqtt:want, ssl map, RTSP 8554 → Task 9. ✅
- Mode selection mqtt-rtsp/rtsp; RUST_LOG; redacted debug echo → Task 8. ✅
- Error handling (uid/address, MQTT fallback) → Task 5, Task 8. ✅
- Testing (shellcheck, fixtures, local arm64 build) → Tasks 2–7, 12. ✅
- Repo files (repository.yaml, README, DOCS, CHANGELOG, translations) → Task 11. ✅

**Placeholder scan:** No TBD/TODO. Icon/logo PNGs are intentionally deferred (HA shows a default; spec marked them placeholder) — not required for function; add later if desired.

**Type/name consistency:** `gen-config.sh` reads `.mqtt_resolved.{enabled,broker,port,username,password,discovery,discovery_topic}`; `run.sh` produces exactly those keys (Task 8 jq). Camera advanced keys in fixtures match the `aj`-read keys and the `config.yaml` schema (`enable_*`, `*_update`, `pause_*`, etc.). The generator is invoked as `neolink-gen-config` (symlink path from Task 10) in run.sh and Task 12; source file is `gen-config.sh`.

**Known follow-ups (out of scope):** add icon/logo PNGs; publish/announce the repo; CI to lint the add-on; bump flow when neolink releases a new version (bump `build.yaml` tag + `config.yaml`/`CHANGELOG` version).
