# Neolink Home Assistant Add-on — Design

Status: approved (2026-06-07)
Project: `neolink-ha-addon` (sibling of `neolink`, at `reolink-streaming/neolink-ha-addon/`)

## 1. Goal

Ship a Home Assistant add-on that runs [neolink](https://github.com/privatecoder/neolink)
and is **100% configurable through the Home Assistant UI** — no hand-editing of a
TOML file. Installing it should be: add the repo URL in HA → install **Neolink** →
fill in cameras in the add-on's Configuration tab → start.

It must support **non-autodiscoverable cameras added by UID + username + password**
(battery / relay / remote cameras with no routable LAN address) as a first-class
case, as well as address-based cameras.

## 2. Key decisions

| Decision | Choice |
|---|---|
| Packaging | Wrap the prebuilt **multi-arch** neolink image (no compiling in the add-on). |
| Pinned base image | `ghcr.io/privatecoder/neolink:0.7.0` (multi-arch: amd64 + aarch64). |
| Architectures | `amd64`, `aarch64`. |
| MQTT | **Auto-wire HA's MQTT** (`services: mqtt:want`), run `mqtt-rtsp`, enable MQTT discovery so entities appear automatically; broker overridable in UI. |
| Config UI | Full typed schema; advanced/noisy per-camera fields grouped under a nested `advanced:` object (approach "A + C"). |
| Networking | `host_network: true` (reliable P2P/relay UDP + RTSP). |
| RTSP port | `8554`. |

**Dependency:** the add-on wraps `ghcr.io/privatecoder/neolink:0.7.0`, which must be
published as a multi-arch manifest (the neolink `docker.yml` multi-arch workflow).
The add-on cannot be built/installed until that image exists for both arches.

## 3. Repository layout

`neolink-ha-addon/` is its own git repository (so users can add it to HA by URL).

```
neolink-ha-addon/
  repository.yaml              # HA add-on repository metadata
  README.md                   # how to add the repo + install + quick start
  neolink/                    # the add-on (slug: neolink)
    config.yaml               # manifest: meta, arch, services, ports, options, schema
    build.yaml                # build_from per arch -> pinned neolink image
    Dockerfile                # ARG BUILD_FROM; add bashio + jq; COPY + run run.sh
    run.sh                    # options.json -> /etc/neolink.toml -> exec neolink
    DOCS.md                   # rendered in the add-on "Documentation" tab
    CHANGELOG.md
    translations/en.yaml      # friendly UI labels + help text for every option
    icon.png                  # add-on icon (placeholder initially)
    logo.png                  # add-on logo (placeholder initially)
  docs/superpowers/specs/2026-06-07-neolink-ha-addon-design.md  # this file
```

`repository.yaml`:

```yaml
name: Neolink Add-ons
url: https://github.com/privatecoder/neolink-ha-addon
maintainer: privatecoder
```

## 4. Packaging (build.yaml + Dockerfile)

`build.yaml` — both arches point at the same multi-arch tag; HA pulls the matching
arch layer:

```yaml
build_from:
  amd64: ghcr.io/privatecoder/neolink:0.7.0
  aarch64: ghcr.io/privatecoder/neolink:0.7.0
```

`Dockerfile` — FROM the neolink image (already carries the gstreamer runtime + the
`neolink` binary); add `bashio` (for options + the MQTT service API) and `jq`:

```dockerfile
ARG BUILD_FROM
FROM ${BUILD_FROM}

# bashio + jq for reading add-on options and the Supervisor MQTT service
RUN apt-get update \
 && apt-get install -y --no-install-recommends jq curl bash tar \
 && apt-get clean && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /usr/lib/bashio \
 && curl -L -s "https://github.com/hassio-addons/bashio/archive/refs/tags/v0.16.2.tar.gz" \
      | tar -xzf - --strip-components=1 -C /usr/lib/bashio \
 && ln -s /usr/lib/bashio/lib/bashio.sh /usr/bin/bashio

COPY run.sh /run.sh
RUN chmod a+x /run.sh
CMD [ "/run.sh" ]
```

(Exact bashio version pinned; verified to exist at build time.)

## 5. Add-on manifest (config.yaml)

Meta + runtime:

```yaml
name: Neolink
slug: neolink
version: "0.7.0"          # tracks the wrapped neolink version
description: Bridge Reolink Baichuan (P2P) cameras to RTSP + MQTT, UI-configured.
url: https://github.com/privatecoder/neolink-ha-addon
arch: [amd64, aarch64]
init: false
startup: application
boot: auto
host_network: true
services: [mqtt:want]
map: [ssl:ro]
```

With `host_network: true` the RTSP server is reachable directly on the host at
`bind_port` (default `8554`); HA ignores `ports:` mappings under host networking, so
none are declared. (If we later switch to bridge networking, add a `ports:` map.)

`options` (defaults) and `schema` cover the full neolink surface. Optional fields use
the `?` suffix; advanced per-camera fields are grouped under `advanced:`.

```yaml
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

A UID-only camera requires only `name`, `username`, `password`, `uid` (the
non-autodiscoverable case). `uid` and `address` are mutually exclusive per camera;
run.sh validates that exactly one is set.

`translations/en.yaml` provides a human label + description for each option key so
the HA UI shows friendly text rather than raw keys.

## 6. Runtime (run.sh)

Bash + bashio. Steps:

1. `RUST_LOG` from `log_level` (e.g. `info`, or `debug,neolink_core::bc_protocol::connection::udpsource=debug` when debug).
2. **Resolve MQTT.** If `mqtt.enabled`:
   - broker/port/user/pass = the `*_override` options if set; otherwise, if
     `bashio::services.available 'mqtt'`, read them from `bashio::services mqtt`
     (host, port, username, password).
   - If `mqtt.enabled` is true but no broker can be resolved (no override **and** no
     HA MQTT service), log a clear warning and continue **without** the `[mqtt]`
     block (RTSP-only). The add-on never fails to start just because MQTT is missing;
     RTSP must always come up. (Consistent with §9.)
3. **Generate `/etc/neolink.toml`:**
   - Top-level: `bind`, `bind_port`, `certificate` (if set), `tls_client_auth` (if set).
   - `[[users]]` from `rtsp_users`.
   - `[mqtt]` block (broker_addr, port, credentials) when MQTT resolved.
   - For each camera: `[[cameras]]` with `name`, `username`, `password`, `uid` **or**
     `address`, and any set scalar fields (`stream`, `channel_id`, `discovery`,
     `relay_server_region`, `connect_mode`, `permitted_users`) + the `advanced.*`
     fields. `[cameras.mqtt]` enable toggles / update intervals when set;
     `[cameras.mqtt.discovery]` with `topic = mqtt.discovery_topic` and `features =
     mqtt_discovery_features` when `mqtt.discovery` is on; `[cameras.pause]` when any
     pause field is set.
   - TOML strings are emitted with proper quoting/escaping; numeric/bool fields
     unquoted.
4. **Mode:** `mqtt-rtsp` if the `[mqtt]` block was written, else `rtsp`.
5. `exec neolink <mode> --config /etc/neolink.toml`.

At `debug` log level, echo the generated `neolink.toml` with passwords redacted.

## 7. HA option → neolink.toml mapping (summary)

| HA option | neolink.toml |
|---|---|
| `bind`, `bind_port`, `certificate`, `tls_client_auth` | top-level keys |
| `rtsp_users[]` (name/pass) | `[[users]]` (name/pass) |
| `mqtt.*` (resolved) | `[mqtt]` broker_addr/port/credentials |
| `cameras[].{name,username,password,uid,address,channel_id,stream,discovery,relay_server_region,connect_mode,permitted_users}` | `[[cameras]]` scalars |
| `cameras[].advanced.{idle_timeout_secs,relay_warm_seconds,udp_gap_skip_ms,buffer_duration,max_encryption,strict,update_time,max_discovery_retries,use_splash,splash_pattern,debug,enabled}` | `[[cameras]]` scalars |
| `cameras[].advanced.{enable_*,*_update}` | `[cameras.mqtt]` |
| `cameras[].mqtt_discovery_features` + `mqtt.discovery_topic` | `[cameras.mqtt.discovery]` features/topic |
| `cameras[].advanced.pause_*` | `[cameras.pause]` (on_motion/on_disconnect/motion_timeout/mode) |

## 8. Data flow

HA UI → `/data/options.json` → `run.sh` (bashio) → `/etc/neolink.toml` + mode →
`neolink mqtt-rtsp` → RTSP on `:8554` + MQTT publish/discovery → camera
entities/controls in HA; streams via go2rtc / generic camera / Frigate.

## 9. Error handling

- Per-camera: exactly one of `uid`/`address` required → otherwise `bashio::exit.nok`
  with the camera name and the reason.
- MQTT requested but unresolvable → warn + RTSP-only fallback (documented).
- Generated config echoed (passwords redacted) only at `debug`.
- neolink exits non-zero → HA restarts it per `startup: application`.

## 10. Testing

- `shellcheck run.sh`.
- Local arm64 (this host is Apple Silicon): build the wrapper image with a sample
  `/data/options.json` covering (a) a UID-only camera, (b) an address camera,
  (c) MQTT overrides, run `run.sh`, and assert the generated `neolink.toml` matches an
  expected fixture and that `neolink --version` / a dry start works.
- Validate `config.yaml` schema syntax.
- Manual end-to-end install in a real HA instance (owner-run; steps in README).

## 11. Out of scope (now)

- Bundling go2rtc / a built-in RTSP-to-HA camera proxy (HA users wire RTSP via
  existing integrations).
- An Ingress web UI (neolink has none).
- Auto-updating the wrapped neolink version (handled by bumping `build.yaml` +
  add-on `version` per neolink release).
- Publishing/registering the add-on repo (separate follow-up once validated).
