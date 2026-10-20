class soc_e2e_sequence extends uvm_sequence #(spi_sensor_item);
  `uvm_object_utils(soc_e2e_sequence)
  function new(string name="soc_e2e_sequence"); super.new(name); endfunction
  task body();
    for (int i=1;i<=8;i++) begin
      spi_sensor_item tr=spi_sensor_item::type_id::create($sformatf("sample_%0d",i));
      start_item(tr);
      if (!tr.randomize() with { sample==i; gap_ns inside {[8:16]}; }) `uvm_fatal("RAND","item randomization failed")
      finish_item(tr);
    end
  endtask
endclass
