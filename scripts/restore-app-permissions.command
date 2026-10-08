#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/iClip.app"
if [[ ! -f "$APP/Contents/MacOS/iClip" ]]; then
    echo "Keep this script next to iClip.app." >&2
    exit 1
fi
# GitHub upload-artifact stores files as 0644, including Mach-O executables.
chmod +x "$APP/Contents/MacOS/iClip"
codesign --verify --strict "$APP"
echo "Permissions restored. You can now open iClip.app."
