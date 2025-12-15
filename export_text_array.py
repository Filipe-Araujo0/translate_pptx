#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import List


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract the text fields from the text-map JSON in source order."
    )
    parser.add_argument(
        "--source",
        type=Path,
        help="Path to the text-map JSON produced earlier.",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Destination JSON file (defaults to <source-stem>.text-values.json).",
    )
    return parser.parse_args()


def load_texts(source: Path) -> List[str]:
    data = json.loads(source.read_text())
    entries = data["entries"]
    texts: List[str] = []
    for idx, entry in enumerate(entries, start=1):
        assert "text" in entry, f"Entry {idx} missing text field"
        texts.append(entry["text"])
    return texts


def main() -> None:
    args = parse_args()
    source = args.source
    assert source.exists(), f"Source file not found: {source}"
    texts = load_texts(source)
    if args.output is not None:
        destination = args.output
    else:
        destination = source.with_name(f"{source.stem}.text-values.json")
    destination.write_text(json.dumps(texts, ensure_ascii=True, indent=2))
    print(f"Wrote {len(texts)} texts to {destination}")


if __name__ == "__main__":
    main()
