# Installation

## A. Debian Live ISO

Build on Linux with Docker and network access (not macOS):

    make build-iso-docker   # -> dist/librekiosk-amd64.iso and dist/librekiosk-amd64.iso.sha256

`make build-iso` (what the container runs) needs a Debian 13 host with a recent live-build; Ubuntu's is too old.

Test in QEMU: `qemu-system-x86_64 -m 4096 -enable-kvm -cdrom dist/librekiosk-amd64.iso`
(add `-bios /usr/share/ovmf/OVMF.fd` for UEFI). Write to USB (with the persistence partition) using `make write-usb DEV=/dev/sdX`; see the README.
It boots as a live system, auto-logs in as `libre` (password `libre`) and opens Brave.
Without the persistence partition, live mode keeps nothing across reboots.

### Persistent install on an SSD

The live ISO does not install itself. To get a persistent system (Brave sessions and cookies survive reboots):

1. Install Debian Stable from the official netinst image. At "Software selection" untick every desktop
   environment, keep only "standard system utilities" (SSH server optional).
2. Boot it, then:

       sudo apt install git make
       git clone <this repository> librekiosk && cd librekiosk
       sudo make install && sudo reboot

3. If the installer set up Ethernet/Wi-Fi in `/etc/network/interfaces`, NetworkManager will ignore those
   interfaces: delete those entries and reboot.

`make install` never formats or partitions anything and can be re-run at any time. It seeds
`/etc/librekiosk/librekiosk.yml` once and never overwrites your edits.

## Configuration

Edit `/etc/librekiosk/librekiosk.yml` (annotated template: `librekiosk_example.yml`; copy it to `librekiosk.yml` before `make install` or building the ISO to preseed it). It is validated before anything is
applied; an invalid file changes nothing. Applied at every boot, or run `make configure`.
Hiding the address bar or tabs runs Brave in `--app` mode, which hides both.

## Still unverified

Verified on a Dell Wyse: ISO build, boot, Wi-Fi, Brave, persistence. Not yet verified: QEMU, `browser.profile: locked`,
the Brave policy used for `shields: false`, KDE Connect pairing, other hardware.
