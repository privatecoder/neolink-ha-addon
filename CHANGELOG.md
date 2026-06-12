# Changelog

Version history for the **Neolink Home Assistant add-on**
(`privatecoder/neolink-ha-addon`). The same notes are shown inside Home Assistant
from [`neolink/CHANGELOG.md`](neolink/CHANGELOG.md). Each version notes which
[`privatecoder/neolink`](https://github.com/privatecoder/neolink) image it wraps.

## 0.7.9

- Wrap neolink **0.7.7** — the *real* fix for the high-CPU / no-reconnect-after-a-drop
  bug. 0.7.8 (neolink 0.7.6) only covered one of the MQTT client's internal
  busy-loop paths, so after several hours the add-on could peg the CPU and go
  silent again right after `Connection Lost … Attempt reconnect`. 0.7.7 caps the
  MQTT poll loop's iteration rate, which structurally bounds the CPU no matter
  which internal path spins (and logs a warning if it ever engages). No config
  changes required.

## 0.7.8

- Wrap neolink **0.7.6** — fixes the high-CPU / no-reconnect bug for real. After a
  camera dropped, the add-on could sit at ~99% (or higher) CPU with its log going
  silent right after `Connection Lost … Attempt reconnect`: the camera never
  reconnected and streams stayed dead until a restart. Root cause was the MQTT
  client busy-spinning internally on a half-open broker connection (rumqttc's
  pending-request replay had a zero throttle), which pegged the CPU and starved
  the runtime so the camera-reconnect task never ran. Verified by reproduction:
  the same camera-reboot stress that used to wedge it now stays at ~1–2% CPU and
  reconnects cleanly. (The 0.7.7 bcconn/motion fixes were real but addressed
  different latent loops, not this one.) No config changes required.

## 0.7.7

- Wrap neolink **0.7.5** — fixes a connection-loss bug that pinned a CPU core at
  ~100% and wedged the runtime. The symptom was the add-on sitting at ~99% CPU
  with its log going silent right after `Connection Lost … Attempt reconnect`:
  the camera never reconnected and RTSP clients connected but got no stream until
  a restart. Camera disconnects now tear down cleanly and reconnect on their own.
  No config changes required.

## 0.7.6

- Wrap neolink **0.7.4** — the per-second RTSP heartbeat (`… HB elapsed=…`) is
  now a debug log, so the add-on's `info` log is no longer flooded.
- Fix the `RTSP port` field help text (it still said "default 8554"; now reflects
  the 8558 default and the go2rtc conflict).
- Docs: README now uses `homeassistant.local:8558`, and adds a "Viewing the
  cameras" section (WebRTC Camera + Advanced Camera Card, Generic Camera, and
  go2rtc-stream options). Added this repository changelog and a LICENSE.

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
