#!/usr/bin/env bash
# Report-only health check.
rc=0
ok()   { echo "  ok    $*"; }
fail() { echo "  FAIL  $*"; rc=1; }
chk()  { if "${@:2}" >/dev/null 2>&1; then ok "$1"; else fail "$1"; fi; }

for p in xorg openbox lightdm network-manager network-manager-gnome kdeconnect brave-browser python3-yaml; do
  chk "package $p" dpkg -s "$p"
done
chk "config valid" librekiosk-configure --check
for s in librekiosk-configure NetworkManager lightdm; do
  chk "service $s enabled" systemctl is-enabled -q "$s"
done
user=$(. /etc/librekiosk/env 2>/dev/null; python3 -I -c "import yaml;print(((yaml.safe_load(open('/etc/librekiosk/librekiosk.yml')) or {}).get('system') or {}).get('user','libre'))" 2>/dev/null || echo libre)
chk "user $user exists" id "$user"
chk "user $user is in sudo" bash -c "id -nG $user | grep -qw sudo"
chk "Brave repo configured" test -f /etc/apt/sources.list.d/brave-browser-release.sources
chk "Wi-Fi connected" bash -c "nmcli -t -f TYPE,STATE device | grep -q '^wifi:connected'" || true
if pgrep -u 0 -x brave >/dev/null; then fail "Brave is running as root"; else ok "Brave not running as root"; fi
exit $rc
