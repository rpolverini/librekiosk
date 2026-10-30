#!/usr/bin/env bash
# Validate the LibreKiosk YAML, then apply it. Idempotent; also runs at every boot.
# Usage: configure.sh [--check] [file]
set -euo pipefail

CHECK=0
[ "${1:-}" = --check ] && { CHECK=1; shift; }
CONF=${1:-/etc/librekiosk/librekiosk.yml}
[ -r "$CONF" ] || { echo "librekiosk: cannot read $CONF" >&2; exit 1; }

# Validation happens before anything is touched: a bad file applies nothing.
vars=$(python3 -I - "$CONF" <<'PY'
import re, shlex, sys, uuid, yaml

def load(p):
    with open(p) as f:
        d = yaml.safe_load(f) or {}
    if not isinstance(d, dict):
        sys.exit(f"{p}: top level must be a mapping")
    return d

c = load(sys.argv[1])

def get(path, typ, default, src=c):
    n = src
    for k in path.split("."):
        n = n.get(k) if isinstance(n, dict) else None
    if n is None:
        return default
    if not isinstance(n, typ):
        sys.exit(f"{path}: expected {typ.__name__}")
    return n

host = get("system.hostname", str, "librekiosk")
user = get("system.user", str, "libre")
home = get("browser.homepage", str, "https://www.youtube.com/")
if not re.fullmatch(r"[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?", host):
    sys.exit("system.hostname: invalid hostname")
if not re.fullmatch(r"[a-z_][a-z0-9_-]{0,31}", user):
    sys.exit("system.user: invalid user name")
if not re.match(r"https?://\S+$", home):
    sys.exit("browser.homepage: must be an http(s) URL")

ssid = get("wifi.ssid", str, "")
psk = get("wifi.password", str, "")
sf = get("wifi.secrets_file", str, "")
if sf:
    try:
        sec = load(sf)
        ssid, psk = get("wifi.ssid", str, ssid, sec), get("wifi.password", str, psk, sec)
    except FileNotFoundError:
        print(f"librekiosk: secrets_file {sf} not found, using librekiosk.yml values", file=sys.stderr)
wifi_on = get("wifi.enabled", bool, False) and bool(ssid) and psk != "CHANGE_ME"
if "\n" in ssid + psk:
    sys.exit("wifi: ssid/password must be single-line")

b = lambda p, d: int(get(p, bool, d))
out = dict(
    LK_HOSTNAME=host, LK_USER=user, LK_HOMEPAGE=home,
    LK_FULLSCREEN=b("browser.fullscreen", False),
    LK_ADDRESS_BAR=b("browser.show_address_bar", True),
    LK_TABS=b("browser.show_tabs", True),
    LK_RESTART=b("browser.restart_on_crash", True),
    LK_SHIELDS=b("browser.shields", True),
    LK_KDECONNECT=b("kdeconnect.enabled", True),
    LK_NO_BLANK=b("system.disable_screen_blanking", True),
    LK_NO_SUSPEND=b("system.disable_suspend", True),
    LK_WIFI=int(wifi_on), LK_SSID=ssid, LK_PSK=psk,
    LK_WIFI_AUTO=b("wifi.autoconnect", True),
    LK_WIFI_UUID=uuid.uuid5(uuid.NAMESPACE_DNS, "librekiosk-wifi"),
)
for k, v in out.items():
    print(f"{k}={shlex.quote(str(v))}")
PY
) || { echo "librekiosk: invalid config $CONF, nothing applied" >&2; exit 1; }
eval "$vars"

if [ "$CHECK" = 1 ]; then echo "librekiosk: $CONF OK"; exit 0; fi

systemd_up() { [ -d /run/systemd/system ]; }   # false inside live-build chroot

# Shell-sourceable settings for the Openbox autostart and browser wrapper (no secrets).
install -d /etc/librekiosk
for v in LK_HOMEPAGE LK_FULLSCREEN LK_ADDRESS_BAR LK_TABS LK_RESTART LK_KDECONNECT LK_NO_BLANK; do
  printf '%s=%q\n' "$v" "${!v}"
done > /etc/librekiosk/env

# Hostname
if [ "$(cat /etc/hostname 2>/dev/null || true)" != "$LK_HOSTNAME" ]; then
  if systemd_up; then hostnamectl set-hostname "$LK_HOSTNAME"; else echo "$LK_HOSTNAME" > /etc/hostname; fi
  if grep -q '^127\.0\.1\.1' /etc/hosts; then
    sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$LK_HOSTNAME/" /etc/hosts
  else
    printf '127.0.1.1\t%s\n' "$LK_HOSTNAME" >> /etc/hosts
  fi
fi

# Automatic graphical login
install -d /etc/lightdm/lightdm.conf.d
printf '[Seat:*]\nautologin-user=%s\nautologin-session=openbox\nautologin-user-timeout=0\n' \
  "$LK_USER" > /etc/lightdm/lightdm.conf.d/50-librekiosk.conf

# Suspend/hibernate
units="sleep.target suspend.target hibernate.target hybrid-sleep.target"
if [ "$LK_NO_SUSPEND" = 1 ]; then
  systemctl mask --quiet $units
else
  systemctl unmask --quiet $units
fi

# Brave Shields are on by default; only write a policy to turn them off.
pol=/etc/brave/policies/managed/librekiosk.json
if [ "$LK_SHIELDS" = 0 ]; then
  install -d "$(dirname "$pol")"
  echo '{"BraveShieldsDisabledForUrls": ["https://*", "http://*"]}' > "$pol"
else
  rm -f "$pol"
fi

# Wi-Fi: a NetworkManager profile (root-only, holds the PSK). NM handles reconnects;
# if this network is absent, nm-applet in the session lets the user pick another.
nm=/etc/NetworkManager/system-connections/librekiosk-wifi.nmconnection
if [ "$LK_WIFI" = 1 ]; then
  ( umask 077
    {
      printf '[connection]\nid=librekiosk-wifi\nuuid=%s\ntype=wifi\nautoconnect=%s\nautoconnect-retries=0\n' \
        "$LK_WIFI_UUID" "$([ "$LK_WIFI_AUTO" = 1 ] && echo true || echo false)"
      printf '\n[wifi]\nmode=infrastructure\nssid=%s\n' "$LK_SSID"
      [ -n "$LK_PSK" ] && printf '\n[wifi-security]\nkey-mgmt=wpa-psk\npsk=%s\n' "$LK_PSK"
      printf '\n[ipv4]\nmethod=auto\n\n[ipv6]\nmethod=auto\n'
    } > "$nm.tmp" )
  mv "$nm.tmp" "$nm"
else
  rm -f "$nm"
fi
if systemd_up && systemctl is-active -q NetworkManager; then nmcli connection reload || true; fi

echo "librekiosk: configuration applied"
