class soc_monitor extends uvm_monitor;
  `uvm_component_utils(soc_monitor)
  virtual soc_if vif;
  uvm_analysis_port #(soc_observation) ap;
  bit prev_irq, prev_halt, prev_fault;
  function new(string name, uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual soc_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","soc_if missing")
  endfunction
  function void emit(obs_kind_e kind, logic signed [31:0] value=0);
    soc_observation o = soc_observation::type_id::create("obs");
    o.kind=kind; o.value=value; ap.write(o);
  endfunction
  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.sys_clk);
      if (vif.uart_strobe) emit(OBS_UART, {24'b0,vif.uart_byte});
      if (vif.dma_done) emit(OBS_DMA_DONE);
      if (vif.acc_done) emit(OBS_RESULT, vif.acc_result);
      if (vif.ecc_corrected) emit(OBS_ECC_CORRECTED);
      if (vif.ecc_uncorrectable) emit(OBS_ECC_UNCORRECTABLE);
      if (vif.irq_o && !prev_irq) emit(OBS_IRQ);
      if (vif.halted && !prev_halt) emit(OBS_HALT);
      if (vif.fault && !prev_fault) emit(OBS_FAULT, vif.debug_pc);
      prev_irq=vif.irq_o; prev_halt=vif.halted; prev_fault=vif.fault;
    end
  endtask
endclass
