#!/usr/bin/env bash
# Write dist/librekiosk-amd64.iso to a USB stick and add the "persistence" partition. ERASES the stick.
# Usage (Linux, root): scripts/write-usb.sh /dev/sdX
set -euo pipefail
dev=${1:-}; iso=$(dirname "$0")/../dist/librekiosk-amd64.iso
[ "$(uname)" = Linux ] && [ "$(id -u)" = 0 ] || { echo "needs Linux and root (make write-usb DEV=/dev/sdX)" >&2; exit 1; }
[ -b "$dev" ] && [ -f "$iso" ] || { echo "usage: $0 /dev/sdX   (and build the ISO first: dist/librekiosk-amd64.iso)" >&2; exit 1; }
[ "$(lsblk -dno TYPE "$dev")" = disk ] || { echo "$dev must be a whole disk, not a partition" >&2; exit 1; }
# Refuse anything that is not a removable/USB disk, or that holds the running system.
[ "$(lsblk -dno RM,TRAN "$dev" | tr -s ' ' | grep -cE '^1 |usb')" -gt 0 ] || { echo "$dev is not a removable/USB disk: refusing" >&2; exit 1; }
lsblk -nro MOUNTPOINT "$dev" | grep -qx / && { echo "$dev holds the running system: refusing" >&2; exit 1; }
lsblk -po NAME,SIZE,MODEL,TRAN "$dev"
read -rp "ERASE $dev and write LibreKiosk? Type the device name to confirm: " ans
[ "$ans" = "$dev" ] || { echo aborted >&2; exit 1; }

for p in $(lsblk -nrpo NAME "$dev" | tail -n +2); do umount "$p" 2>/dev/null || true; done
dd if="$iso" of="$dev" bs=4M status=progress conv=fsync
sync
# The hybrid ISO has an iso9660 signature and a 2048-vs-512 block warning (expected), and sfdisk may exit non-zero
# because the kernel cannot re-read the table. So judge by the result: did a new partition appear?
before=$(lsblk -nrpo NAME,TYPE "$dev" | grep -c ' part$' || true)
echo ',,L' | sfdisk --append --force --wipe never --wipe-partitions never "$dev" || echo "sfdisk exited non-zero; checking the result" >&2
partprobe "$dev" 2>/dev/null || blockdev --rereadpt "$dev" 2>/dev/null || true
udevadm settle; sleep 2
after=$(lsblk -nrpo NAME,TYPE "$dev" | grep -c ' part$' || true)
[ "$after" -gt "$before" ] || { echo "FAIL: no new partition was created on $dev ($before -> $after)" >&2; exit 1; }
part=$(lsblk -nrpo NAME,TYPE "$dev" | awk '$2=="part"{p=$1} END{print p}')   # the last partition = the new one
mkfs.ext4 -qF -L persistence "$part"
mnt=$(mktemp -d); trap 'umount "$mnt" 2>/dev/null; rmdir "$mnt"' EXIT
mount "$part" "$mnt"
echo "/home union" > "$mnt/persistence.conf"
sync

# Self-check: fail loudly if anything did not land.
[ "$(cat "$mnt/persistence.conf")" = "/home union" ] || { echo "FAIL: persistence.conf missing" >&2; exit 1; }
[ "$(blkid -s LABEL -o value "$part")" = persistence ] || { echo "FAIL: label is not 'persistence'" >&2; exit 1; }
cmp -n "$(stat -c%s "$iso")" "$iso" "$dev" || { echo "FAIL: ISO on the stick differs from dist/" >&2; exit 1; }
echo "OK: $dev ready (ISO verified, $part labeled persistence, persistence.conf written)."
