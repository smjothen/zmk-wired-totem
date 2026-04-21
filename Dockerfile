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
#   firmware/totem.svg, firmware/overview.svg, firmware/totem.yaml

# ── Stage 1: ZMK build image + keymap-drawer ────────────────────────────────

FROM zmkfirmware/zmk-build-arm:3.5 AS base

# Install pip and Python packages for keymap drawing.
RUN apt-get update && apt-get install -y --no-install-recommends python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir --break-system-packages \
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

# Copy full config tree, module, and draw scripts.
COPY config/ config/
COPY totem-module/ totem-module/
COPY keymap_drawer.config.yaml .
COPY draw/ draw/

ARG BOARD=xiao_rp2040//zmk
ENV ZMK_APP=zmk/app
ENV BOARD=${BOARD}
ENV ZMK_CONFIG=/zmk-config/config
ENV KEYMAP_FILE=config/totem.keymap
ENV ZMK_EXTRA_MODULES=/zmk-config/totem-module
ENV ZEPHYR_BASE=/zmk-config/zephyr
ENV STRIP_SVG_LABELS=layer

# Build script: accepts "left", "right", "draw", "all" (default: "all").
COPY <<'ENTRYPOINT' /usr/local/bin/build.sh
#!/bin/bash
set -euo pipefail

TARGET="${1:-all}"
OUTDIR="/out"

build_left() {
    echo "=== Building left half ==="
    west build -s "$ZMK_APP" -d build/left -b "$BOARD" -- \
        -DSHIELD=totem_left -DZMK_CONFIG="$ZMK_CONFIG" \
        -DZMK_EXTRA_MODULES="$ZMK_EXTRA_MODULES"
    cp build/left/zephyr/zmk.uf2 "$OUTDIR/totem_left.uf2"
    echo "=== Left half: $OUTDIR/totem_left.uf2 ==="
}

build_right() {
    echo "=== Building right half ==="
    west build -s "$ZMK_APP" -d build/right -b "$BOARD" -- \
        -DSHIELD=totem_right -DZMK_CONFIG="$ZMK_CONFIG" \
        -DZMK_EXTRA_MODULES="$ZMK_EXTRA_MODULES"
    cp build/right/zephyr/zmk.uf2 "$OUTDIR/totem_right.uf2"
    echo "=== Right half: $OUTDIR/totem_right.uf2 ==="
}

draw_keymap() {
    echo "=== Drawing keymap ==="
    mkdir -p draw draw/layers
    local layer_tmp
    layer_tmp="$(mktemp -d)"
    keymap -c keymap_drawer.config.yaml parse \
        -z "$KEYMAP_FILE" -c 10 \
        > draw/totem.raw.yaml
    python3 draw/combo_layer.py < draw/totem.raw.yaml > draw/totem.yaml
    python3 draw/make_overview.py draw/totem.raw.yaml draw/totem-overview.yaml
    python3 draw/split_layers.py draw/totem.raw.yaml "$layer_tmp" --prefix totem
    python3 draw/make_layer_combo.py draw/totem.raw.yaml draw/totem-base-combo.yaml Base
    keymap -c keymap_drawer.config.yaml draw draw/totem.yaml > draw/totem.svg
    keymap -c keymap_drawer.config.yaml draw draw/totem-overview.yaml > draw/overview.svg
    keymap -c keymap_drawer.config.yaml draw draw/totem-base-combo.yaml > draw/totem-base-combo.svg
    rm -f draw/layers/*.svg
    for layer_yaml in "$layer_tmp"/*.yaml; do
        layer_svg="draw/layers/$(basename "${layer_yaml%.yaml}.svg")"
        keymap -c keymap_drawer.config.yaml draw "$layer_yaml" > "$layer_svg"
        case "$STRIP_SVG_LABELS" in
            all)
                python3 draw/hide_layer_labels.py --mode all < "$layer_svg" > "$layer_svg.tmp" && mv "$layer_svg.tmp" "$layer_svg"
                ;;
            layer)
                python3 draw/hide_layer_labels.py --mode layer < "$layer_svg" > "$layer_svg.tmp" && mv "$layer_svg.tmp" "$layer_svg"
                ;;
        esac
    done
    python3 draw/hide_layer_labels.py --mode layer < draw/overview.svg > draw/overview.svg.tmp && mv draw/overview.svg.tmp draw/overview.svg
    python3 draw/hide_layer_labels.py --mode layer < draw/totem-base-combo.svg > draw/totem-base-combo.svg.tmp && mv draw/totem-base-combo.svg.tmp draw/totem-base-combo.svg
    cp draw/totem.yaml draw/totem.svg draw/overview.svg draw/totem-base-combo.svg "$OUTDIR/"
    cp draw/layers/*.svg "$OUTDIR/"
    rm -rf "$layer_tmp" draw/totem.raw.yaml draw/totem-base-combo.yaml draw/totem-overview.yaml
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
