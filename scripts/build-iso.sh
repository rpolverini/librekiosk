#!/usr/bin/env bash
# Build dist/librekiosk-amd64.iso. Needs a Debian 13 host with live-build, as root; use `make build-iso-docker` elsewhere.
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$(uname)" = Linux ] && command -v lb >/dev/null || { echo "needs Linux with a recent live-build; run make build-iso-docker" >&2; exit 1; }
[ "$(id -u)" = 0 ] || { echo "run as root (make build-iso uses sudo)" >&2; exit 1; }

# Build in a throwaway copy so the git tree stays clean; the hook installs from /opt/librekiosk.
rm -rf build && mkdir -p build dist
cp -r live-build/. build/
stage=build/config/includes.chroot/opt/librekiosk
mkdir -p "$stage/live-build/config"
cp -r installer config "$stage/"
# Your own librekiosk.yml (git-ignored) wins over the shipped example.
[ -f librekiosk.yml ] && cp librekiosk.yml "$stage/librekiosk.yml" || cp librekiosk_example.yml "$stage/librekiosk.yml"
cp -r live-build/config/package-lists live-build/config/branding "$stage/live-build/config/"

( cd build && lb clean --purge >/dev/null 2>&1 || true; lb config && lb build )

cp build/live-image-amd64.hybrid.iso dist/librekiosk-amd64.iso
( cd dist && sha256sum librekiosk-amd64.iso > librekiosk-amd64.iso.sha256 )
echo "built dist/librekiosk-amd64.iso"
