# Changelog

## 0.7.8-rc2

- Diagnostic release candidate wrapping neolink `0.7.6-rc2`. Raises the offline
  keepalive rate to ~10 fps (a 1 fps placeholder can be treated as a stalled stream)
  and adds logging of the keepalive push outcomes, to pin down why a viewer can still
  drop the session during a long outage. Same behaviour as rc1 otherwise.

## 0.7.8-rc1

- Release candidate wrapping neolink `0.7.6-rc1`. Adds a keepalive so that opening a
  camera that is currently offline keeps the live view's session alive: a low-rate
  placeholder image is sent until the camera (re)connects, at which point the real
  video appears on its own — without closing and reopening the card. The placeholder
  is generated once per camera resolution and matches it exactly, so the switch to
  live video is seamless. If it can't be generated, the stream simply falls back to
  the previous behaviour. Intended for verification before a stable release.

## 0.7.7

Wraps neolink **0.7.5**. The headline is the fix for the high-CPU / no-reconnect
bug after a camera drop, plus a round of RTSP and core hardening. Changes since
0.7.6 (which wrapped neolink 0.7.4):

- **High CPU / no-reconnect after a camera drops, fixed.** The add-on could peg the
  CPU and go silent right after `Connection Lost … Attempt reconnect`, with the
  camera never coming back until a restart. The cause was the per-camera MQTT
  handler restarting in a tight loop with no backoff, flooding the broker and
  spinning the MQTT client until the runtime starved. The handler now backs off
  before restarting, a spinning connection is dropped and reconnected, and a
  poll-rate cap acts as a failsafe.
- **Snappier, more robust live view.** Once a stream's codec has been seen, opening
  it again builds and serves the pipeline immediately while the camera connects in
  the background, and a brief camera drop resumes into the same session without the
  card reconnecting. RTSP client setup is time-bounded and self-cleaning, so a slow
  or offline camera can no longer stall the server or leave stale mounts.
- **Hardened against malformed camera data** — bounded protocol resync and stricter
  audio-frame parsing, plus recovery of dropped packets at stream start.
- **Build** — wraps neolink built on Rust edition 2021, with a reproducible Docker
  base.
- **Docs** — added a Home Assistant integration guide (go2rtc / WebRTC / MSE / HLS,
  H264/H265 + AAC, and the camera-side I-frame-interval and CBR/VBR trade-offs).

No add-on configuration changes are required.

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
