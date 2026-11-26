#!/usr/bin/env bash
# Clone a prepared "master" USB stick onto many sticks, guided on screen. Linux, root.
#   scripts/clone-usb.sh image   master stick -> dist/librekiosk-stick.img
#   scripts/clone-usb.sh write   dist/librekiosk-stick.img -> stick after stick (each one is ERASED)
set -euo pipefail
cd "$(dirname "$0")/.."
img=dist/librekiosk-stick.img
[ "$(uname)" = Linux ] && [ "$(id -u)" = 0 ] || { echo "needs Linux and root (make clone-image / make clone-usb)" >&2; exit 1; }

usb_disks() { lsblk -dnpo NAME,TYPE,TRAN | awk '$2=="disk" && $3=="usb"{print $1}'; }
describe() { lsblk -dpno NAME,SIZE,VENDOR,MODEL "$1"; }
unmount_all() { local p; for p in $(lsblk -nrpo NAME "$1" | tail -n +2); do umount "$p" 2>/dev/null || true; done; }
wait_gone() { while usb_disks | grep -qx "$1"; do sleep 1; done; }
# Prints the USB disk that appears after you plug it in: you never type a device name, and disks that were
# already plugged in (and anything not USB, like your system disk) can never be picked.
wait_new() {
	local before d; before=$(usb_disks)
	echo "$1" >&2
	while :; do
		d=$(usb_disks | grep -vxF -f <(printf '%s' "$before") | head -1 || true)
		[ -n "$d" ] && break
		sleep 1
	done
	udevadm settle; sleep 2
	echo "$d"
}

image_cmd() {
	mkdir -p dist
	local dev last b end
	dev=$(wait_new "Plug in the MASTER stick (already set up, with its logins) ...")
	echo "Found: $(describe "$dev")"
	lsblk -nro LABEL "$dev" | grep -qx persistence || { echo "$dev has no 'persistence' partition: is it a stick made by make write-usb?" >&2; exit 1; }
	last=$(lsblk -nrpo NAME,TYPE "$dev" | awk '$2=="part"{p=$1} END{print p}')
	b=${last#/dev/}
	end=$(( ($(cat "/sys/class/block/$b/start") + $(cat "/sys/class/block/$b/size")) * 512 ))   # end of the last partition
	unmount_all "$dev"
	e2fsck -fn "$last" >/dev/null 2>&1 || echo "WARNING: the persistence filesystem is not clean. Was the master shut down properly (not unplugged)?" >&2
	read -rp "Save $((end / 1024 / 1024)) MiB from $dev to $img? [Enter = yes, Ctrl+C = cancel] " _
	dd if="$dev" of="$img" bs=16M iflag=count_bytes count="$end" status=progress
	sync
	( cd dist && sha256sum "${img#dist/}" > "${img#dist/}.sha256" )
	echo "Image saved: $img. Remove the master stick now."
	wait_gone "$dev"
	echo "Next: make clone-usb"
}

write_cmd() {
	[ -f "$img" ] || { echo "no $img: run make clone-image first" >&2; exit 1; }
	local size n=0 dev cap a; size=$(stat -c%s "$img")
	trap 'echo; echo "Finished: $n stick(s) cloned."; exit 0' INT
	echo "Image: $img ($((size / 1024 / 1024)) MiB). Every stick you plug in is ERASED (after you confirm). Ctrl+C to finish."
	while :; do
		dev=$(wait_new "[$n done] Plug in the next NEW stick ...")
		lsblk -nro MOUNTPOINT "$dev" | grep -qx / && { echo "$dev holds the running system: skipped" >&2; wait_gone "$dev"; continue; }
		cap=$(blockdev --getsize64 "$dev")
		if [ "$cap" -lt "$size" ]; then
			echo "Found $(describe "$dev"): too small for the image. Remove it and use a bigger one."; wait_gone "$dev"; continue
		fi
		echo "Found: $(describe "$dev")"
		read -rp "ERASE it and clone? [Enter = yes, s = skip] " a
		if [ "$a" != s ]; then
			unmount_all "$dev"
			if dd if="$img" of="$dev" bs=16M conv=fsync status=progress && sync && cmp -n "$size" "$img" "$dev"; then
				n=$((n + 1)); echo "OK: stick #$n verified."
			else
				echo "FAILED on $dev: do not use this stick." >&2
			fi
		fi
		echo "Remove the stick now ..."; wait_gone "$dev"
	done
}

case "${1:-}" in
	image) image_cmd ;;
	write) write_cmd ;;
	*) echo "usage: $0 image|write" >&2; exit 1 ;;
esac
