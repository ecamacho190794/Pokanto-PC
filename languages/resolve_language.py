#!/usr/bin/env python3
"""Map a CLI language name or alias to languages/<id>."""
from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        return 1
    want = sys.argv[1]
    root = Path(__file__).resolve().parent
    for lang_dir in sorted(p for p in root.iterdir() if p.is_dir()):
        variant = lang_dir / "variant.json"
        if not variant.is_file():
            continue
        data = json.loads(variant.read_text(encoding="utf-8"))
        names = {lang_dir.name, data.get("id", "")}
        names.update(data.get("aliases", []))
        if want in names:
            print(lang_dir.name)
            return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
