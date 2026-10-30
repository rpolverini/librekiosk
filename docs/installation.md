# Installation

## A. Debian Live ISO

Build on a Debian/Ubuntu machine (not macOS), as root, with network access:

    sudo apt install live-build
    make build-iso          # -> dist/librekiosk-amd64.iso and dist/librekiosk-amd64.iso.sha256

Test in QEMU: `qemu-system-x86_64 -m 4096 -enable-kvm -cdrom dist/librekiosk-amd64.iso`
(add `-bios /usr/share/ovmf/OVMF.fd` for UEFI). Write to USB with `dd if=dist/librekiosk-amd64.iso of=/dev/sdX bs=4M status=progress`.
It boots as a live system, auto-logs in as `libre` (password `libre`) and opens Brave.
Live mode keeps nothing across reboots.

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

Edit `/etc/librekiosk/librekiosk.yml` (annotated example: `librekiosk.yml`). It is validated before anything is
applied; an invalid file changes nothing. Applied at every boot, or run `make configure`.
Hiding the address bar or tabs runs Brave in `--app` mode, which hides both.

## Untested

Written without access to a Debian host. Needs a first real run of: `make build-iso`, QEMU boot, live-config
reusing the pre-created `libre` user, the Brave policy used for `shields: false`, KDE Connect pairing, Wyse 7010.
