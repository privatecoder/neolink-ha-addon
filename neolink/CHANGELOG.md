# Changelog

## 0.7.5

- **Default RTSP port changed `8554` → `8558`.** Home Assistant's built-in
  go2rtc already listens on `8554`, so neolink couldn't bind it — the RTSP
  server looked started but was unreachable, and cards got *"wrong response on
  DESCRIBE"* from the go2rtc squatting the port. If you previously set `8554`
  explicitly, change it (and your stream URLs) to `8558` or another free port.
- Wrap neolink **0.7.3**, which now logs a clear error if the RTSP port is
  already in use instead of silently serving nothing.

## 0.7.4

- Wrap neolink **0.7.2** — a single lost UDP packet no longer drops the camera
  connection (the BC control framing now resyncs instead of forcing a
  reconnect + re-login every few minutes on high-bitrate remote streams), and
  the "Europe (United Kingdom)" relay region now pins correctly.

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
