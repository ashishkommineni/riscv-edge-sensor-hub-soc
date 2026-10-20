typedef enum int {OBS_UART, OBS_RESULT, OBS_DMA_DONE, OBS_IRQ, OBS_ECC_CORRECTED,
                  OBS_ECC_UNCORRECTABLE, OBS_HALT, OBS_FAULT} obs_kind_e;
class soc_observation extends uvm_sequence_item;
  obs_kind_e kind;
  logic signed [31:0] value;
  `uvm_object_utils_begin(soc_observation)
    `uvm_field_enum(obs_kind_e, kind, UVM_ALL_ON)
    `uvm_field_int(value, UVM_ALL_ON)
  `uvm_object_utils_end
  function new(string name="soc_observation"); super.new(name); endfunction
endclass
