#!/usr/bin/env python3
import argparse
import copy

import yaml


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_yaml")
    parser.add_argument("output_yaml")
    parser.add_argument("layer_name")
    args = parser.parse_args()

    with open(args.input_yaml, "r", encoding="utf-8") as infile:
        data = yaml.safe_load(infile)

    layers = data.get("layers", {})
    if args.layer_name not in layers:
        raise SystemExit(f"Layer not found: {args.layer_name}")

    output = {k: copy.deepcopy(v) for k, v in data.items() if k not in {"layers", "combos"}}
    output["layers"] = {args.layer_name: copy.deepcopy(layers[args.layer_name])}

    layer_combos = []
    for combo in data.get("combos", []):
        combo_layers = combo.get("l", list(layers.keys()))
        if args.layer_name in combo_layers:
            combo_copy = copy.deepcopy(combo)
            combo_copy["l"] = [args.layer_name]
            layer_combos.append(combo_copy)

    if layer_combos:
        output["combos"] = layer_combos

    with open(args.output_yaml, "w", encoding="utf-8") as outfile:
        yaml.safe_dump(output, outfile, sort_keys=False, allow_unicode=True)


if __name__ == "__main__":
    main()
