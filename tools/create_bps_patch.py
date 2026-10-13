#!/usr/bin/env python3
"""Create and self-verify a compact BPS patch from a stock ROM to a build ROM."""

from __future__ import annotations

import argparse
import binascii
from pathlib import Path


def encode_number(value: int) -> bytes:
    """Encode an unsigned BPS integer."""
    if value < 0:
        raise ValueError("BPS integers cannot be negative")
    result = bytearray()
    while True:
        byte = value & 0x7F
        value >>= 7
        if value == 0:
            result.append(byte | 0x80)
            return bytes(result)
        result.append(byte)
        value -= 1


def decode_number(data: bytes, offset: int) -> tuple[int, int]:
    value = 0
    shift = 1
    while True:
        if offset >= len(data):
            raise ValueError("truncated BPS varint")
        byte = data[offset]
        offset += 1
        value += (byte & 0x7F) * shift
        if byte & 0x80:
            return value, offset
        shift <<= 7
        value += shift


def crc32(data: bytes) -> int:
    return binascii.crc32(data) & 0xFFFFFFFF


def build_patch(source: bytes, target: bytes) -> bytes:
    patch = bytearray(b"BPS1")
    patch += encode_number(len(source))
    patch += encode_number(len(target))
    patch += encode_number(0)  # metadata size

    pos = 0
    while pos < len(target):
        if pos < len(source) and source[pos] == target[pos]:
            end = pos + 1
            while end < len(target) and end < len(source) and source[end] == target[end]:
                end += 1
            patch += encode_number(((end - pos - 1) << 2) | 0)  # SourceRead
        else:
            end = pos + 1
            while end < len(target):
                if end < len(source) and source[end] == target[end]:
                    # Keep tiny equal spans in TargetRead to avoid extra commands.
                    probe = end
                    while probe < min(len(target), len(source)) and source[probe] == target[probe]:
                        probe += 1
                    if probe - end >= 4:
                        break
                end += 1
            patch += encode_number(((end - pos - 1) << 2) | 1)  # TargetRead
            patch += target[pos:end]
        pos = end

    patch += crc32(source).to_bytes(4, "little")
    patch += crc32(target).to_bytes(4, "little")
    patch += crc32(patch).to_bytes(4, "little")
    return bytes(patch)


def apply_patch(patch: bytes, source: bytes) -> bytes:
    if len(patch) < 16 or patch[:4] != b"BPS1":
        raise ValueError("invalid BPS patch header")
    if crc32(patch[:-4]) != int.from_bytes(patch[-4:], "little"):
        raise ValueError("BPS patch checksum mismatch")
    if crc32(source) != int.from_bytes(patch[-12:-8], "little"):
        raise ValueError("source ROM checksum mismatch")

    offset = 4
    source_size, offset = decode_number(patch, offset)
    target_size, offset = decode_number(patch, offset)
    metadata_size, offset = decode_number(patch, offset)
    if source_size != len(source):
        raise ValueError("source ROM size mismatch")
    offset += metadata_size
    target = bytearray()
    while len(target) < target_size:
        command, offset = decode_number(patch, offset)
        length = (command >> 2) + 1
        mode = command & 3
        if mode == 0:  # SourceRead at the current output offset
            start = len(target)
            target += source[start : start + length]
        elif mode == 1:  # TargetRead literal bytes
            target += patch[offset : offset + length]
            offset += length
        else:
            raise ValueError("unexpected copy command in generated BPS patch")
    result = bytes(target)
    if len(result) != target_size:
        raise ValueError("BPS target size mismatch")
    if crc32(result) != int.from_bytes(patch[-8:-4], "little"):
        raise ValueError("target ROM checksum mismatch")
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--target", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    source = args.source.read_bytes()
    target = args.target.read_bytes()
    patch = build_patch(source, target)
    if apply_patch(patch, source) != target:
        raise SystemExit("generated BPS patch did not reproduce the target ROM")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(patch)
    print(f"Wrote verified BPS patch ({len(patch)} bytes) to {args.output}")


if __name__ == "__main__":
    main()
