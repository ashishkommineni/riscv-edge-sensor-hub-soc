#!/usr/bin/env python3
"""Parse the complete UVM source tree without claiming UVM elaboration."""

from pathlib import Path
import re

from pyslang.syntax import SyntaxTree


ROOT = Path(__file__).resolve().parents[1]
UVM_MACRO_STUBS = r"""
`define uvm_object_utils_begin(T)
`define uvm_object_utils_end
`define uvm_object_utils(T)
`define uvm_component_utils(T)
`define uvm_field_int(V,F)
`define uvm_field_enum(T,V,F)
`define uvm_field_string(V,F)
`define uvm_analysis_imp_decl(S)
`define uvm_fatal(ID,MSG) $fatal(1,MSG);
`define uvm_error(ID,MSG) $error(MSG);
`define uvm_info(ID,MSG,V) $display("%s",MSG);
"""
INCLUDE_RE = re.compile(r'^\s*`include\s+"([^"]+)"')


def expand_includes(path: Path, stack: tuple[Path, ...] = ()) -> str:
    """Expand repository-local includes and replace only UVM utility macros."""
    path = path.resolve()
    if path in stack:
        raise RuntimeError(f"recursive include: {path.relative_to(ROOT)}")
    output: list[str] = []
    for line in path.read_text().splitlines():
        match = INCLUDE_RE.match(line)
        if not match:
            output.append(line)
            continue
        include = match.group(1)
        if include == "uvm_macros.svh":
            output.append(UVM_MACRO_STUBS)
            continue
        candidates = (path.parent / include, ROOT / "dv" / include)
        target = next((candidate for candidate in candidates if candidate.is_file()), None)
        if target is None:
            raise FileNotFoundError(f"unresolved include {include!r} in {path.relative_to(ROOT)}")
        output.append(expand_includes(target, stack + (path,)))
    return "\n".join(output) + "\n"


def parse_unit(name: str, text: str) -> list[str]:
    tree = SyntaxTree.fromText(text, name)
    return [str(diagnostic.code) for diagnostic in tree.diagnostics]


def main() -> int:
    units = {
        "dv/soc_uvm_pkg.sv": expand_includes(ROOT / "dv/soc_uvm_pkg.sv"),
        "dv/soc_if.sv": (ROOT / "dv/soc_if.sv").read_text(),
        "dv/top/uvm_tb_top.sv": (ROOT / "dv/top/uvm_tb_top.sv").read_text(),
    }
    failures: list[str] = []
    for name, text in units.items():
        diagnostics = parse_unit(name, text)
        if diagnostics:
            failures.append(f"{name}: {', '.join(diagnostics)}")
    if failures:
        raise SystemExit("UVM source syntax failed:\n  " + "\n  ".join(failures))
    print(f"UVM_SOURCE_SYNTAX_PASS units={len(units)} parser=pyslang-12.0.0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
