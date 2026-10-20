#!/usr/bin/env python3
"""Generate the deterministic RV32I image without requiring a cross-compiler."""
from __future__ import annotations
import argparse
from pathlib import Path


def lui(rd: int, imm20: int) -> int:
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0x37


def op_imm(rd: int, rs1: int, imm: int, funct3: int) -> int:
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | 0x13


def addi(rd: int, rs1: int, imm: int) -> int:
    return op_imm(rd, rs1, imm, 0)


def andi(rd: int, rs1: int, imm: int) -> int:
    return op_imm(rd, rs1, imm, 7)


def lw(rd: int, rs1: int, imm: int) -> int:
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (2 << 12) | (rd << 7) | 0x03


def sw(rs2: int, rs1: int, imm: int) -> int:
    u = imm & 0xFFF
    return ((u >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | ((u & 0x1F) << 7) | 0x23


def beq(rs1: int, rs2: int, offset: int) -> int:
    if offset % 2:
        raise ValueError("branch offset must be 2-byte aligned")
    u = offset & 0x1FFF
    return (((u >> 12) & 1) << 31) | (((u >> 5) & 0x3F) << 25) | (rs2 << 20) | \
           (rs1 << 15) | (((u >> 1) & 0xF) << 8) | (((u >> 11) & 1) << 7) | 0x63


def image() -> list[int]:
    w: list[int] = [
        lui(1, 0x20001), lui(2, 0x10000), lui(9, 0x20003),
        addi(10, 0, 31), sw(10, 9, 4), sw(2, 1, 4), addi(3, 0, 8),
        sw(3, 1, 8), addi(3, 0, 9), sw(3, 1, 0),
        lw(4, 1, 0), andi(4, 4, 2), beq(4, 0, -8),
        lui(5, 0x20002), sw(2, 5, 4), addi(3, 0, 8), sw(3, 5, 8),
        addi(3, 0, 9), sw(3, 5, 0),
        lw(4, 5, 0), andi(4, 4, 2), beq(4, 0, -8), lw(6, 5, 16),
        lui(7, 0x20004),
    ]
    for ch in b"PASS\n":
        w += [addi(8, 0, ch), sw(8, 7, 0)]
    w += [0x00100073]  # EBREAK
    return w


def render() -> str:
    return "\n".join(f"{word:08x}" for word in image()) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="compare with firmware/boot.hex")
    parser.add_argument("--stdout", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    text = render()
    if args.stdout:
        print(text, end="")
    if args.check:
        expected = (root / "firmware" / "boot.hex").read_text()
        if expected != text:
            raise SystemExit("firmware/boot.hex is stale; regenerate from this script")
        print(f"PASS firmware image: {len(image())} words")
    if not args.stdout and not args.check:
        (root / "firmware" / "boot.hex").write_text(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
