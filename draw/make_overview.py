#!/usr/bin/env python3
import argparse
import copy

import yaml


ABBREVIATIONS = {
    "Prev Win": "PWin",
    "Next Win": "NWin",
    "Prev Desk": "PDesk",
    "Next Desk": "NDesk",
    "Pin App": "PinA",
    "Pin Win": "PinW",
    "Smart Mouse": "SMouse",
    "Left Click": "LClk",
    "Right Click": "RClk",
    "Middle Click": "MClk",
}


def _extract_label(key):
    if isinstance(key, str):
        return key
    if isinstance(key, dict):
        return key.get("t")
    return None


def _is_transparent(key) -> bool:
    return isinstance(key, dict) and key.get("type") in {"trans", "held"}


def _base_key(key):
    if isinstance(key, str):
        return {"t": key}
    if isinstance(key, dict):
        return copy.deepcopy(key)
    return {"t": ""}


def _shorten_corner_label(label):
    if not isinstance(label, str):
        return label
    shortened = ABBREVIATIONS.get(label, label)
    if shortened.startswith("Alt+"):
        shortened = "⌥+" + shortened[4:]

    if shortened.startswith("$$mdi:") and shortened.endswith("$$"):
        return shortened
    if "$$mdi:" in shortened:
        return shortened

    if len(shortened) <= 7:
        return shortened

    words = [word for word in shortened.replace("+", " ").replace("/", " ").split() if word]
    if len(words) >= 2:
        compact = "".join(word[:3] for word in words[:2])
        if len(compact) <= 7:
            return compact

    return shortened[:7]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_yaml")
    parser.add_argument("output_yaml")
    parser.add_argument("--base", default="Base")
    parser.add_argument("--nav", default="Nav")
    parser.add_argument("--fn", default="Fn")
    parser.add_argument("--num", default="Num")
    parser.add_argument("--sys", default="Sys")
    parser.add_argument("--combos", default="Combos")
    args = parser.parse_args()

    with open(args.input_yaml, "r", encoding="utf-8") as infile:
        data = yaml.safe_load(infile)

    layers = data.get("layers", {})
    required = [args.base, args.nav, args.fn, args.num, args.sys]
    missing = [layer_name for layer_name in required if layer_name not in layers]
    if missing:
        raise SystemExit(f"Missing layer(s): {', '.join(missing)}")

    base_rows = layers[args.base]
    nav_rows = layers[args.nav]
    fn_rows = layers[args.fn]
    num_rows = layers[args.num]
    sys_rows = layers[args.sys]

    if not (len(base_rows) == len(nav_rows) == len(fn_rows) == len(num_rows) == len(sys_rows)):
        raise SystemExit("Layer row counts do not match")

    overview_rows = []
    for row_idx, base_row in enumerate(base_rows):
        nav_row = nav_rows[row_idx]
        fn_row = fn_rows[row_idx]
        num_row = num_rows[row_idx]
        sys_row = sys_rows[row_idx]

        if not (len(base_row) == len(nav_row) == len(fn_row) == len(num_row) == len(sys_row)):
            raise SystemExit(f"Layer column counts do not match in row {row_idx + 1}")

        row_out = []
        for col_idx, base_key in enumerate(base_row):
            merged_key = _base_key(base_key)

            nav_label = _extract_label(nav_row[col_idx])
            fn_label = _extract_label(fn_row[col_idx])
            num_label = _extract_label(num_row[col_idx])
            sys_label = _extract_label(sys_row[col_idx])

            if not _is_transparent(nav_row[col_idx]) and nav_label is not None:
                merged_key["tr"] = _shorten_corner_label(nav_label)
            if not _is_transparent(fn_row[col_idx]) and fn_label is not None:
                merged_key["tl"] = _shorten_corner_label(fn_label)
            if not _is_transparent(num_row[col_idx]) and num_label is not None:
                merged_key["bl"] = _shorten_corner_label(num_label)
            if not _is_transparent(sys_row[col_idx]) and sys_label is not None:
                merged_key["br"] = _shorten_corner_label(sys_label)

            row_out.append(merged_key)
        overview_rows.append(row_out)

    output = {k: copy.deepcopy(v) for k, v in data.items() if k not in {"layers", "combos"}}
    output["layers"] = {
        args.base: overview_rows,
        args.combos: copy.deepcopy(layers.get(args.combos, [[""] * len(r) for r in base_rows])),
    }

    combos = []
    for combo in data.get("combos", []):
        combo_copy = copy.deepcopy(combo)
        combo_copy["l"] = [args.combos]
        combos.append(combo_copy)
    if combos:
        output["combos"] = combos

    with open(args.output_yaml, "w", encoding="utf-8") as outfile:
        yaml.safe_dump(output, outfile, sort_keys=False, allow_unicode=True)


if __name__ == "__main__":
    main()
