# Neolink Home Assistant Add-on

Run [neolink](https://github.com/privatecoder/neolink) as a Home Assistant add-on
to bridge Reolink "Baichuan" (P2P) cameras to RTSP, with MQTT control/discovery —
all configured from the Home Assistant UI.

## Install

1. Settings → Add-ons → Add-on Store → ⋮ → **Repositories**.
2. Add `https://github.com/privatecoder/neolink-ha-addon` and reload.
3. Install **Neolink**, open **Configuration**, add your cameras, and start it.

## Cameras

Each camera needs a `name`, `username`, `password`, and **either** a `uid`
(P2P/relay — for battery/remote cameras) **or** an `address` (`ip:9000` on your
LAN). Advanced per-camera options are optional fields, hidden behind the camera's
"Show unused optional configuration options" toggle until you need them.

## MQTT

With the Mosquitto broker add-on installed, MQTT is auto-wired. Camera
**control/sensor** entities (motion, battery, floodlight, switches, …) appear in
Home Assistant via MQTT discovery, plus an optional periodic-**snapshot** camera
if you enable the `camera`/`preview` discovery feature. Override the broker in
the add-on options if you use an external one.

> MQTT discovery does **not** create a live-video entity — Home Assistant has no
> discovery type for an RTSP stream. For live video, use one of the methods under
> [Viewing the cameras](#viewing-the-cameras) below.

## RTSP

The RTSP server is exposed on the host at the configured `bind_port` (default
`8558`):

```
rtsp://homeassistant.local:8558/<camera-name>/main           # full quality (often H.265)
rtsp://homeassistant.local:8558/<camera-name>/externStream   # "Balanced": H.264, mid-res
rtsp://homeassistant.local:8558/<camera-name>/sub            # lighter substream (H.264)
```

> The default is **8558**, not the usual RTSP `8554`, because Home Assistant's
> built-in go2rtc already listens on `8554` — neolink can't bind it there.
>
> `homeassistant.local` is the simplest host reference and works for consumers
> running inside Home Assistant. If your network can't resolve it, use the Home
> Assistant host's LAN IP instead (e.g. `rtsp://192.168.1.50:8558/...`).

> **Tip — the third ("extern") stream is often the best WebRTC source.** Beyond main and
> sub, Reolink cameras expose a third stream slot. On most **single-lens** cameras it's
> the app's **"Balanced"** live quality: **H.264 like the sub stream but at a higher
> resolution and bitrate** (e.g. 896×512 vs sub's 640×360). You can pick it in live view
> (the Clear / Balanced / Fluent switch), but its encoder config never appears in the
> app's Stream settings — which only show main and sub, so it's easy to miss. Since
> browsers play H.264 over WebRTC everywhere — while the
> H.265 main usually can't outside Safari — that often makes it the best WebRTC picture,
> sharper than sub. Set the camera's `stream` option to `Extern` (or `All`) and use
> `/<camera-name>/externStream`.
>
> The slot's content is **model-dependent**, so check what your camera actually delivers:
> on **dual-lens / tracking / telephoto** models it's the **second lens**, not a balanced
> stream, and some models don't serve it at all (it falls back to the sub stream).

## Viewing the cameras

The add-on only produces RTSP streams; turning those into something you can put
on a dashboard is a one-time setup per camera. Three common ways, simplest first:

### 1. WebRTC Camera integration + Advanced Camera Card (direct, no entity)

Install the **WebRTC Camera** integration (HACS) and the **Advanced Camera Card**
(HACS). Point the card's `webrtc-card` provider straight at the RTSP URL — no
camera entity required, low-latency playback via the integration's bundled go2rtc:

```yaml
type: custom:advanced-camera-card
cameras:
  - live_provider: webrtc-card
    webrtc_card:
      url: rtsp://homeassistant.local:8558/front-door/main
    id: front-door
    title: Front Door
```

### 2. Generic Camera integration (creates a `camera.*` entity)

Settings → Devices & Services → **Add Integration → Generic Camera**:

- **Stream Source URL:** `rtsp://homeassistant.local:8558/<camera-name>/main`
- **RTSP transport:** TCP

This creates a `camera.<name>` entity usable by any card (Picture Glance,
Advanced Camera Card via `camera_entity:`, etc.):

```yaml
type: custom:advanced-camera-card
cameras:
  - camera_entity: camera.front_door
```

### 3. Register the stream in go2rtc (optional)

You can have go2rtc own the streams (handy for re-use across cards/integrations,
recording, transcoding). Add them once to its `go2rtc.yaml`:

```yaml
streams:
  front-door: rtsp://homeassistant.local:8558/front-door/main
  driveway: rtsp://homeassistant.local:8558/driveway/main
```

go2rtc pulls these server-side (it can reach `homeassistant.local:8558` fine).
The catch is how the **card** reaches go2rtc:

- **Home Assistant's built-in go2rtc** binds its API to **`127.0.0.1:1984`**
  (loopback). The card's `live_provider: go2rtc` connects to that API *from your
  browser*, so `url: http://homeassistant.local:1984/` is **unreachable** and the
  card shows nothing (no error). **Do not use the `go2rtc` provider with the
  built-in go2rtc.** Instead, reference the stream by **name** through the WebRTC
  Camera integration's proxy:

  ```yaml
  type: custom:advanced-camera-card
  cameras:
    - live_provider: webrtc-card
      webrtc_card:
        url: front-door          # go2rtc stream name (not an rtsp:// URL)
      id: front-door
      title: Front Door
  ```

- The direct `live_provider: go2rtc` provider only works against a go2rtc whose
  **API is reachable from the browser** — e.g. a standalone **go2rtc add-on** with
  its API exposed on the host. With HA's built-in go2rtc it won't.

For most setups the simplest path remains method 1 (direct RTSP via
`webrtc-card`) — the go2rtc indirection is only worth it if you specifically want
a single go2rtc to own all streams.

### Offline cameras and reboots

You don't need to do anything special for outages. Once a camera has been viewed
once (so its stream format is cached), opening it while it's **offline** — or
rebooting it while a card is open — shows a brief **placeholder** (a still of the
camera's last frame) and then returns to the live picture **on its own once the camera
is back**, with no need to close and reopen the card. The placeholder is held for as long as the card stays
open, so always-on wall dashboards ride through arbitrarily long reboots and recover
automatically. (The one caveat: the **first** time you open a camera after the add-on
restarts, the camera must be online so its format can be learned and cached.)

If you'd rather a long outage **end** the stream — so Home Assistant marks the camera
unavailable and can alert you — instead of holding the placeholder forever, set
**Offline timeout (seconds)** (`offline_timeout_secs`), either globally in the add-on
options or per camera. `0` (the default) holds the placeholder indefinitely; any other
value must exceed your camera's reboot time (a 60s floor is enforced). It's per-viewer:
the shared camera connection keeps reconnecting for any other open cards.

### Live view connects then drops in a loop

**Symptom:** a camera's live view won't hold — it connects and drops within a second,
keeps retrying, and the card shows nothing. It often appears right **after the add-on
restarts**, and a second restart sometimes "fixes" it.

**Why:** a Reolink camera takes ~2–3 seconds to connect peer-to-peer after the add-on
starts. If you open a card in that window, the stream isn't producing real frames yet,
so the add-on fills the gap with a "connecting" placeholder — but Home Assistant's
player (go2rtc) gives up on a placeholder-only stream within a fraction of a second and
falls into a fast reconnect loop that doesn't recover on its own. When the camera
happens to be ready in time, the same stream plays fine for hours — which is why it
looks random.

**Fix (do both):**

1. **Already handled by the add-on (0.7.18+).** It now briefly waits for the camera's
   first real frame before answering, so go2rtc gets real video immediately. You can tune
   or disable this with **Startup keyframe wait (seconds)** (`startup_keyframe_wait_secs`,
   default 5; `0` = off), globally or per camera. The trade-off is a brief "connecting"
   (usually 2–3 s) on the first open of each camera after a restart.
2. **Give go2rtc one stream to own.** If you point each card at a raw
   `rtsp://…:8558/…` URL, every card opens its own impatient connection with no backoff.
   Instead register each camera **once** as a named go2rtc stream and reference it by
   name — see [Register the stream in go2rtc](#3-register-the-stream-in-go2rtc-optional).
   That gives go2rtc a single, well-behaved producer per camera and stops the retry
   storm.
