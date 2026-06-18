# Changelog

## 0.7.13

Wraps neolink **0.7.11**. Bug-fix release: fixes the truncated camera preview image
and removes a stale MQTT topic.

- The camera preview image (MQTT `status/preview`, shown by the Home Assistant camera
  entity) is no longer cut off after the top portion. Neolink previously published a
  snapshot even when part of it was lost in transit; it now retries the snapshot and
  keeps the last good frame instead of publishing a truncated image.
- The unused `status/notification` MQTT topic — a leftover from the push-notification
  feature removed upstream — is cleared and no longer published. Nothing read it, so no
  configuration changes are required.

## 0.7.12

Wraps neolink **0.7.10**. Adds doorbell (visitor) button-press detection over MQTT.

- Cameras with a doorbell can now report each press to Home Assistant. Enable the
  per-camera **enable_doorbell** option (off by default) and add **doorbell** to a
  camera's MQTT discovery features. Each press is published as a discrete event to
  `neolink/{camera}/status/doorbell` and exposed as a Home Assistant event entity
  (`device_class` doorbell). Doorbell presses are reported separately from motion,
  and cameras without a doorbell are unaffected.

No add-on configuration changes are required to keep today's behaviour.

## 0.7.11

Wraps neolink **0.7.9**. Stability fix that prevents live views from dropping after
hours of continuous operation.

- Under the hood, a single slow or stalled viewer (for example a card that stopped
  keeping up with a high-bitrate camera) could block the camera's control channel,
  which made the camera drop the session and forced a reconnect cycle for everyone.
  Neolink now keeps that control channel responsive regardless of how any one viewer
  is behaving, and an audio buffer that fills up no longer tears down the whole
  stream. Long-running views stay up.

No add-on configuration changes are required to keep today's behaviour.

## 0.7.10

Wraps neolink **0.7.8**. Adds a **persistent stream-type cache** so a known
camera's offline placeholder survives an add-on restart.

- New **Stream cache path** option (`stream_cache_path`), defaulting to
  `/data/stream-cache.json` (the add-on's persistent volume). Neolink learns each
  camera's stream type on first connection and now persists it there, so after the
  add-on restarts a card that opens while a known camera is still offline gets the
  "stream not ready" placeholder immediately instead of nothing. Clear the option
  to disable persistence (in-memory only).
- Cached types are a hint, not the truth: on the first connection they are
  reconciled against the live camera. If the codec or audio format changed while
  the add-on was down, the cache is refreshed and the view reconnects to a correct
  pipeline.
- Also from neolink 0.7.8: a defensive fallback that serves the splash placeholder
  (instead of failing with GStreamer errors) when a client connects before any
  camera codec has been learned and the camera is unreachable.

No add-on configuration changes are required to keep today's behaviour.

## 0.7.9

Wraps neolink **0.7.7**. Adds an **optional offline timeout** for the live view.

- By default nothing changes: when a camera is offline the placeholder is held
  indefinitely and the view recovers on its own when the camera returns.
- New **Offline timeout (seconds)** option (`offline_timeout_secs`) lets you instead
  have a viewer's stream **end** after N seconds offline — so Home Assistant marks the
  camera unavailable and can alert you — rather than holding the placeholder forever.
  Set it globally in the add-on options, or per camera (a camera's value overrides the
  global; unset inherits it). `0` = never (default); any value must exceed your
  camera's reboot time (a 60 s floor is enforced). It's per-viewer — the shared camera
  connection keeps reconnecting for any other open cards.

No add-on configuration changes are required to keep today's behaviour.

## 0.7.8

Wraps neolink **0.7.6**. Builds on 0.7.7 with offline-recovery for the live view.

- **The live view survives a camera reboot, and opens even while the camera is
  offline.** Opening a camera that's offline — or rebooting a camera while its card is
  open — no longer fails or times out. The add-on shows a brief black placeholder, and
  once the camera is back the live picture returns **on its own, without closing and
  reopening the card**. It does this by holding the stream open with a low-rate
  placeholder (a black image plus matching silent audio) until real frames arrive.
- One thing to know: the **first** time you open a camera after the add-on (re)starts,
  the camera must be online so its stream format can be learned and cached; after that,
  offline opens and reboots recover automatically.

No add-on configuration changes are required.

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
