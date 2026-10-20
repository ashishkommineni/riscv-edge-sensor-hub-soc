class spi_sensor_agent extends uvm_agent;
  `uvm_component_utils(spi_sensor_agent)
  spi_sensor_sequencer sequencer;
  spi_sensor_driver driver;
  spi_sensor_monitor monitor;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = spi_sensor_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      sequencer = spi_sensor_sequencer::type_id::create("sequencer", this);
      driver = spi_sensor_driver::type_id::create("driver", this);
    end
  endfunction
  function void connect_phase(uvm_phase phase);
    if (get_is_active() == UVM_ACTIVE) driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
