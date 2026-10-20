class soc_coverage extends uvm_subscriber #(soc_observation);
  `uvm_component_utils(soc_coverage)
  obs_kind_e sampled_kind;
  logic signed [31:0] sampled_value;
  covergroup cg;
    option.per_instance=1;
    kind_cp: coverpoint sampled_kind;
    uart_cp: coverpoint sampled_value[7:0] iff (sampled_kind==OBS_UART) {
      bins pass_chars[]={8'h50,8'h41,8'h53,8'h0a};
      bins other=default;
    }
    result_sign_cp: coverpoint sampled_value[31] iff (sampled_kind==OBS_RESULT);
  endgroup
  function new(string name, uvm_component parent); super.new(name,parent); cg=new; endfunction
  function void write(soc_observation t); sampled_kind=t.kind; sampled_value=t.value; cg.sample(); endfunction
endclass
