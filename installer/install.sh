#!/usr/bin/env bash
# Turn a clean Debian Stable amd64 install into LibreKiosk. Safe to re-run.
# Never touches disks or partitions. Also used inside the live-build chroot.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

[ "$(id -u)" = 0 ] || { echo "run as root: sudo $0" >&2; exit 1; }
ROOT=$(cd "$(dirname "$0")/.." && pwd)
. /etc/os-release
[ "$ID" = debian ] && [ "$(dpkg --print-architecture)" = amd64 ] || { echo "Debian amd64 required" >&2; exit 1; }

pkgs() { grep -vh '^\s*\(#\|$\)' "$ROOT/live-build/config/package-lists/$1.list.chroot"; }

apt-get update
pkgs librekiosk | xargs apt-get install -y
pkgs firmware | xargs apt-get install -y || echo "WARNING: firmware packages not installed (enable the non-free-firmware APT component)" >&2

# Brave: official APT repository
if [ ! -f /etc/apt/sources.list.d/brave-browser-release.sources ]; then
  base=https://brave-browser-apt-release.s3.brave.com
  curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg "$base/brave-browser-archive-keyring.gpg"
  curl -fsSLo /etc/apt/sources.list.d/brave-browser-release.sources "$base/brave-browser.sources"
  apt-get update
fi
apt-get install -y brave-browser

# LibreKiosk files. The YAML is only seeded, never overwritten.
install -d /etc/librekiosk
[ -e /etc/librekiosk/librekiosk.yml ] || install -m 644 "$ROOT/librekiosk.yml" /etc/librekiosk/librekiosk.yml
install -Dm755 "$ROOT/config/bin/librekiosk-browser" /usr/local/bin/librekiosk-browser
install -Dm755 "$ROOT/installer/configure.sh" /usr/local/bin/librekiosk-configure
install -Dm755 "$ROOT/installer/doctor.sh" /usr/local/bin/librekiosk-doctor
install -Dm644 "$ROOT/config/openbox/autostart" /etc/xdg/openbox/autostart
install -Dm644 "$ROOT/config/openbox/menu.xml" /etc/xdg/openbox/menu.xml
install -Dm644 "$ROOT/config/systemd/librekiosk-configure.service" /etc/systemd/system/librekiosk-configure.service

# Default user (dev defaults: libre/libre; password only set when the account is created)
user=$(python3 -I -c "import yaml;print(((yaml.safe_load(open('/etc/librekiosk/librekiosk.yml')) or {}).get('system') or {}).get('user','libre'))")
if ! id "$user" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -G sudo,audio,video,netdev,plugdev "$user"
  echo "$user:libre" | chpasswd
  echo "NOTE: user '$user' created with password 'libre'. Change it before using an untrusted network."
fi

systemctl enable librekiosk-configure.service NetworkManager.service lightdm.service
systemctl set-default graphical.target
/usr/local/bin/librekiosk-configure
echo "LibreKiosk installed. Reboot to start the graphical session."
