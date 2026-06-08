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
rtsp://homeassistant.local:8558/<camera-name>/main     # full quality
rtsp://homeassistant.local:8558/<camera-name>/sub      # lighter substream
```

> The default is **8558**, not the usual RTSP `8554`, because Home Assistant's
> built-in go2rtc already listens on `8554` — neolink can't bind it there.
>
> `homeassistant.local` is the simplest host reference and works for consumers
> running inside Home Assistant. If your network can't resolve it, use the Home
> Assistant host's LAN IP instead (e.g. `rtsp://192.168.1.50:8558/...`).

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
      url: rtsp://homeassistant.local:8558/rgm203-entrada/main
    id: rgm203-entrada
    title: Entrada
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
  - camera_entity: camera.rgm203_entrada
```

### 3. Add the stream to go2rtc, then use it in Advanced Camera Card

If you run go2rtc (the **go2rtc add-on**, or the instance bundled with the WebRTC
Camera integration), register the neolink stream once in its `go2rtc.yaml`:

```yaml
streams:
  rgm203-entrada: rtsp://homeassistant.local:8558/rgm203-entrada/main
  rgm203-ascensor: rtsp://homeassistant.local:8558/rgm203-ascensor/main
```

Then reference it by name with the card's `go2rtc` provider (point `url` at your
go2rtc API, default `:1984`):

```yaml
type: custom:advanced-camera-card
cameras:
  - live_provider: go2rtc
    go2rtc:
      url: http://homeassistant.local:1984/
      stream: rgm203-entrada
    id: rgm203-entrada
    title: Entrada
```

This is handy when you want one go2rtc instance to own all streams (re-used by
multiple cards/integrations, recording, WebRTC/MSE transcoding, etc.).
