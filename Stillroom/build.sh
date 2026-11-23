#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
app="$PWD/build/DynUtils.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp Info.plist "$app/Contents/"
cp Resources/*.png "$app/Contents/Resources/"
cp -R Resources/th.lproj "$app/Contents/Resources/"
arch="$(uname -m)"
xcrun swiftc -module-cache-path "$PWD/build/ModuleCache" -swift-version 6 -target "$arch-apple-macosx14.0" -O \
    Sources/*.swift -o "$app/Contents/MacOS/DynUtils"
codesign --force --sign - "$app" >&2
printf '%s\n' "$app"
