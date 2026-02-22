# video-timeline.yazi

A small Yazi plugin that shows a “timeline” preview for videos in the preview pane:

- renders a cached thumbnail (using `ffmpeg`, fallback `ffmpegthumbnailer`)
- shows compact metadata below (via `ffprobe`)
- cycles offsets automatically (0..9) to simulate motion / scanning through the video

Tested with **kitty** (Kgp image adapter).

## Demo

Hover a video file in Yazi → the preview pane shows:
- top: a thumbnail frame
- bottom: video/audio metadata
- every 2 seconds: the thumbnail advances to the next offset

## Requirements

- Yazi (recent)
- Terminal with image support (kitty recommended)
- `ffmpeg` (for `ffmpeg` + `ffprobe`)
- Optional: `ffmpegthumbnailer` (fallback)

On Debian/Ubuntu/Mint:
```bash
sudo apt install ffmpeg ffmpegthumbnailer
