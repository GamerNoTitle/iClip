#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ARCH="${ARCH:-}"
if [[ -n "$ARCH" ]]; then
    [[ "$ARCH" == arm64 || "$ARCH" == x86_64 ]] || { echo "Unsupported ARCH: $ARCH" >&2; exit 1; }
    swift build -c release --arch "$ARCH"
    BIN_DIR="$(swift build -c release --arch "$ARCH" --show-bin-path)"
else
    swift build -c release
    BIN_DIR="$(swift build -c release --show-bin-path)"
fi
APP="$ROOT/dist/iClip.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/iClip" "$APP/Contents/MacOS/iClip"
# Explicit installed-app lookup uses the standard resource directory.
cp -R "$BIN_DIR/iClip_iClip.bundle" "$APP/Contents/Resources/"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/MenuBarIcon.png" "$APP/Contents/Resources/MenuBarIcon.png"
python3 "$ROOT/scripts/prepare-icon-catalog.py" "$ROOT/.build/AppIcons.xcassets"
xcrun actool "$ROOT/.build/AppIcons.xcassets" --compile "$APP/Contents/Resources" \
    --platform macosx --minimum-deployment-target 14.0 --app-icon AppIcon \
    --output-partial-info-plist "$ROOT/.build/icon-info.plist"
# Set SIGN_IDENTITY to an Apple Development/Developer ID identity for stable permissions.
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP/Contents/Resources/iClip_iClip.bundle"
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
codesign --verify --strict "$APP"
printf 'Built: %s\n' "$APP"
