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
