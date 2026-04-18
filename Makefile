# ZMK firmware build + keymap diagram generation for TOTEM
#
# Usage:
#   make              # build both halves + draw keymap (if changed)
#   make left         # build left half only
#   make right        # build right half only
#   make draw         # regenerate keymap diagram only
#   make clean        # remove build dirs and generated files
#   make flash-left   # copy left UF2 to RP2040 (must be in bootloader mode)
#   make flash-right  # copy right UF2 to RP2040 (must be in bootloader mode)
#
# Docker (no local toolchain needed):
#   make docker       # build both halves + draw via Docker
#   make docker-left  # left half only via Docker
#   make docker-right # right half only via Docker
#   make docker-draw  # keymap diagram only via Docker

SHELL := /bin/bash

ZMK_APP     := zmk/app
BOARD       := xiao_rp2040
ZMK_CONFIG  := $(CURDIR)/config
SHIELD_DIR  := config/boards/shields/totem

KEYMAP      := $(SHIELD_DIR)/totem.keymap
COMBOS      := $(SHIELD_DIR)/combos.dtsi
MOUSE       := $(SHIELD_DIR)/mouse.dtsi
LEADER      := $(SHIELD_DIR)/leader.dtsi
DRAW_CONFIG := keymap_drawer.config.yaml
DRAW_YAML   := draw/totem.yaml
DRAW_SVG    := draw/totem.svg

UF2_LEFT    := build/left/zephyr/zmk.uf2
UF2_RIGHT   := build/right/zephyr/zmk.uf2
UF2_VOLUME  := /Volumes/RPI-RP2

# All keymap sources that affect the diagram
KEYMAP_SRCS := $(KEYMAP) $(COMBOS) $(MOUSE) $(LEADER)

.PHONY: all left right draw clean flash-left flash-right docker docker-left docker-right docker-draw

all: left right draw

left: $(UF2_LEFT)
right: $(UF2_RIGHT)
draw: $(DRAW_SVG)

$(UF2_LEFT): $(wildcard $(SHIELD_DIR)/*) $(wildcard config/*.conf)
	west build -s $(ZMK_APP) -d build/left -b $(BOARD) -- \
		-DSHIELD=totem_left -DZMK_CONFIG="$(ZMK_CONFIG)"

$(UF2_RIGHT): $(wildcard $(SHIELD_DIR)/*) $(wildcard config/*.conf)
	west build -s $(ZMK_APP) -d build/right -b $(BOARD) -- \
		-DSHIELD=totem_right -DZMK_CONFIG="$(ZMK_CONFIG)"

$(DRAW_YAML): $(KEYMAP_SRCS) $(DRAW_CONFIG) draw/combo_layer.py
	@mkdir -p draw
	keymap -c $(DRAW_CONFIG) parse -z $(KEYMAP) -c 10 | python3 draw/combo_layer.py > $@

$(DRAW_SVG): $(DRAW_YAML)
	keymap -c $(DRAW_CONFIG) draw $< > $@
	@echo "Keymap diagram updated: $@"

clean:
	rm -rf build/left build/right
	rm -f $(DRAW_YAML) $(DRAW_SVG)

flash-left: $(UF2_LEFT)
	@test -d $(UF2_VOLUME) || { echo "ERROR: RP2040 not in bootloader mode ($(UF2_VOLUME) not found)"; exit 1; }
	cp -X $< $(UF2_VOLUME)/
	@echo "Flashed left half"

flash-right: $(UF2_RIGHT)
	@test -d $(UF2_VOLUME) || { echo "ERROR: RP2040 not in bootloader mode ($(UF2_VOLUME) not found)"; exit 1; }
	cp -X $< $(UF2_VOLUME)/
	@echo "Flashed right half"

# Docker targets
DOCKER_IMG := totem-zmk

docker: docker-build
	docker run --rm -v $(CURDIR)/firmware:/out $(DOCKER_IMG) all

docker-left: docker-build
	docker run --rm -v $(CURDIR)/firmware:/out $(DOCKER_IMG) left

docker-right: docker-build
	docker run --rm -v $(CURDIR)/firmware:/out $(DOCKER_IMG) right

docker-draw: docker-build
	docker run --rm -v $(CURDIR)/firmware:/out $(DOCKER_IMG) draw

docker-build:
	docker build -t $(DOCKER_IMG) .
