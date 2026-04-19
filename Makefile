# TOTEM Docker-only build helpers
#
# Usage:
#   make              # build both halves + draw keymap via Docker
#   make left         # build left half only via Docker
#   make right        # build right half only via Docker
#   make draw         # regenerate keymap diagram only via Docker
#   make clean        # remove generated firmware outputs
#   make flash-left   # copy left UF2 to RP2040 (must be in bootloader mode)
#   make flash-right  # copy right UF2 to RP2040 (must be in bootloader mode)

SHELL := /bin/bash

DOCKER_IMG := totem-zmk
BOARD := xiao_rp2040//zmk
OUTDIR := $(CURDIR)/firmware
STRIP_SVG_LABELS ?= layer
UF2_LEFT := $(OUTDIR)/totem_left.uf2
UF2_RIGHT := $(OUTDIR)/totem_right.uf2
DRAW_YAML := $(OUTDIR)/totem.yaml
DRAW_SVG := $(OUTDIR)/totem.svg
UF2_VOLUME := /Volumes/RPI-RP2

.PHONY: all left right draw clean flash-left flash-right docker-build

all: docker-build
	@mkdir -p "$(OUTDIR)"
	docker run --rm -e STRIP_SVG_LABELS="$(STRIP_SVG_LABELS)" -v "$(OUTDIR)":/out $(DOCKER_IMG) all

left: docker-build
	@mkdir -p "$(OUTDIR)"
	docker run --rm -e STRIP_SVG_LABELS="$(STRIP_SVG_LABELS)" -v "$(OUTDIR)":/out $(DOCKER_IMG) left

right: docker-build
	@mkdir -p "$(OUTDIR)"
	docker run --rm -e STRIP_SVG_LABELS="$(STRIP_SVG_LABELS)" -v "$(OUTDIR)":/out $(DOCKER_IMG) right

draw: docker-build
	@mkdir -p "$(OUTDIR)"
	docker run --rm -e STRIP_SVG_LABELS="$(STRIP_SVG_LABELS)" -v "$(OUTDIR)":/out $(DOCKER_IMG) draw

clean:
	rm -rf "$(OUTDIR)"

flash-left: $(UF2_LEFT)
	@test -d "$(UF2_VOLUME)" || { echo "ERROR: RP2040 not in bootloader mode ($(UF2_VOLUME) not found)"; exit 1; }
	cp -X "$<" "$(UF2_VOLUME)/"
	@echo "Flashed left half"

flash-right: $(UF2_RIGHT)
	@test -d "$(UF2_VOLUME)" || { echo "ERROR: RP2040 not in bootloader mode ($(UF2_VOLUME) not found)"; exit 1; }
	cp -X "$<" "$(UF2_VOLUME)/"
	@echo "Flashed right half"

$(UF2_LEFT):
	@$(MAKE) left

$(UF2_RIGHT):
	@$(MAKE) right

docker-build:
	docker build --build-arg BOARD="$(BOARD)" -t $(DOCKER_IMG) .
