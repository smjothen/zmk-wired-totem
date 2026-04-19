#!/usr/bin/env python3
import argparse
import re
import sys


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=["layer", "all"], default="layer")
    args = parser.parse_args()

    svg = sys.stdin.read()
    if args.mode == "all":
        svg = re.sub(r"\s*<a [^>]+>\s*<text[^>]*>.*?</text>\s*</a>", "", svg, flags=re.DOTALL)
        svg = re.sub(r"\s*<text[^>]*>.*?</text>", "", svg, flags=re.DOTALL)
    else:
        svg = re.sub(r"\s*<text x=\"0\" y=\"28\" class=\"label\" id=\"[^\"]+\">.*?</text>", "", svg)
    sys.stdout.write(svg)


if __name__ == "__main__":
    main()
