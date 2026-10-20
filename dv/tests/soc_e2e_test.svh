class soc_e2e_test extends uvm_test;
  `uvm_component_utils(soc_e2e_test)
  soc_env env;
  virtual soc_if vif;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env=soc_env::type_id::create("env",this);
    if(!uvm_config_db#(virtual soc_if)::get(this,"","vif",vif)) `uvm_fatal("NOVIF","soc_if missing")
  endfunction
  task run_phase(uvm_phase phase);
    soc_e2e_sequence seq=soc_e2e_sequence::type_id::create("seq");
    phase.raise_objection(this);
    seq.start(env.spi_agent.sequencer);
    fork
      begin wait(vif.halted); end
      begin repeat(20000) @(posedge vif.sys_clk); `uvm_fatal("TIMEOUT","CPU did not halt") end
    join_any
    disable fork;
    repeat(4) @(posedge vif.sys_clk);
    phase.drop_objection(this);
  endtask
endclass
