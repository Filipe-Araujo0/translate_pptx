#!/usr/bin/env python3
"""Replace PPTX text-map entries with translated values while keeping metadata intact."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any, Dict, List


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Create a translated copy of a PPTX text map by swapping the text field "
            "of each entry using a list of translated values (in order)."
        )
    )
    parser.add_argument(
        "--base-map",
        required=True,
        help="Path to the original *.text-map.json file.",
    )
    parser.add_argument(
        "--translated-values",
        required=True,
        help="Path to the JSON array containing the translated strings.",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Destination path for the translated map JSON file.",
    )
    return parser.parse_args()


def load_json(path: Path) -> Any:
    return json.loads(path.read_text())


def write_json(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, ensure_ascii=True, indent=2))


def merge_translations(
    base_map: Dict[str, Any], translated_values: List[Any]
) -> Dict[str, Any]:
    entries = base_map.get("entries")
    assert isinstance(entries, list), "entries must be a list"
    assert len(entries) == len(translated_values), (
        "translated array must match entries length; "
        f"{len(entries)} entries != {len(translated_values)} translated items"
    )

    merged_entries: List[Dict[str, Any]] = []
    for entry, text in zip(entries, translated_values):
        assert isinstance(entry, dict), "entry must be a dict"
        assert isinstance(text, str), "translated value must be a string"
        new_entry = dict(entry)
        new_entry["text"] = text
        merged_entries.append(new_entry)

    merged = dict(base_map)
    merged["entries"] = merged_entries
    merged["entry_count"] = len(merged_entries)
    return merged


def main() -> None:
    args = parse_args()
    base_map_path = Path(args.base_map)
    translated_values_path = Path(args.translated_values)
    output_path = Path(args.output)

    base_map = load_json(base_map_path)
    translated_values = load_json(translated_values_path)
    assert isinstance(translated_values, list), (
        "translated values file must contain a JSON array"
    )

    merged = merge_translations(base_map, translated_values)
    write_json(output_path, merged)


if __name__ == "__main__":
    main()
