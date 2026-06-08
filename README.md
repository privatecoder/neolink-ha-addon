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

With the Mosquitto broker add-on installed, MQTT is auto-wired and camera
entities appear in Home Assistant via MQTT discovery. Override the broker in the
add-on options if you use an external one.

## RTSP

The RTSP server is exposed on the host at the configured `bind_port` (default
`8554`): `rtsp://<home-assistant-host>:8554/<camera-name>/main`.
