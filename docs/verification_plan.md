# Verification plan

## Verification layers

| Layer | Purpose | Pass evidence |
|---|---|---|
| Python firmware model | Decode the exact checked-in machine code and validate MMIO intent | `PASS reference model` |
| Python SECDED model | Clean decode, every single-bit location, representative double-bit faults | `195 single-bit corrections`, `5 double-bit detections` |
| Structural gate | Required artifacts, balanced modules, current firmware, evidence wording | `PASS structure` |
| Portable SV test | RTL end-to-end data, CDC, DMA, ECC injection, accelerator, IRQ, UART | `SOC_TEST_PASS` |
| SVA | Bounded response, DMA progress, no engine/CPU write collision | Assertion summary, zero failures |
| UVM 1.2 | Reusable SPI agent, scoreboard, functional coverage and seeded regression | Xcelium transcript and IMC report when run |

## Planned scenarios

| ID | Scenario | Expected result | Current automation |
|---|---|---|---|
| E2E-01 | Samples 1..8 | Result -10, UART PASS | Portable SV + Python |
| ECC-01 | Flip one protected data bit | Corrected pulse, result unchanged | Portable SV + Python |
| ECC-02 | Flip each of 39 codeword bits | All correctable | Python exhaustive loop |
| ECC-03 | Representative double-bit flips | Uncorrectable, never reported corrected | Python; RTL negative test planned |
| DMA-01 | Empty FIFO while active | Wait without underflow/pop | Portable end-to-end behavior |
| DMA-02 | One pop per byte | Eight committed words | DMA FSM + result check |
| IRQ-01 | Enabled DMA/accelerator/ECC source | Pending and `irq_o` observed | Portable SV |
| UART-01 | Backpressure while serial frame active | CPU store stalls, exact byte order | Portable SV |
| RESET-01 | Normal reset before traffic | Deterministic boot | Portable SV |
| RESET-02 | Reset during DMA/accelerator | Clean cancellation | Future directed/UVM test |
| SPI-01 | Mode-0 MSB-first bytes | Byte reconstruction | Portable SV/UVM |
| SPI-02 | FIFO overflow | Drop + synchronized IRQ source | Future directed/UVM test |

## Assertions

- Every CPU data request receives a response within 80 system clocks.
- DMA transferred count is monotonic while active.
- CPU and engine never commit competing memory writes.
- Cover properties require a multi-cycle DMA active window and an accelerator
  start-to-finish interval.

Assertions are compiled with `+define+ENABLE_SVA` in the Xcelium target. Portable
functional gates remain active even if a simulator does not support full SVA.

## Functional coverage model

The UVM subscriber samples observation kind, UART byte class, accelerator result
sign and completion. A production closure plan should add crosses for:

- DMA length × FIFO empty wait duration;
- SPI inter-byte gap × system/SPI clock ratio;
- ECC class × consumer (CPU, DMA, accelerator);
- reset point × active engine;
- interrupt source × mask state;
- accelerator length × result sign × overflow.

Coverage percentage is not claimed until an actual Xcelium/IMC run is archived.

## Sign-off rule

A green Python check is necessary but not sufficient. RTL PASS requires the
self-checking SV test transcript. UVM PASS requires the Xcelium transcript, exact
seed, zero `UVM_ERROR/UVM_FATAL`, assertion summary, and coverage report. CDC and
RDC sign-off require a dedicated structural tool and constraints.
