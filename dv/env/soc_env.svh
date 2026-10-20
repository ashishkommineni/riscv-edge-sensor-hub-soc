class soc_env extends uvm_env;
  `uvm_component_utils(soc_env)
  spi_sensor_agent spi_agent;
  soc_monitor monitor;
  soc_scoreboard scoreboard;
  soc_coverage coverage;
  function new(string name, uvm_component parent); super.new(name,parent); endfunction
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    spi_agent=spi_sensor_agent::type_id::create("spi_agent",this);
    monitor=soc_monitor::type_id::create("monitor",this);
    scoreboard=soc_scoreboard::type_id::create("scoreboard",this);
    coverage=soc_coverage::type_id::create("coverage",this);
  endfunction
  function void connect_phase(uvm_phase phase);
    spi_agent.monitor.ap.connect(scoreboard.sensor_imp);
    monitor.ap.connect(scoreboard.obs_imp);
    monitor.ap.connect(coverage.analysis_export);
  endfunction
endclass
