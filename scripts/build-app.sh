#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"
APP="$ROOT/dist/iClip.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/iClip" "$APP/Contents/MacOS/iClip"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# Set SIGN_IDENTITY to an Apple Development/Developer ID identity for stable permissions.
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
codesign --verify --strict "$APP"
printf 'Built: %s\n' "$APP"
