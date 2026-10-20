class spi_sensor_item extends uvm_sequence_item;
  rand bit signed [7:0] sample;
  rand int unsigned gap_ns;
  constraint legal_gap { gap_ns inside {[4:20]}; }
  `uvm_object_utils_begin(spi_sensor_item)
    `uvm_field_int(sample, UVM_ALL_ON)
    `uvm_field_int(gap_ns, UVM_ALL_ON)
  `uvm_object_utils_end
  function new(string name="spi_sensor_item"); super.new(name); endfunction
endclass
