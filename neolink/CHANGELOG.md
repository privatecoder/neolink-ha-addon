# Changelog

## 0.7.7-rc1

- Release candidate wrapping neolink `0.7.5-rc3`. Carries the MQTT CPU-spin work
  (a 5s backoff on the per-camera handler restart so a camera disconnect can no
  longer drive the MQTT event loop into a CPU spin, plus retain-flag preservation
  when re-queuing a failed publish) together with a round of RTSP and core
  hardening: the stream-setup phase is now bounded by a timeout and is
  cancellation-aware, so a slow or offline camera can no longer hold a GStreamer
  worker thread; stream generations own and tear down their per-client tasks and
  RTSP mounts on reconfiguration; appsrc pushes use typed outcomes; BC framing
  resync and AAC/ADPCM frame parsing are bounded against malformed input; and the
  build moves to Rust edition 2021. Intended for verification before a stable
  release.

## 0.7.6

- Wrap neolink **0.7.4** — the per-second RTSP heartbeat (`… HB elapsed=…`) is
  now a debug log, so the add-on's `info` log is no longer flooded.
- Fix the `RTSP port` field help text (it still said "default 8554"; now reflects
  the 8558 default and the go2rtc conflict).
- Docs: README now uses `homeassistant.local:8558`, and adds a "Viewing the
  cameras" section (WebRTC Camera + Advanced Camera Card, Generic Camera, and
  go2rtc-stream options). Added a repository changelog and LICENSE.

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
