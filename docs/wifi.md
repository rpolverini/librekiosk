# Wi-Fi

Preconfigure in `/etc/librekiosk/librekiosk.yml`:

    wifi:
      enabled: true
      ssid: "MyWifi"
      password: "real-password"
      autoconnect: true

Better, keep the password out of that file: create `/etc/librekiosk/secrets.yml` (see `config/examples/secrets.yml`),
`sudo chmod 600` it, and set `wifi.secrets_file: /etc/librekiosk/secrets.yml`. Then `make configure`.
`password: "CHANGE_ME"` means "not configured". Never commit real credentials.

This creates a root-only NetworkManager profile that connects at boot and reconnects automatically.

## If the network is unavailable

Use the network icon in the panel (nm-applet), or right-click the desktop → **Wi-Fi settings**,
to join any other network. NetworkManager remembers it. From a terminal: `nmcli device wifi connect SSID --ask`.
