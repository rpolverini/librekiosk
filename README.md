# LibreKiosk

> **⚠️ BETA — nothing here has been tested yet.** The ISO has not been built, booted in QEMU, or run on
> real hardware (Dell Wyse 7010 included). Expect broken scripts. Feedback and issues are welcome.

A lightweight Smart TV Linux for old PCs and thin clients (first target: Dell Wyse 7010).
It is a regular Debian Stable (amd64) system: Xorg + Openbox + LightDM autologin, booting straight into
[Brave](https://brave.com) (from Brave's official APT repo). Wi-Fi via NetworkManager, phone remote via KDE Connect.
Everything is configured by one YAML file, `/etc/librekiosk/librekiosk.yml` (see [Configuration](#configuration-and-branding)). The normal desktop stays
available: right-click the desktop for the maintenance menu (quit Brave, Wi-Fi, terminal, reboot).

> **Security:** the default account is `libre` / `libre` (development default). Run `passwd` before using
> LibreKiosk on any untrusted network. Never commit real Wi-Fi passwords; use `wifi.secrets_file`.

## Quick start

| Goal | Command |
|---|---|
| Build the ISO (any Linux with Docker) | `make build-iso-docker` → `dist/librekiosk-amd64.iso` + `.sha256` |
| Convert an existing clean Debian install | `make install` (no disk changes, safe to re-run) |
| Apply edited YAML | edit `/etc/librekiosk/librekiosk.yml`, then `make configure` (or reboot) |
| Check the installation | `make doctor` |
| Upgrade everything | `make update` |

### Write the ISO to a USB stick (Linux)

```bash
(cd dist && sha256sum -c librekiosk-amd64.iso.sha256)   # verify
lsblk                                           # find the stick, e.g. /dev/sdX (check the size!)
sudo umount /dev/sdX* 2>/dev/null
sudo dd if=dist/librekiosk-amd64.iso of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

`dd` erases the whole target device. A wrong `/dev/sdX` (your system disk) destroys your data. On macOS or Windows, use balenaEtcher or Rufus. Boot the stick (UEFI or legacy) from the BIOS boot menu.

## Troubleshooting

**It boots, you log in (or autologin runs) and you land on the login screen again.** The graphical session
started and died. It is usually hardware-specific (graphics driver or firmware), so first try the same stick
on another PC. If it works there, the stick is fine and the first machine is the problem.

To find the cause on the failing machine:

1. At the login screen press `Ctrl+Alt+F2` and log in as `libre` / `libre` (`Ctrl+Alt+F1`/`F7` goes back).
2. Run the checks below and look for errors:

       tail -30 ~/.xsession-errors          # why Openbox/the session exited
       tail -40 /var/log/Xorg.0.log         # look for "(EE)" lines: no screens found, driver failed
       journalctl -b -u lightdm | tail -30
       sudo dmesg | grep -iE "firmware|drm|gpu"   # "failed to load firmware" = missing driver blob
       librekiosk-doctor                    # packages, services, user, config

3. Common fixes: a "no screens found" or `drm`/firmware error means a graphics driver issue. Try
   another video output, or at the boot menu press `e` and append `nomodeset` to the kernel line.
   Brave not starting: run `librekiosk-browser` from a terminal in the session and read its output.

## Configuration and branding

**Your config.** `librekiosk_example.yml` is the annotated template tracked in Git. Copy it to `librekiosk.yml`
(git-ignored, so Wi-Fi passwords never get committed) and edit it:

    cp librekiosk_example.yml librekiosk.yml    # then set wifi.ssid / wifi.password / browser.homepage

`make build-iso` bakes `librekiosk.yml` into the ISO (the example if you have none), so every PC installed from
that ISO starts with your Wi-Fi and homepage. The password sits in plain text inside the ISO and in
`/etc/librekiosk/librekiosk.yml`: do not share that ISO outside your organization.

**Your look.** Replace the files in `live-build/config/branding/` (same names) and rebuild:

| File | Used for |
|---|---|
| `splash.png` | boot menu background, 640x480 |
| `fondo.png` | desktop wallpaper and boot splash (scaled to fit, centred) |

Boot menu timeout (2.5 s; 3 s on UEFI) and title: `live-build/config/hooks/normal/0200-bootmenu.hook.binary`.

## Logins that persist (Netflix, etc.), then lock

Brave keeps cookies and saved passwords in `~/.config/BraveSoftware`. A live USB runs from RAM, so by default
**everything is lost at reboot**. Pick one:

1. **Install to disk** (`make install` on Debian): the profile persists on its own.
2. **Live USB with persistence:** one command writes the ISO, adds the `persistence` partition and checks the result
   (Linux, root; `/dev/sdX` = the stick, check with `lsblk`; it ERASES the stick and refuses non-USB disks):

       make write-usb DEV=/dev/sdX

   It prints `OK: ... ready` only if the ISO on the stick matches `dist/`, the partition is labeled `persistence`
   and `persistence.conf` (`/home union`) exists. For 100 sticks, prepare one this way and clone it with `dd`.

**Set up, then lock.** `browser.profile` in `librekiosk.yml`:

- `persistent` (default): everything Brave saves survives reboots. Log in to your services and tick "remember
  password", then close Brave with right-click desktop → **Quit Brave** (flushes cookies to disk).
- `locked`: each boot starts from a copy of that saved profile in RAM. The logins stay, but anything done during
  the session (new logins, history, changed settings) is gone at reboot. Set it, then `make configure` and reboot.

To change a login later, go back to `persistent`, fix it, quit Brave, and lock again. The saved password store is
unencrypted-at-rest (`--password-store=basic`): anyone with the disk or stick can read it.

Docs: [installation](docs/installation.md) · [Wi-Fi](docs/wifi.md) · [Android remote](docs/remote-control.md)

## Layout

`live-build/` ISO definition · `installer/` install, configure (YAML validate+apply), doctor ·
`config/` Openbox, systemd, browser wrapper · `scripts/` build and update · `librekiosk_example.yml` default config.
The ISO build runs the very same `installer/install.sh` as the "existing Debian" path, so both match.

## Status

Beta MVP scaffold; see "Untested" in docs/installation.md for what is still unverified. License: MIT.
