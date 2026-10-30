# LibreKiosk

> **⚠️ BETA — nothing here has been tested yet.** The ISO has not been built, booted in QEMU, or run on
> real hardware (Dell Wyse 7010 included). Expect broken scripts. Feedback and issues are welcome.

A lightweight Smart TV Linux for old PCs and thin clients (first target: Dell Wyse 7010).
It is a regular Debian Stable (amd64) system: Xorg + Openbox + LightDM autologin, booting straight into
[Brave](https://brave.com) (from Brave's official APT repo). Wi-Fi via NetworkManager, phone remote via KDE Connect.
Everything is configured by one YAML file, `/etc/librekiosk/librekiosk.yml`. The normal desktop stays
available: right-click the desktop for the maintenance menu (quit Brave, Wi-Fi, terminal, reboot).

> **Security:** the default account is `libre` / `libre` (development default). Run `passwd` before using
> LibreKiosk on any untrusted network. Never commit real Wi-Fi passwords; use `wifi.secrets_file`.

## Quick start

| Goal | Command |
|---|---|
| Build the ISO (Debian/Ubuntu host, root) | `sudo apt install live-build && make build-iso` → `dist/librekiosk-amd64.iso` + `.sha256` |
| Convert an existing clean Debian install | `make install` (no disk changes, safe to re-run) |
| Apply edited YAML | edit `/etc/librekiosk/librekiosk.yml`, then `make configure` (or reboot) |
| Check the installation | `make doctor` |
| Upgrade everything | `make update` |

Docs: [installation](docs/installation.md) · [Wi-Fi](docs/wifi.md) · [Android remote](docs/remote-control.md)

## Layout

`live-build/` ISO definition · `installer/` install, configure (YAML validate+apply), doctor ·
`config/` Openbox, systemd, browser wrapper · `scripts/` build and update · `librekiosk.yml` default config.
The ISO build runs the very same `installer/install.sh` as the "existing Debian" path, so both match.

## Status

Beta MVP scaffold; see "Untested" in docs/installation.md for what is still unverified. License: MIT.
