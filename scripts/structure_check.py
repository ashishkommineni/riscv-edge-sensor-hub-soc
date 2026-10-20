#!/usr/bin/env python3
"""Fast repository/RTL consistency gate used before simulator jobs."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "README.md", "LICENSE", "firmware/boot.S", "firmware/boot.hex",
    "rtl/cpu/rv32i_control_core.sv", "rtl/memory/ecc_sram.sv",
    "rtl/dma/sensor_dma.sv", "rtl/cdc/async_fifo.sv",
    "rtl/accelerator/int8_dot_product.sv", "tb/tb_riscv_edge_sensor_hub.sv",
    "docs/specification.md", "docs/verification_plan.md", "docs/memory_map.md",
    "docs/verification_report.md", "assets/architecture.svg", "assets/waveform.svg",
    "requirements-ci.txt", "scripts/uvm_syntax_check.py",
]

missing = [name for name in REQUIRED if not (ROOT / name).is_file()]
if missing:
    raise SystemExit("missing required files: " + ", ".join(missing))

sv_files = list(ROOT.glob("rtl/**/*.sv")) + list(ROOT.glob("tb/*.sv"))
for path in sv_files:
    text = path.read_text()
    if text.count("module ") != text.count("endmodule"):
        raise SystemExit(f"module/endmodule imbalance: {path.relative_to(ROOT)}")
    if "TODO" in text or "PLACEHOLDER" in text.upper():
        raise SystemExit(f"unfinished marker in {path.relative_to(ROOT)}")

fw = (ROOT / "firmware/boot.hex").read_text().split()
if not fw or any(not re.fullmatch(r"[0-9a-fA-F]{8}", word) for word in fw):
    raise SystemExit("firmware/boot.hex has malformed words")

readme = (ROOT / "README.md").read_text()
for phrase in ("not an ISA-compliance", "not a silicon CDC sign-off", "not been run in Xcelium"):
    if phrase not in readme:
        raise SystemExit(f"README missing evidence boundary: {phrase}")

print(f"PASS structure: {len(sv_files)} portable RTL/TB files, {len(fw)} firmware words")
