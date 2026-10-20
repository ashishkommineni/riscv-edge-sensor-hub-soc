`uvm_analysis_imp_decl(_sensor)
`uvm_analysis_imp_decl(_obs)
class soc_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(soc_scoreboard)
  uvm_analysis_imp_sensor #(spi_sensor_item, soc_scoreboard) sensor_imp;
  uvm_analysis_imp_obs #(soc_observation, soc_scoreboard) obs_imp;
  byte signed samples[$];
  byte uart[$];
  bit saw_dma, saw_result, saw_irq, saw_correction, saw_halt, failed;
  int signed actual_result;
  int signed weights[8] = '{1,-1,2,-2,3,-3,4,-4};
  function new(string name, uvm_component parent);
    super.new(name,parent); sensor_imp=new("sensor_imp",this); obs_imp=new("obs_imp",this);
  endfunction
  function void write_sensor(spi_sensor_item item); samples.push_back(item.sample); endfunction
  function void write_obs(soc_observation o);
    case (o.kind)
      OBS_UART: uart.push_back(o.value[7:0]);
      OBS_DMA_DONE: saw_dma=1;
      OBS_RESULT: begin saw_result=1; actual_result=$signed(o.value); end
      OBS_IRQ: saw_irq=1;
      OBS_ECC_CORRECTED: saw_correction=1;
      OBS_ECC_UNCORRECTABLE: begin failed=1; `uvm_error("ECC","uncorrectable error observed") end
      OBS_HALT: saw_halt=1;
      OBS_FAULT: begin failed=1; `uvm_error("CPU",$sformatf("fault at pc=%08x",o.value)) end
      default: ;
    endcase
  endfunction
  function void check_phase(uvm_phase phase);
    int signed expected=0;
    byte expected_uart[5]='{"P","A","S","S",8'h0a};
    if (samples.size()!=8) `uvm_error("COUNT",$sformatf("expected 8 SPI bytes, got %0d",samples.size()))
    foreach (samples[i]) expected += samples[i] * weights[i%8];
    if (!saw_result || actual_result != expected)
      `uvm_error("RESULT",$sformatf("actual=%0d expected=%0d",actual_result,expected))
    if (uart.size()!=5) `uvm_error("UART",$sformatf("received %0d bytes",uart.size()))
    else foreach(expected_uart[i]) if(uart[i]!==expected_uart[i]) `uvm_error("UART","byte stream mismatch")
    if (!(saw_dma&&saw_irq&&saw_correction&&saw_halt) || failed)
      `uvm_error("GATES",$sformatf("dma=%0b irq=%0b ecc=%0b halt=%0b failed=%0b",
                 saw_dma,saw_irq,saw_correction,saw_halt,failed))
  endfunction
endclass
