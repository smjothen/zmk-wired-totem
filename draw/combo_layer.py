#!/usr/bin/env python3
"""Post-process keymap-drawer YAML to move combos onto a dedicated blank layer."""
import sys, yaml

data = yaml.safe_load(sys.stdin)

# Count keys per row from the first layer
first_layer = list(data["layers"].values())[0]
blank_layer = [[""] * len(row) for row in first_layer]

# Add a blank "Combos" layer
data["layers"]["Combos"] = blank_layer

# Point all combos to only the Combos layer
if "combos" in data:
    for combo in data["combos"]:
        combo["l"] = ["Combos"]

yaml.dump(data, sys.stdout, default_flow_style=None, allow_unicode=True, sort_keys=False)
