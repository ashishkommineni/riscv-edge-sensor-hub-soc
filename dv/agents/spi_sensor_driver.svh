class spi_sensor_driver extends uvm_driver #(spi_sensor_item);
  `uvm_component_utils(spi_sensor_driver)
  virtual soc_if vif;
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual soc_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "soc_if was not configured")
  endfunction
  task idle_spi_edge();
    #(7ns); vif.spi_sclk <= 1'b1;
    #(7ns); vif.spi_sclk <= 1'b0;
  endtask
  task drive_byte(spi_sensor_item tr);
    vif.spi_cs_n <= 1'b0;
    for (int bit_no=7; bit_no>=0; bit_no--) begin
      vif.spi_mosi <= tr.sample[bit_no];
      idle_spi_edge();
    end
    vif.spi_cs_n <= 1'b1;
    vif.spi_mosi <= 1'b0;
    #(tr.gap_ns * 1ns);
  endtask
  task run_phase(uvm_phase phase);
    vif.spi_cs_n <= 1'b1;
    vif.spi_sclk <= 1'b0;
    wait (vif.arst_n === 1'b1);
    repeat (2) idle_spi_edge();
    forever begin
      seq_item_port.get_next_item(req);
      drive_byte(req);
      seq_item_port.item_done();
    end
  endtask
endclass
