# LibreKiosk

> **BETA.** The ISO builds and boots on a real Dell Wyse; Wi-Fi, Brave and persistence work there. Not yet
> verified: `locked` mode, KDE Connect pairing, `browser.shields: false`, other hardware. Feedback welcome.

A lightweight Smart TV Linux for old PCs and thin clients (first target: Dell Wyse 7010).
It is a regular Debian Stable (amd64) system: Xorg + Openbox + LightDM autologin, booting straight into
[Brave](https://brave.com) (from Brave's official APT repo). Wi-Fi via NetworkManager, phone remote via KDE Connect.
Everything is configured by one YAML file, `/etc/librekiosk/librekiosk.yml` (see [Configuration](#configuration-and-branding)). The normal desktop stays
available: right-click the desktop for the maintenance menu (quit Brave, Wi-Fi, terminal, reboot).

> **Security:** the default account is `libre` / `libre` (development default). Run `passwd` before using
> LibreKiosk on any untrusted network. Never commit real Wi-Fi passwords; use `wifi.secrets_file`.

## Which path do I use?

| I want... | Use | Where |
|---|---|---|
| **A USB stick I can boot on many PCs** (live system, logins saved on the stick) | `make build-iso-docker` then `make write-usb DEV=/dev/sdX` | the Deploy checklist below |
| **To turn a PC that already has Debian installed into LibreKiosk** (runs from its disk, no stick) | `make install` | [docs/installation.md](docs/installation.md) |

They are two different ways to get the same system; you do not need both. `write-usb` is the one that creates
the persistence partition (ISO + partition + checks in one go). `make install` needs no ISO and no extra partition:
the disk already persists.

Other commands: `make configure` (apply an edited YAML), `make doctor` (check), `make update` (upgrade).

## Deploy checklist (USB stick)

1. `git pull`, then `cp librekiosk_example.yml librekiosk.yml` (first time) and edit it: `wifi.ssid` exactly as
   the network is spelled (case-sensitive), `wifi.password`, `browser.homepage`, `hostname: "librekiosk-{id}"`.
   Then `make build-iso-docker` (Linux with Docker) → `dist/librekiosk-amd64.iso`.
2. `make write-usb DEV=/dev/sdX` (Linux, root). `lsblk` first: `sdX` is the stick, not your system disk. It erases the
   stick, writes the ISO, adds the `persistence` partition and checks everything; wait for `OK: ... ready`.
3. Boot the stick (UEFI or legacy, from the BIOS boot menu) and run `mount | grep sdb3` (your stick's name): it must
   show the partition mounted under `/home`.
4. Log in to your services, save a bookmark, quit with right-click desktop → **Quit Brave**, reboot and check it is
   still there. Then set `browser.profile: "locked"` if you want it frozen (see below).

For many PCs, see [Cloning many sticks](#cloning-many-sticks). On macOS/Windows you can write the ISO with
balenaEtcher or Rufus, but that gives **no persistence partition**; use a Linux machine for `write-usb`.

## Cloning many sticks

`make write-usb` takes minutes per stick and needs you to type the device. For many PCs, prepare **one master**
and clone it; the tools guide you on screen (plug a stick, it is detected, confirm, remove it, plug the next):

    make clone-image    # master stick  -> dist/librekiosk-stick.img   (ISO + 4 GiB persistence, about 5 GB)
    make clone-usb      # image -> stick after stick; each is verified byte by byte

You never type a device name: the stick you plug in is the one used, and only USB disks can be picked, so the
system disk is safe. Each stick must be at least as big as the image. Ctrl+C ends the loop and prints the count.

**Case 1: clean sticks (users log in themselves).** `make write-usb` once, boot it once to check it works,
`make clone-image`, `make clone-usb`. Use a master you have not logged in with.

**Case 2: pre-logged sticks (a company's internal system).** The logins travel inside the clones:
1. `make write-usb DEV=/dev/sdX`: this is the master. Boot it on a PC.
2. Log in to the services (Netflix, intranet, ...), tick "remember password", then right-click the desktop →
   **Quit Brave**.
3. Optional, to freeze it: in a terminal run `sudoedit /etc/librekiosk/librekiosk.yml`, set
   `browser.profile: "locked"`, then `sudo librekiosk-configure`. Reboot once and check the logins are still there.
4. Shut down properly from the menu (do not unplug the master, or the clone image may be inconsistent).
5. On the Linux machine: plug the master, `make clone-image`; then `make clone-usb` and feed it new sticks.

Caveats: every clone holds the same logins and saved passwords, readable by anyone who has the stick (the password
store is unencrypted), so treat each stick like a key. Some services limit simultaneous sessions or devices per
account, and some tie a login to a device, so test with two clones before making 100. Wi-Fi and homepage come from
the ISO's `librekiosk.yml`; to change them for a batch, rebuild the ISO and start from a new master.

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

Brave keeps cookies and saved passwords in `~/.config/BraveSoftware`. A live USB without the persistence partition runs
from RAM and **loses everything at reboot**. Pick one:

1. **Install to disk** (`make install` on Debian): the profile persists on its own.
2. **Live USB with persistence:** `make write-usb` (see the Deploy checklist) creates the partition and
   `persistence.conf` (`/home union`) for you.

**Set up, then lock.** `browser.profile` in `librekiosk.yml`:

- `persistent` (default): everything Brave saves survives reboots. Log in to your services and tick "remember
  password", then close Brave with right-click desktop → **Quit Brave** (flushes cookies to disk).
- `locked`: each boot starts from a copy of that saved profile in RAM. The logins stay, but anything done during
  the session (new logins, history, changed settings) is gone at reboot. On a persistent USB stick, edit `/etc/librekiosk/librekiosk.yml` on the stick itself (that folder persists), run
  `sudo librekiosk-configure`, and reboot.

To change a login later, go back to `persistent`, fix it, quit Brave, and lock again. The saved password store is
unencrypted-at-rest (`--password-store=basic`): anyone with the disk or stick can read it.

Docs: [installation](docs/installation.md) · [Wi-Fi](docs/wifi.md) · [Android remote](docs/remote-control.md)

## Layout

`live-build/` ISO definition · `installer/` install, configure (YAML validate+apply), doctor ·
`config/` Openbox, systemd, browser wrapper · `scripts/` build and update · `librekiosk_example.yml` default config.
The ISO build runs the very same `installer/install.sh` as the "existing Debian" path, so both match.

## Status

See "Still unverified" in docs/installation.md. License: MIT.
