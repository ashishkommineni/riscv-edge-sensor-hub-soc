class spi_sensor_monitor extends uvm_monitor;
  `uvm_component_utils(spi_sensor_monitor)
  virtual soc_if vif;
  uvm_analysis_port #(spi_sensor_item) ap;
  function new(string name, uvm_component parent); super.new(name, parent); ap=new("ap",this); endfunction
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual soc_if)::get(this, "", "vif", vif))
      `uvm_fatal("NOVIF", "soc_if was not configured")
  endfunction
  task run_phase(uvm_phase phase);
    bit [7:0] shift=0;
    int count=0;
    forever begin
      @(posedge vif.spi_sclk);
      if (!vif.spi_cs_n) begin
        shift = {shift[6:0], vif.spi_mosi};
        count++;
        if (count == 8) begin
          spi_sensor_item item = spi_sensor_item::type_id::create("observed_item");
          item.sample = shift;
          item.gap_ns = 0;
          ap.write(item);
          count = 0;
        end
      end else count = 0;
    end
  endtask
endclass
