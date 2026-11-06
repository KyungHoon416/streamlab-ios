#!/usr/bin/env bash
# Requires ffmpeg. Extend the repository's own 30-second demo without re-encoding.
# Normal playback and episode/end tests continue to use playback-demo.mp4.
set -euo pipefail
cd "$(dirname "$0")/.."
resource_dir=Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Resources
ffmpeg -hide_banner -loglevel error -nostdin -y -stream_loop 19 \
  -i "$resource_dir/playback-demo.mp4" -map 0 -c copy -movflags +faststart \
  "$resource_dir/playback-smoke-600.mp4"
ffprobe -v error -show_entries format=duration,size -of json "$resource_dir/playback-smoke-600.mp4"
