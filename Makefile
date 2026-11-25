SUDO := $(if $(filter 0,$(shell id -u)),,sudo)

.PHONY: help write-usb build-iso build-iso-docker install configure doctor update clean
help:
	@echo "make build-iso   build dist/librekiosk-amd64.iso (Debian 13 host only, root)"
	@echo "make build-iso-docker  same, inside a Debian trixie container (Ubuntu/any host with Docker)"
	@echo "make write-usb DEV=/dev/sdX  write the ISO + persistence partition to a USB stick (ERASES it)"
	@echo "make install     turn this Debian install into LibreKiosk (idempotent)"
	@echo "make configure   validate and apply /etc/librekiosk/librekiosk.yml"
	@echo "make doctor      check the installation"
	@echo "make update      APT upgrade + re-apply LibreKiosk"
	@echo "make clean       remove build/ and dist/"

build-iso:
	$(SUDO) scripts/build-iso.sh
# Ubuntu's live-build is too old for trixie; build in Debian instead.
build-iso-docker:
	docker run --rm --privileged -v "$(CURDIR)":/src -w /src debian:trixie bash -c \
	  'apt-get update && apt-get install -y live-build make xorriso && make build-iso'
write-usb:
	$(SUDO) scripts/write-usb.sh "$(DEV)"
install:
	$(SUDO) installer/install.sh
configure:
	$(SUDO) installer/configure.sh
doctor:
	installer/doctor.sh
update:
	$(SUDO) scripts/update.sh
clean:
	$(SUDO) rm -rf build dist
