# Neolink

Bridges Reolink Baichuan/P2P cameras to RTSP + MQTT.

## Options

- **log_level** — `trace|debug|info|warn|error`.
- **bind / bind_port** — RTSP server bind address / port (host network).
  Defaults to `0.0.0.0:8558`. **Do not use port 8554:** Home Assistant's
  built-in go2rtc already listens on `8554`, so neolink can't bind it — you'd
  get an RTSP server that looks started but is unreachable (and consumers get
  *"wrong response on DESCRIBE"* from the go2rtc that owns the port). Streams
  are at `rtsp://<HA-host-ip>:8558/<camera-name>/main` (or `/sub`).
- **offline_timeout_secs** — global default for how long a viewer keeps seeing the
  black + silent-audio placeholder while a camera is offline before that viewer's
  stream is dropped. `0` = never (default; the placeholder is held indefinitely and
  recovers on its own when the camera returns). Set N seconds to instead drop the
  viewer so Home Assistant can mark the camera unavailable / trigger automations; it
  must exceed your camera's reboot time (values 1-59 are raised to a 60s floor).
  Override per camera via the camera's optional `offline_timeout_secs`.
- **certificate / tls_client_auth** — optional RTSP TLS (use `rtsps://`).
- **rtsp_users** — RTSP login accounts; omit for anonymous access.
- **mqtt** — `enabled`/`discovery`/`discovery_topic` and optional broker
  overrides. Empty overrides = use the Home Assistant MQTT service.
- **cameras** — one entry per camera:
  - `name`, `username`, `password`
  - `uid` (P2P/relay) **or** `address` (`ip:9000`) — exactly one
  - `stream`, `discovery`, `connect_mode`, `relay_server_region`,
    `permitted_users`, `mqtt_discovery_features`
  - optional advanced fields (timeouts, buffer, encryption, splash, per-camera
    MQTT toggles, pause behaviour) — hidden under the camera's *"Show unused
    optional configuration options"* toggle until you need them.

## Notes

- Battery/remote cameras: use `uid` with `discovery = relay` (default) and
  `connect_mode = on_demand`.
- Offline / reboot recovery: a viewer opening an offline camera (or watching one
  that reboots) sees a black placeholder and returns to live on its own when the
  camera is back — no reconnect. Held indefinitely by default; cap it with
  `offline_timeout_secs` (global or per-camera) if you'd rather the stream end so HA
  marks the camera unavailable.
- Viewing in a dashboard: point the WebRTC Camera integration / Advanced Camera
  Card at the RTSP URL, e.g. `rtsp://<HA-host-ip>:8558/<camera-name>/main`. Use
  the host's LAN IP, not `homeassistant.local` (which resolves to an internal
  address that can't reach the host-network add-on).
- See the upstream docs for option meanings:
  <https://github.com/privatecoder/neolink#camera-configuration-reference>.
