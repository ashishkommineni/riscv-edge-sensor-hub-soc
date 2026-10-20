package soc_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  `include "agents/spi_sensor_item.svh"
  `include "agents/spi_sensor_sequencer.svh"
  `include "agents/spi_sensor_driver.svh"
  `include "agents/spi_sensor_monitor.svh"
  `include "agents/spi_sensor_agent.svh"
  `include "env/soc_observation.svh"
  `include "env/soc_monitor.svh"
  `include "scoreboard/soc_scoreboard.svh"
  `include "coverage/soc_coverage.svh"
  `include "env/soc_env.svh"
  `include "sequences/soc_e2e_sequence.svh"
  `include "tests/soc_e2e_test.svh"
endpackage
