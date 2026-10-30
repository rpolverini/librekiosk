#!/usr/bin/env bash
# Upgrade the system through APT (Brave included), then re-apply LibreKiosk.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEBIAN_FRONTEND=noninteractive
[ -d .git ] && git pull --ff-only || true
apt-get update
apt-get -y full-upgrade
installer/install.sh
