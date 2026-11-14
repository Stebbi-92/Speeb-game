#!/bin/bash
# Builds everything a release needs, locally (no GitHub Actions):
#   dist/Brelm-Setup.exe             Windows installer
#   dist/Brelm-Windows.zip           Windows, unzip and play
#   dist/Brelm-macOS.zip             macOS app
#   dist/Brelm-Windows-godot4.3.pck  game data, fetched by the in-game updater
#   dist/Brelm-macOS-godot4.3.pck
# Then, to publish (needs gh signed in):  tools/release.sh publish
set -e
cd "$(dirname "$0")/.."
G=${GODOT:-/home/user/godot/Godot_v4.3-stable_linux.x86_64}
VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
NUM=${VERSION%%-*}
ENGINE=godot4.3
mkdir -p build build-mac dist

if [ "$1" != "publish" ]; then
  $G --headless --path . --export-release "Windows Desktop" build/Brelm.exe
  $G --headless --path . --export-release "macOS" build-mac/Brelm.zip
  $G --headless --path . --export-pack "Windows Desktop" "dist/Brelm-Windows-$ENGINE.pck"
  $G --headless --path . --export-pack "macOS" "dist/Brelm-macOS-$ENGINE.pck"
  python3 tools/package.py dist
  (cd tools/installer && makensis -V2 -DVERSION="$NUM" -DSRC="../../build" -DOUT="../../dist/Brelm-Setup.exe" brelm.nsi)
  ls -la dist
  exit 0
fi

TAG="v$VERSION"
gh release create "$TAG" --repo Stebbi-92/Speeb-game --prerelease --title "Brelm alpha $NUM" \
  --notes-file "${NOTES:-NEWS.txt}" \
  dist/Brelm-Setup.exe dist/Brelm-Windows.zip dist/Brelm-macOS.zip \
  "dist/Brelm-Windows-$ENGINE.pck" "dist/Brelm-macOS-$ENGINE.pck"
