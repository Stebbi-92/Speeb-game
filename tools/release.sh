#!/bin/bash
# Builds everything a release needs. Run locally, or by the Release workflow when it is started by hand:
#   dist/Brelm-Setup.exe             Windows installer
#   dist/Brelm-Windows.zip           Windows, unzip and play
#   dist/Brelm-macOS.zip             macOS app
#   dist/Brelm-Linux.zip             Linux and Steam Deck, unzip and play
#   dist/Brelm-Windows-godot4.3-rtc1.pck  game data, fetched by the in-game updater
#   dist/Brelm-macOS-godot4.3-rtc1.pck
#   dist/Brelm-Linux-godot4.3-rtc1.pck
#   dist/split/<OS>/                 the same data cut into a code pack and parts (tools/split_pack.py),
#                                    with their list: an update fetches only the parts that changed
# Then, to publish (needs gh signed in):  tools/release.sh publish
set -e
cd "$(dirname "$0")/.."
G=${GODOT:-/home/user/godot/Godot_v4.3-stable_linux.x86_64}
VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
NUM=${VERSION%%-*}
ENGINE=godot4.3-rtc1   # keep in step with Updater.LIBS
mkdir -p build build-mac build-linux dist

if [ "$1" != "publish" ]; then
  # A fresh checkout has no import cache; make it before exporting
  [ -d .godot/imported ] || $G --headless --import >/dev/null 2>&1 || true
  python3 tools/split_pack.py plan   # parts.json: every pack knows its own parts
  cp "tools/launchers/Brelm (compatibility mode).bat" "tools/launchers/Brelm Server.bat" build/
  cp "tools/launchers/Brelm Server.command" build-mac/
  cp "tools/launchers/Brelm Server.sh" "tools/launchers/Brelm (compatibility mode).sh" build-linux/
  $G --headless --path . --export-release "Windows Desktop" build/Brelm.exe
  $G --headless --path . --export-release "macOS" build-mac/Brelm.zip
  $G --headless --path . --export-release "Linux" build-linux/Brelm.x86_64
  $G --headless --path . --export-pack "Windows Desktop" "dist/Brelm-Windows-$ENGINE.pck"
  $G --headless --path . --export-pack "macOS" "dist/Brelm-macOS-$ENGINE.pck"
  $G --headless --path . --export-pack "Linux" "dist/Brelm-Linux-$ENGINE.pck"
  rm -rf dist/split
  for OS in Windows macOS Linux; do
    python3 tools/split_pack.py split "dist/Brelm-$OS-$ENGINE.pck" "$OS" "dist/split/$OS"
  done
  rm -f parts.json
  python3 tools/package.py dist
  (cd tools/installer && makensis -V2 -DVERSION="$NUM" -DSRC="../../build" -DOUT="../../dist/Brelm-Setup.exe" brelm.nsi)
  ls -la dist
  exit 0
fi

TAG="v$VERSION"
REPO=Stebbi-92/Speeb-game
# Parts whose sources did not change since the last release keep their name: they are not sent again,
# and the list points to the release that holds them (so never delete an old release's files)
PREV=$(gh release list --repo $REPO --limit 5 --json tagName --jq '.[].tagName' | grep -vx "$TAG" | head -1)
rm -rf dist/prev && mkdir -p dist/prev
[ -n "$PREV" ] && gh release download "$PREV" --repo $REPO -p "*-parts.json" -D dist/prev 2>/dev/null || true
UPLOAD=()
for OS in Windows macOS Linux; do
  M="dist/split/$OS/Brelm-$OS-$ENGINE-parts.json"
  mapfile -t KEEP < <(python3 tools/split_pack.py reuse "$M" "dist/prev/Brelm-$OS-$ENGINE-parts.json" "$PREV")
  UPLOAD+=("$M" "dist/split/$OS/Brelm-$OS-$ENGINE-code.pck")
  for F in dist/split/$OS/*.pck; do
    case "$F" in *-code.pck) continue;; esac
    printf '%s\n' "${KEEP[@]}" | grep -qx "$(basename "$F")" || UPLOAD+=("$F")
  done
done
gh release create "$TAG" --repo $REPO --target "${GITHUB_SHA:-main}" --prerelease --title "Brelm alpha $NUM" \
  --notes-file "${NOTES:-NEWS.txt}" \
  dist/Brelm-Setup.exe dist/Brelm-Windows.zip dist/Brelm-macOS.zip dist/Brelm-Linux.zip \
  "dist/Brelm-Windows-$ENGINE.pck" "dist/Brelm-macOS-$ENGINE.pck" "dist/Brelm-Linux-$ENGINE.pck" \
  "${UPLOAD[@]}"
