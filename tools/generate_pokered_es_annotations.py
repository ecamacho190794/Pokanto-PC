#!/usr/bin/env python3
"""Create function-entry annotations from the Pokered-es RGBDS symbol file.

Pokered-es symbols include local labels and data labels. The recompiler's
conservative symbol import names code but does not treat every symbol as a
function. Seed only non-local labels whose first ROM byte is a legal LR35902
opcode; this avoids the broad pointer scan that mistakes tables for code.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path


SYMBOL_RE = re.compile(r"^([0-9a-fA-F]{2}):([0-9a-fA-F]{4})\s+(\S+)\s*$")
INVALID_OPCODES = {0xD3, 0xDB, 0xDD, 0xE3, 0xE4, 0xEB, 0xEC, 0xED, 0xF4, 0xFC, 0xFD}
DATA_PREFIXES = ("SFX_", "Music_", "ToggleData_")
DATA_SUFFIXES = ("_id", "TextPointers", "Texts", "Anim")
KNOWN_DATA_LABELS = {
    "CredMon",
    "CredProducer",
    "WhichTechniqueString",
    "LinkCableInfoTexts",
    "ViridianBlackboardStatusPointers",
}


def is_known_data(name: str) -> bool:
    return name.startswith(DATA_PREFIXES) or name.endswith(DATA_SUFFIXES) or name in KNOWN_DATA_LABELS


def rom_offset(bank: int, address: int) -> int:
    return address if address < 0x4000 else bank * 0x4000 + address - 0x4000


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--symbols", type=Path, required=True)
    parser.add_argument("--rom", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    rom = args.rom.read_bytes()
    symbols: list[tuple[int, int, str]] = []
    for line in args.symbols.read_text(encoding="utf-8").splitlines():
        match = SYMBOL_RE.match(line)
        if not match:
            continue
        bank, address = int(match.group(1), 16), int(match.group(2), 16)
        name = match.group(3)
        if address < 0x8000:
            symbols.append((bank, address, name))

    symbols.sort()
    next_global: dict[tuple[int, int], int] = {}
    globals_by_bank: dict[int, list[int]] = {}
    for bank, address, name in symbols:
        if "." not in name:
            globals_by_bank.setdefault(bank, []).append(address)
    for bank, addresses in globals_by_bank.items():
        unique = sorted(set(addresses))
        for index, address in enumerate(unique[:-1]):
            next_global[(bank, address)] = unique[index + 1]

    annotations: list[str] = []
    seen: set[tuple[int, int]] = set()
    data_seen: set[tuple[int, int]] = set()
    for bank, address, name in symbols:
        # Dotted symbols are local labels inside a routine; their owning
        # non-local label already seeds the routine.
        if "." in name:
            continue
        key = (bank, address)
        if is_known_data(name):
            end = next_global.get(key)
            if key not in data_seen and end is not None and end > address:
                annotations.append(f"data {bank:02x}:{address:04x} {end - address} {name}")
                data_seen.add(key)
            continue
        offset = rom_offset(bank, address)
        if offset >= len(rom) or rom[offset] in INVALID_OPCODES:
            continue
        if key in seen:
            continue
        seen.add(key)
        annotations.append(f"function {bank:02x}:{address:04x} {name}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(annotations) + "\n", encoding="utf-8")
    print(f"Wrote {len(annotations)} Pokered-es function/data annotations to {args.output}")


if __name__ == "__main__":
    main()
