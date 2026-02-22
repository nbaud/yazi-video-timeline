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
- `mediainfo` (recommended; nicer metadata output)
- Optional: `ffmpegthumbnailer` (fallback thumbnail generator)

Debian/Ubuntu/Mint:

```bash
sudo apt update
sudo apt install ffmpeg ffmpegthumbnailer mediainfo
```

---

## Install

1) Copy the plugin folder into Yazi’s plugins directory:

```bash
mkdir -p ~/.config/yazi/plugins
cp -r video-timeline.yazi ~/.config/yazi/plugins/
chmod +x ~/.config/yazi/plugins/video-timeline.yazi/preview.sh
```

2) Enable the previewer in `yazi.toml`

Some Yazi installs do **not** create `~/.config/yazi/yazi.toml` until you make one.

If `~/.config/yazi/yazi.toml` already exists

Add this rule (preferably above other generic video previewers like `mediainfo`):

```toml
[[plugin.prepend_previewers]]
mime = "video/*"
run = "video-timeline"
```

If `~/.config/yazi/yazi.toml` does NOT exist (create a minimal one)

```bash
mkdir -p ~/.config/yazi

cat > ~/.config/yazi/yazi.toml <<'EOF'
[plugin]
prepend_previewers = [
  { mime = "video/*", run = "video-timeline" },
]
EOF
```

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

### If you ever see old thumbnails after changing settings

Clear the cache directory:

```bash
rm -rf /tmp/yazi-video-timeline
```

## Inspiration / Thanks

This plugin was inspired by the general script-driven preview approach used in the Yazi community, including the `preview.yazi` plugin by Urie96.
This repository is a focused implementation for video timeline previews.

---

## License

MIT (see `LICENSE`).
