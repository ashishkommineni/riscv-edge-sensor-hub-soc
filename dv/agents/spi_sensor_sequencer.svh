class spi_sensor_sequencer extends uvm_sequencer #(spi_sensor_item);
  `uvm_component_utils(spi_sensor_sequencer)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
endclass
