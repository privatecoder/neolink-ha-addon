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
- Viewing in a dashboard: point the WebRTC Camera integration / Advanced Camera
  Card at the RTSP URL, e.g. `rtsp://<HA-host-ip>:8558/<camera-name>/main`. Use
  the host's LAN IP, not `homeassistant.local` (which resolves to an internal
  address that can't reach the host-network add-on).
- See the upstream docs for option meanings:
  <https://github.com/privatecoder/neolink#camera-configuration-reference>.
