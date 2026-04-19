#!/usr/bin/env python3
import argparse
import copy
import re
from pathlib import Path

import yaml


def slugify(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    return slug or "layer"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_yaml")
    parser.add_argument("output_dir")
    parser.add_argument("--prefix", default="totem")
    parser.add_argument("--combos-name", default="Combos")
    args = parser.parse_args()

    with open(args.input_yaml, "r", encoding="utf-8") as infile:
        data = yaml.safe_load(infile)

    layers = data.get("layers", {})
    layer_names = list(layers.keys())
    if not layer_names:
        raise SystemExit("No layers found in parsed keymap YAML")

    blank_layer = [[""] * len(row) for row in layers[layer_names[0]]]
    combos = data.get("combos", [])
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    base_data = {k: copy.deepcopy(v) for k, v in data.items() if k not in {"layers", "combos"}}

    for layer_name in layer_names:
        layer_data = copy.deepcopy(base_data)
        layer_data["layers"] = {layer_name: copy.deepcopy(layers[layer_name])}
        output_path = output_dir / f"{args.prefix}-{slugify(layer_name)}.yaml"
        with open(output_path, "w", encoding="utf-8") as outfile:
            yaml.safe_dump(layer_data, outfile, sort_keys=False, allow_unicode=True)

    combos_data = copy.deepcopy(base_data)
    combos_data["layers"] = {args.combos_name: copy.deepcopy(blank_layer)}
    if combos:
        combos_data["combos"] = []
        for combo in combos:
            combo_copy = copy.deepcopy(combo)
            combo_copy["l"] = [args.combos_name]
            combos_data["combos"].append(combo_copy)

    combos_path = output_dir / f"{args.prefix}-{slugify(args.combos_name)}.yaml"
    with open(combos_path, "w", encoding="utf-8") as outfile:
        yaml.safe_dump(combos_data, outfile, sort_keys=False, allow_unicode=True)


if __name__ == "__main__":
    main()
