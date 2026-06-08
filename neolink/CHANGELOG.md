# Changelog

## 0.7.3

- Wrap neolink **0.7.1** (skips re-probing battery/floodlight on cameras that
  lack them — no more repeated `Task Error` lines for non-battery cameras).
- `relay_server_region` is now a **dropdown** of the known Reolink relay regions
  instead of a free-text field. (UK pinning uses the corrected
  "Europe (United Kingdom)" spelling; with an older wrapped neolink image it
  falls back to trying all relay servers, which still connects.)

## 0.7.2

- Add an empty `rtsp_users: []` default. HA add-on schema requires every
  top-level key to be present unless it has a default or is an optional scalar;
  the `rtsp_users` list had neither, so saving failed with "Missing option
  'rtsp_users' in root". Still wraps neolink 0.7.0.

## 0.7.1

- Flatten per-camera advanced options to direct optional fields. Home Assistant
  add-on schema cannot mark a nested dictionary optional, so the previous
  `advanced` group made it mandatory and rejected cameras ("Missing option
  'advanced'"). Same options, now hidden behind the per-camera "show unused
  optional configuration options" toggle. Still wraps neolink 0.7.0.

## 0.7.0

- Initial release. Wraps neolink 0.7.0 (multi-arch amd64 + aarch64).
- 100% UI-configurable; auto-wires Home Assistant MQTT + discovery.
