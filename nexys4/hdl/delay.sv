module delay #(parameter WIDTH=1, parameter DELAY=1) (
  input wire clk_in,
  input logic[WIDTH-1:0] in,
  output logic[WIDTH-1:0] out);

  logic[WIDTH-1:0] regs[0:DELAY-1]; 

  always_ff @(posedge clk_in) begin
    regs[0] <= in;
    for (int i = 1; i < DELAY; i++) begin
      regs[i] <= regs[i - 1];
    end
  end

  assign out = regs[DELAY - 1];
endmodule