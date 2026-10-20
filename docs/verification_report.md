# Verification report

## Evidence available in the initial repository

| Check | Status | Reproduce |
|---|---|---|
| Firmware image matches generator | Locally executed PASS | `python3 scripts/build_firmware.py --check` |
| Firmware/MMIO reference execution | Locally executable; record output below | `python3 scripts/reference_model.py` |
| SECDED reference fault campaign | Locally executable; record output below | `python3 scripts/reference_model.py` |
| Repository structure gate | Locally executable after all files are present | `python3 scripts/structure_check.py` |
| Verilator lint | Simulator unavailable in authoring workspace | `make lint` or CI |
| Verilator RTL simulation | Simulator unavailable in authoring workspace | `make sim` or CI |
| Xcelium UVM 1.2 | Not executed | `make xcelium` |
| IMC coverage | Not generated | Run after Xcelium regression |
| CDC/RDC sign-off | Not executed | Target technology/tool required |

## Required run record

When a simulator run is made, append—not overwrite—the following:

```text
Date:
Git commit:
Tool and version:
Command:
Test:
Seed:
Result:
UVM_ERROR/UVM_FATAL:
Assertions passed/failed:
Functional coverage:
Code coverage:
Transcript/artifact path:
Known waivers:
```

The repository intentionally does not pre-fill pass results for tools that were
not available. `results/expected_output.txt` is a contract, not a captured run.
