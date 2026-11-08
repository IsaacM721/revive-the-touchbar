#!/bin/bash
# Builds effectlab from the app's renderer sources (plain Swift, no AppKit) and runs it.
#   tools/effectlab/run.sh list
#   tools/effectlab/run.sh still all /tmp/fx
# Needs a Swift toolchain (swiftc) on PATH: Xcode on a Mac, or swift.org / the swiftlang package on Linux.
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT="${EFFECTLAB_BIN:-build/effectlab}"
mkdir -p "$(dirname "$OUT")"
SRC=(Sources/Model.swift Sources/Canvas.swift Sources/PixelFont.swift Sources/EffectCore.swift Sources/Library*.swift Sources/Scene.swift tools/effectlab/main.swift)
newest=$(ls -t "${SRC[@]}" | head -1)
if [ ! -x "$OUT" ] || [ "$newest" -nt "$OUT" ]; then
  swiftc -O -swift-version 5 "${SRC[@]}" -o "$OUT" >&2
fi
exec "$OUT" "$@"
