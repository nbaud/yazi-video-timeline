#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Nicolas Baudoin
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
  if have mediainfo; then
    mediainfo "$FILE_PATH" >"$INFO" 2>/dev/null || true
  elif have ffprobe; then
    ffprobe -v error -show_format -show_streams -- "$FILE_PATH" >"$INFO" 2>/dev/null || true
  else
    echo "Install mediainfo (recommended) or ffmpeg (ffprobe) for metadata." >"$INFO"
  fi
fi

cat "$INFO" 2>/dev/null || true
