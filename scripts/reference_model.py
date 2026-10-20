#!/usr/bin/env python3
"""Executable reference checks for firmware, datapath math, and SECDED logic.

This does not replace RTL simulation. It independently validates the checked-in
firmware control flow and the expected architectural result using only Python.
"""
from __future__ import annotations
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DMA, ACC, IRQ, UART, SRAM = 0x20001000, 0x20002000, 0x20003000, 0x20004000, 0x10000000
SAMPLES = list(range(1, 9))
WEIGHTS = [1, -1, 2, -2, 3, -3, 4, -4]


def sign(value: int, bits: int) -> int:
    value &= (1 << bits) - 1
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def ecc_encode(data: int) -> int:
    bits = [0] * 39
    di = 0
    for pos in range(1, 39):
        if pos not in (1, 2, 4, 8, 16, 32):
            bits[pos - 1] = (data >> di) & 1
            di += 1
    for p in (1, 2, 4, 8, 16, 32):
        bits[p - 1] = sum(bits[pos - 1] for pos in range(1, 39) if pos & p) & 1
    bits[38] = sum(bits[:38]) & 1
    return sum(bit << i for i, bit in enumerate(bits))


def ecc_decode(code: int) -> tuple[int, bool, bool]:
    bits = [(code >> i) & 1 for i in range(39)]
    syndrome = 0
    for p in (1, 2, 4, 8, 16, 32):
        if sum(bits[pos - 1] for pos in range(1, 39) if pos & p) & 1:
            syndrome |= p
    overall = sum(bits) & 1
    corrected = uncorrectable = False
    if syndrome and overall:
        if syndrome <= 38:
            bits[syndrome - 1] ^= 1
        corrected = True
    elif not syndrome and overall:
        bits[38] ^= 1
        corrected = True
    elif syndrome and not overall:
        uncorrectable = True
    data = 0
    di = 0
    for pos in range(1, 39):
        if pos not in (1, 2, 4, 8, 16, 32):
            data |= bits[pos - 1] << di
            di += 1
    return data, corrected, uncorrectable


class SoCModel:
    def __init__(self) -> None:
        self.dma_dst = SRAM
        self.dma_len = 0
        self.dma_status = 0
        self.acc_src = SRAM
        self.acc_len = 0
        self.acc_status = 0
        self.acc_result = 0
        self.irq_mask = 0
        self.memory: dict[int, int] = {}
        self.uart = bytearray()

    def write(self, addr: int, value: int) -> None:
        if addr == DMA + 4:
            self.dma_dst = value
        elif addr == DMA + 8:
            self.dma_len = value & 0xFFFF
        elif addr == DMA and value & 1:
            assert self.dma_len <= len(SAMPLES)
            for i, sample in enumerate(SAMPLES[: self.dma_len]):
                self.memory[self.dma_dst + 4 * i] = sample
            self.dma_status = 0b1010  # irq_enable + done
        elif addr == ACC + 4:
            self.acc_src = value
        elif addr == ACC + 8:
            self.acc_len = value & 0xFFFF
        elif addr == ACC and value & 1:
            total = 0
            for i in range(self.acc_len):
                sample = sign(self.memory[self.acc_src + 4 * i] & 0xFF, 8)
                total += sample * WEIGHTS[i % len(WEIGHTS)]
            self.acc_result = total & 0xFFFFFFFF
            self.acc_status = 0b1010
        elif addr == IRQ + 4:
            self.irq_mask = value & 0x1F
        elif addr == UART:
            self.uart.append(value & 0xFF)
        else:
            raise AssertionError(f"unexpected MMIO write 0x{addr:08x}")

    def read(self, addr: int) -> int:
        if addr == DMA:
            return self.dma_status
        if addr == ACC:
            return self.acc_status
        if addr == ACC + 16:
            return self.acc_result
        raise AssertionError(f"unexpected MMIO read 0x{addr:08x}")


def execute_firmware(words: list[int]) -> SoCModel:
    soc = SoCModel()
    regs = [0] * 32
    pc = 0
    for _ in range(1000):
        insn = words[pc // 4]
        opcode, rd = insn & 0x7F, (insn >> 7) & 0x1F
        funct3, rs1, rs2 = (insn >> 12) & 7, (insn >> 15) & 31, (insn >> 20) & 31
        if opcode == 0x37:  # LUI
            regs[rd] = insn & 0xFFFFF000
            pc += 4
        elif opcode == 0x13:  # ADDI / ANDI
            imm = sign(insn >> 20, 12)
            regs[rd] = (regs[rs1] + imm) & 0xFFFFFFFF if funct3 == 0 else regs[rs1] & imm
            pc += 4
        elif opcode == 0x23:  # SW
            imm = sign(((insn >> 25) << 5) | ((insn >> 7) & 0x1F), 12)
            soc.write((regs[rs1] + imm) & 0xFFFFFFFF, regs[rs2])
            pc += 4
        elif opcode == 0x03:  # LW
            imm = sign(insn >> 20, 12)
            regs[rd] = soc.read((regs[rs1] + imm) & 0xFFFFFFFF)
            pc += 4
        elif opcode == 0x63:  # BEQ
            imm = (((insn >> 31) & 1) << 12) | (((insn >> 7) & 1) << 11) | \
                  (((insn >> 25) & 0x3F) << 5) | (((insn >> 8) & 0xF) << 1)
            pc = pc + sign(imm, 13) if regs[rs1] == regs[rs2] else pc + 4
        elif opcode == 0x73:
            break
        else:
            raise AssertionError(f"unsupported firmware opcode 0x{opcode:02x} at pc=0x{pc:x}")
        regs[0] = 0
    else:
        raise AssertionError("firmware model did not halt")
    assert sign(regs[6], 32) == -10
    return soc


def main() -> int:
    words = [int(line, 16) for line in (ROOT / "firmware/boot.hex").read_text().split()]
    soc = execute_firmware(words)
    assert soc.uart == b"PASS\n"
    assert soc.irq_mask == 0x1F
    assert sign(soc.acc_result, 32) == sum(a * b for a, b in zip(SAMPLES, WEIGHTS)) == -10

    patterns = [0, 1, 0xFFFFFFFF, 0xA5A55A5A, 0x80000001]
    for data in patterns:
        code = ecc_encode(data)
        clean, corrected, unc = ecc_decode(code)
        assert (clean, corrected, unc) == (data, False, False)
        for bit in range(39):
            got, corrected, unc = ecc_decode(code ^ (1 << bit))
            assert got == data and corrected and not unc
        _, corrected, unc = ecc_decode(code ^ 0b11)
        assert not corrected and unc

    print("PASS reference model: firmware=35_words uart=PASS result=-10 irq_mask=0x1f")
    print("PASS SECDED model: clean + 195 single-bit corrections + 5 double-bit detections")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
