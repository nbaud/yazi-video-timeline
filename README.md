# video-timeline.yazi

A small Yazi plugin that shows a “timeline” preview for videos in the preview pane:

- renders a cached thumbnail (prefers `ffmpeg`, falls back to `ffmpegthumbnailer`)
- shows compact video/audio metadata (via `ffprobe`)
- cycles offsets automatically (0..9) to simulate motion / scanning through the video

Works best in **kitty** (Yazi adapter: **Kgp**).

---

## Requirements

- Yazi (recent)
- Terminal with image support (**kitty** recommended)
- `ffmpeg` (for `ffmpeg` + `ffprobe`)
- Optional: `ffmpegthumbnailer` (fallback thumbnail generator)

Debian/Ubuntu/Mint:

```bash
sudo apt update
sudo apt install ffmpeg ffmpegthumbnailer
```

---

## Install

1) Copy the plugin folder into Yazi’s plugins directory:

```bash
mkdir -p ~/.config/yazi/plugins
cp -r video-timeline.yazi ~/.config/yazi/plugins/
chmod +x ~/.config/yazi/plugins/video-timeline.yazi/preview.sh
```

2) Enable it for videos in `~/.config/yazi/yazi.toml`:

```toml
[[plugin.prepend_previewers]]
mime = "video/*"
run = "video-timeline"
```

Put this rule **above** other generic video previewers (e.g. `mediainfo`) so it wins, or remove other previewers.

3) Restart Yazi and hover a video file.

---

## Configuration

Open `~/.config/yazi/plugins/video-timeline.yazi/preview.sh` and tweak:

- `BASE_SECS` — where the timeline starts (seconds). Useful to avoid black intros.
- `STEP_SECS` — how far each offset jumps (seconds).
- `OUT_W` / `OUT_H` — output thumbnail dimensions (the script crops to 16:9 at these dims).

The cache key includes these values, so changing them automatically invalidates cached thumbnails.

---

## Cache

Cached files are stored in:

- `/tmp/yazi-video-timeline/` (or `$TMPDIR/yazi-video-timeline/`)

Clear cache:

```bash
rm -rf /tmp/yazi-video-timeline
```

---

## Troubleshooting

### Check kitty image adapter is active

```bash
yazi --debug | sed -n '/Adapter/,+4p'
```

You want to see `Adapter.matches: Kgp`.

### If you ever see old thumbnails after changing settings

Clear the cache directory:

```bash
rm -rf /tmp/yazi-video-timeline
```

---

## License

MIT (see `LICENSE`).
