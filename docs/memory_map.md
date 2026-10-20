# Memory map and register contract

All registers are 32-bit and word-aligned. Undefined offsets read zero. Writes to
read-only fields have no effect.

## Global map

| Base | Size | Name |
|---:|---:|---|
| `0x0000_0000` | 1 KiB | Instruction ROM |
| `0x1000_0000` | 1 KiB | SECDED SRAM |
| `0x2000_0000` | 4 KiB | SPI/FIFO status |
| `0x2000_1000` | 4 KiB | Sensor DMA |
| `0x2000_2000` | 4 KiB | INT8 accelerator |
| `0x2000_3000` | 4 KiB | Interrupt controller |
| `0x2000_4000` | 4 KiB | UART |

## DMA (`0x2000_1000`)

| Offset | Name | Access | Definition |
|---:|---|---|---|
| `0x00` | CONTROL_STATUS | R/W | `[0] ACTIVE/START`, `[1] DONE/CLEAR_DONE`, `[2] ERROR/CLEAR_ERROR`, `[3] IRQ_ENABLE` |
| `0x04` | DESTINATION | R/W | First SRAM byte address |
| `0x08` | LENGTH | R/W | Number of sensor bytes |
| `0x0C` | TRANSFERRED | R | Committed word count |

Firmware polls `CONTROL_STATUS.DONE` at offset `0x00`; `TRANSFERRED` is never
treated as a done flag.

## Accelerator (`0x2000_2000`)

| Offset | Name | Access | Definition |
|---:|---|---|---|
| `0x00` | CONTROL_STATUS | R/W | Same bit layout as DMA |
| `0x04` | SOURCE | R/W | First SRAM sample address |
| `0x08` | LENGTH | R/W | Number of samples |
| `0x0C` | INDEX | R | Samples consumed |
| `0x10` | RESULT | R | Signed 32-bit accumulated result |

## Interrupt controller (`0x2000_3000`)

| Offset | Name | Access | Definition |
|---:|---|---|---|
| `0x00` | PENDING | R/W1C | Sticky source bits |
| `0x04` | MASK | R/W | One enables propagation to `irq_o` |

Sources `[4:0]` are SPI overflow, ECC uncorrectable, ECC corrected, accelerator
done/error, and DMA done/error. The reference firmware writes `0x1F` to MASK.

## UART (`0x2000_4000`)

| Offset | Name | Access | Definition |
|---:|---|---|---|
| `0x00` | TX_DATA | W | Low byte begins an 8-N-1 frame; bus stalls while busy |
| `0x04` | STATUS | R | `[0] BUSY` |

## SPI/FIFO status (`0x2000_0000`)

Bits `[3:0]` are underflow, synchronized overflow event, full and empty. The CPU
does not pop FIFO data directly in this MVP; DMA owns the read port.
