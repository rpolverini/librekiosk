#!/usr/bin/env bash
# Build dist/librekiosk-amd64.iso. Needs a Debian/Ubuntu host with live-build, as root.
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(uname)" = Linux ] && command -v lb >/dev/null || { echo "needs Linux with live-build (apt install live-build)" >&2; exit 1; }
[ "$(id -u)" = 0 ] || { echo "run as root (make build-iso uses sudo)" >&2; exit 1; }

# Build in a throwaway copy so the git tree stays clean; the hook installs from /opt/librekiosk.
rm -rf build && mkdir -p build dist
cp -r live-build/. build/
stage=build/config/includes.chroot/opt/librekiosk
mkdir -p "$stage/live-build/config"
cp -r installer config librekiosk.yml "$stage/"
cp -r live-build/config/package-lists "$stage/live-build/config/"

( cd build && lb clean --purge >/dev/null 2>&1 || true; lb config && lb build )

cp build/live-image-amd64.hybrid.iso dist/librekiosk-amd64.iso
( cd dist && sha256sum librekiosk-amd64.iso > librekiosk-amd64.iso.sha256 )
echo "built dist/librekiosk-amd64.iso"
