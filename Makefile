SUDO := $(if $(filter 0,$(shell id -u)),,sudo)

.PHONY: help build-iso install configure doctor update clean
help:
	@echo "make build-iso   build dist/librekiosk-amd64.iso (Debian host, needs live-build, root)"
	@echo "make install     turn this Debian install into LibreKiosk (idempotent)"
	@echo "make configure   validate and apply /etc/librekiosk/librekiosk.yml"
	@echo "make doctor      check the installation"
	@echo "make update      APT upgrade + re-apply LibreKiosk"
	@echo "make clean       remove build/ and dist/"

build-iso:
	$(SUDO) scripts/build-iso.sh
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
