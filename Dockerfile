# Multi-stage Dockerfile for building TOTEM ZMK firmware + keymap diagrams.
#
# Usage:
#   docker build -t totem-zmk .
#   docker run --rm -v $(pwd)/firmware:/out totem-zmk              # build both halves + draw
#   docker run --rm -v $(pwd)/firmware:/out totem-zmk left          # left half only
#   docker run --rm -v $(pwd)/firmware:/out totem-zmk right         # right half only
#   docker run --rm -v $(pwd)/firmware:/out totem-zmk draw          # keymap diagram only
#   docker run --rm -v $(pwd)/firmware:/out totem-zmk all           # everything
#
# Outputs are copied to the mounted /out directory:
#   firmware/totem_left.uf2, firmware/totem_right.uf2
#   firmware/totem.svg, firmware/totem.yaml

# ── Stage 1: Python 3.12 + Zephyr SDK + build tools ─────────────────────────

FROM python:3.12-slim AS base

# Install system build dependencies.
RUN apt-get update && apt-get install -y --no-install-recommends \
    git cmake ninja-build gperf ccache device-tree-compiler wget xz-utils \
    file make gcc g++ libmagic1 \
    && rm -rf /var/lib/apt/lists/*

# Install Zephyr SDK (arm toolchain only — RP2040 uses the ARM core).
ARG ZEPHYR_SDK_VERSION=0.17.0
ARG ZEPHYR_SDK_INSTALL_DIR=/opt/zephyr-sdk-${ZEPHYR_SDK_VERSION}
RUN wget -q "https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VERSION}/zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-$(uname -m)_minimal.tar.xz" \
    && tar xf zephyr-sdk-*.tar.xz -C /opt \
    && rm zephyr-sdk-*.tar.xz \
    && ${ZEPHYR_SDK_INSTALL_DIR}/setup.sh -t arm-zephyr-eabi -c

ENV ZEPHYR_SDK_INSTALL_DIR=${ZEPHYR_SDK_INSTALL_DIR}

# Install Python packages.
RUN pip install --no-cache-dir \
    west \
    keymap-drawer==0.23.0 \
    protobuf \
    grpcio-tools \
    pyelftools

# ── Stage 2: Workspace init + west update ────────────────────────────────────

FROM base AS workspace

WORKDIR /zmk-config

# Copy only manifest first for layer caching (west update is slow).
COPY config/west.yml config/west.yml

# Initialize west workspace and fetch all modules.
RUN west init -l config && west update && west zephyr-export

# ── Stage 3: Build ───────────────────────────────────────────────────────────

FROM workspace AS builder

# Copy full config tree (shield files, keymap, confs, draw scripts).
COPY config/ config/
COPY keymap_drawer.config.yaml .
COPY draw/ draw/

ENV ZMK_APP=zmk/app
ENV BOARD=xiao_rp2040
ENV ZMK_CONFIG=/zmk-config/config
ENV SHIELD_DIR=config/boards/shields/totem
ENV ZEPHYR_BASE=/zmk-config/zephyr

# Build script: accepts "left", "right", "draw", "all" (default: "all").
COPY <<'ENTRYPOINT' /usr/local/bin/build.sh
#!/bin/bash
set -euo pipefail

TARGET="${1:-all}"
OUTDIR="/out"

build_left() {
    echo "=== Building left half ==="
    west build -s "$ZMK_APP" -d build/left -b "$BOARD" -- \
        -DSHIELD=totem_left -DZMK_CONFIG="$ZMK_CONFIG"
    cp build/left/zephyr/zmk.uf2 "$OUTDIR/totem_left.uf2"
    echo "=== Left half: $OUTDIR/totem_left.uf2 ==="
}

build_right() {
    echo "=== Building right half ==="
    west build -s "$ZMK_APP" -d build/right -b "$BOARD" -- \
        -DSHIELD=totem_right -DZMK_CONFIG="$ZMK_CONFIG"
    cp build/right/zephyr/zmk.uf2 "$OUTDIR/totem_right.uf2"
    echo "=== Right half: $OUTDIR/totem_right.uf2 ==="
}

draw_keymap() {
    echo "=== Drawing keymap ==="
    mkdir -p draw
    keymap -c keymap_drawer.config.yaml parse \
        -z "$SHIELD_DIR/totem.keymap" -c 10 \
        | python3 draw/combo_layer.py > draw/totem.yaml
    keymap -c keymap_drawer.config.yaml draw draw/totem.yaml > draw/totem.svg
    cp draw/totem.yaml draw/totem.svg "$OUTDIR/"
    echo "=== Keymap diagram: $OUTDIR/totem.svg ==="
}

mkdir -p "$OUTDIR"

case "$TARGET" in
    left)  build_left ;;
    right) build_right ;;
    draw)  draw_keymap ;;
    all)   build_left; build_right; draw_keymap ;;
    *)     echo "Unknown target: $TARGET (use left, right, draw, all)"; exit 1 ;;
esac

echo "=== Done ==="
ENTRYPOINT

RUN chmod +x /usr/local/bin/build.sh

ENTRYPOINT ["build.sh"]
CMD ["all"]
