# Cloud Receiver

A Vision Pro app that displays any 360° equirectangular video stream on an inverted sphere — designed to receive live Syphon output from a Mac running Cloud Visualizer, eBoSuite, Ableton (with a Syphon sender), or any other Syphon-producing tool.

The headset becomes a universal 360° monitor for any live Mac visual performance.

## Architecture

```
Mac                                    Vision Pro
─────────────────────────              ─────────────────
Cloud Visualizer / eBoSuite /          Cloud Receiver
Ableton + Syphon sender                AVPlayer + VideoMaterial
        │                                      ▲
        ▼ Syphon (zero-copy GPU)               │ LL-HLS
OBS Studio (Syphon Client source)              │
        │                                      │
        ▼ RTMP push to localhost               │
MediaMTX (single binary)  ─────────────────────┘
        republishes as LL-HLS on :8888
```

The receiver itself is a thin AVPlayer wrapper bound to a `VideoMaterial` on a 50m inverted sphere — the proven 8K@60fps path on visionOS. Everything heavy happens on the Mac.

## Mac Setup (one-time)

### 1. Install MediaMTX

Download the latest macOS ARM64 build from [github.com/bluenviron/mediamtx/releases](https://github.com/bluenviron/mediamtx/releases) — pick the file ending in `darwin_arm64.tar.gz`.

```bash
cd ~/Downloads
tar -xzf mediamtx_*_darwin_arm64.tar.gz
mkdir -p ~/Tools/mediamtx
mv mediamtx mediamtx.yml ~/Tools/mediamtx/
```

The default config has Low-Latency HLS enabled out of the box. No edits needed.

### 2. Run MediaMTX

```bash
cd ~/Tools/mediamtx && ./mediamtx
```

Leave the Terminal window open. MediaMTX will print something like:

```
INF [RTMP] listener opened on :1935
INF [HLS] listener opened on :8888
INF [RTSP] listener opened on :8554
```

If macOS blocks it the first time: System Settings → Privacy & Security → "Allow Anyway".

### 3. Configure OBS

- Add a **Syphon Client** source, pick "Cloud Visualizer" (or eBoSuite, Ableton, etc.)
- Set the canvas to **2:1 aspect ratio** — equirectangular 360° needs this. Settings → Video → Base/Output resolution = `3840x1920` (or `2048x1024` for lighter loads).
- Settings → **Stream**:
  - Service: **Custom**
  - Server: `rtmp://localhost:1935/live`
  - Stream Key: `stream` (anything works; the receiver URL must match)
- Settings → **Output** → Streaming:
  - Encoder: **Apple VT H.264 Hardware Encoder**
  - Rate Control: **CBR**
  - Bitrate: 8000–20000 Kbps (start at 12000)
  - Keyframe Interval: **1s** (critical for low latency)
- Click **Start Streaming**.

### 4. Find your Mac's hostname

```bash
scutil --get LocalHostName
```

Returns something like `Chris-MacBook-Pro`. Your stream URL is then:

```
http://Chris-MacBook-Pro.local:8888/live/index.m3u8
```

## Vision Pro Setup

1. Open **Cloud Receiver**.
2. Paste the URL above into the field. The app remembers it across launches.
3. Tap **Connect** — you should see "Connecting to..." then playback starts in the small window.
4. Tap **Enter Immersive** — the stream wraps around you on a 360° sphere.

## Latency

LL-HLS with 1s keyframes typically lands at **800ms – 2s** end-to-end. This is fine for visual monitoring of a live performance. If you need sub-second for tightly choreographed shows, MediaMTX also serves the same stream as RTSP on port 8554 — but consuming RTSP on visionOS requires VLCKit (currently alpha), so it's not the default path.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Receiver shows "Idle" forever | Check OBS is actually streaming (status bar shows "LIVE") and MediaMTX terminal shows `[RTMP] new conn` |
| Visible stutter / buffering | Lower OBS bitrate, or drop canvas to 2048×1024 |
| Wrong aspect ratio on the sphere | OBS canvas isn't 2:1 — fix in Settings → Video |
| `your-mac.local` doesn't resolve | Use the IP address from `ipconfig getifaddr en0` instead |
| MediaMTX won't launch (Gatekeeper) | System Settings → Privacy & Security → Allow Anyway |

## Build

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```bash
xcodegen generate
xcodebuild -project CloudVisualizerReceiver.xcodeproj \
           -scheme CloudVisualizerReceiver \
           -destination 'platform=visionOS,id=YOUR_DEVICE_ID' \
           build
```
