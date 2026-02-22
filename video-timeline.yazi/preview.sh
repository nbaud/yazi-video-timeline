#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n'

FILE_PATH=""
OFFSET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)   shift; FILE_PATH="${1:-}";;
    --offset) shift; OFFSET="${1:-0}";;
    --topw|--toph|--width|--height) shift ;;  # ignore if passed
  esac
  shift || true
done

[[ -z "${FILE_PATH}" || ! -f "${FILE_PATH}" ]] && { echo "No such file: ${FILE_PATH}"; exit 0; }

have() { command -v "$1" >/dev/null 2>&1; }
emit_image() { echo "__preview__image__path__ $1"; }

hash_str() {
  printf "%s" "$1" | (md5sum 2>/dev/null || shasum 2>/dev/null || sha1sum 2>/dev/null) | awk '{print $1}'
}

# --- TIMELINE SETTINGS ---
BASE_SECS=8
STEP_SECS=40

# --- THUMB SETTINGS ---
OUT_W=1600
OUT_H=900

cache_key() {
  local st
  if st="$(stat -Lc '%n|%Y|%s' -- "$FILE_PATH" 2>/dev/null)"; then
    :
  else
    st="$(stat -f '%N|%m|%z' -- "$FILE_PATH")"
  fi

  # Include settings so cache updates when you tweak them
  local settings="base=${BASE_SECS}|step=${STEP_SECS}|w=${OUT_W}|h=${OUT_H}|crop=16:9"
  hash_str "${st}|${settings}"
}

TMPDIR="${TMPDIR:-/tmp}"
CACHEDIR="${TMPDIR%/}/yazi-video-timeline"
mkdir -p "$CACHEDIR"

OFFSET=$(( OFFSET % 10 ))
(( OFFSET < 0 )) && OFFSET=0

KEY="$(cache_key)"
IMG="${CACHEDIR}/${KEY}.${OFFSET}.jpg"
INFO="${CACHEDIR}/${KEY}.info"

TS=$(( BASE_SECS + OFFSET * STEP_SECS ))

# Generate thumbnail if missing
if [[ ! -s "$IMG" ]]; then
  if have ffmpeg; then
    VF="scale=${OUT_W}:${OUT_H}:force_original_aspect_ratio=increase,crop=${OUT_W}:${OUT_H}"
    LC_NUMERIC=C ffmpeg -hide_banner -loglevel error -y \
      -ss "$TS" -i "$FILE_PATH" \
      -vf "$VF" -frames:v 1 -q:v 3 \
      "$IMG" >/dev/null 2>&1 || true
  elif have ffmpegthumbnailer; then
    # fallback (no crop guarantee)
    LC_NUMERIC=C ffmpegthumbnailer \
      -q 7 -c jpeg -i "$FILE_PATH" -o "$IMG" -t "$TS" -s "$OUT_W" \
      >/dev/null 2>&1 || true
  else
    echo "Missing dependency: ffmpeg (preferred) or ffmpegthumbnailer"
  fi
fi

[[ -s "$IMG" ]] && emit_image "$IMG"

# Metadata (cached once per file version + settings)
if [[ ! -s "$INFO" ]]; then
  if have ffprobe; then
    # Pull a few key fields (video + first audio stream)
    # Then format them nicely with awk.
    ffprobe -v error \
      -select_streams v:0 \
      -show_entries \
        format=filename,format_name,duration,bit_rate:stream=codec_name,width,height,avg_frame_rate,r_frame_rate,display_aspect_ratio \
      -of default=nw=1 -- "$FILE_PATH" 2>/dev/null \
    | awk -F= '
      function trim(s){ sub(/^[ \t\r\n]+/, "", s); sub(/[ \t\r\n]+$/, "", s); return s }
      function fps(fr,   a,b){ split(fr,a,"/"); if(a[2]>0) return a[1]/a[2]; return fr }
      function human_dur(sec,   s,m,h){
        sec=int(sec+0.5); s=sec%60; m=int(sec/60)%60; h=int(sec/3600);
        if(h>0) return sprintf("%dh%02dm%02ds",h,m,s);
        return sprintf("%dm%02ds",m,s);
      }
      function human_br(b,   mb){ if(b==""||b==0) return "n/a"; mb=b/1000000; return sprintf("%.2f Mbps", mb) }

      $1=="codec_name"{vcodec=$2}
      $1=="width"{w=$2}
      $1=="height"{h=$2}
      $1=="display_aspect_ratio"{dar=$2}
      $1=="avg_frame_rate"{avg=$2}
      $1=="r_frame_rate"{rfr=$2}
      $1=="duration"{dur=$2}
      $1=="bit_rate"{br=$2}
      $1=="format_name"{fmt=$2}
      END{
        if(dar=="") dar="n/a";
        if(avg!="" && avg!="0/0") f=fps(avg); else f=fps(rfr);
        printf("Video:   %s  |  %sx%s  |  DAR %s  |  %.2f fps\n", vcodec, w, h, dar, f);
        printf("Length:  %s  |  Bitrate: %s  |  Container: %s\n", human_dur(dur), human_br(br), fmt);
      }
    ' >"$INFO" || true

    # Add first audio stream info (optional)
    ffprobe -v error \
      -select_streams a:0 \
      -show_entries stream=codec_name,channels,sample_rate,bit_rate \
      -of default=nw=1 -- "$FILE_PATH" 2>/dev/null \
    | awk -F= '
      function human_hz(x){ if(x==""||x==0) return "n/a"; return sprintf("%.1f kHz", x/1000) }
      function human_br(b,   kb){ if(b==""||b==0) return "n/a"; kb=b/1000; return sprintf("%.0f kbps", kb) }
      $1=="codec_name"{ac=$2}
      $1=="channels"{ch=$2}
      $1=="sample_rate"{sr=$2}
      $1=="bit_rate"{br=$2}
      END{
        if(ac!="") printf("Audio:   %s  |  %s ch  |  %s  |  %s\n", ac, ch, human_hz(sr), human_br(br));
      }
    ' >>"$INFO" || true

  else
    echo "ffprobe not found (install ffmpeg)" >"$INFO"
  fi
fi

cat "$INFO" 2>/dev/null || true
