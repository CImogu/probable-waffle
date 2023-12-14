`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module top_level(
    input wire clk_100mhz,
    input wire [15:0] sw, //all 16 input slide switches
    output logic [15:0] led, //16 green output LEDs (located right above switches)
    output logic uart_txd,
    input wire uart_rxd
);

logic sys_rst;

logic [20:0] p1;
logic [20:0] p2;
logic [20:0] p3;
logic [20:0] b1;
logic [20:0] b2;
logic [20:0] b3;
logic [31:0] smth_out;

logic [9:0] exval4;
logic [9:0] exval5;

logic [20:0] obj_location [5:0];
always_comb begin
    obj_location[0] = p1;
    obj_location[1] = p2;
    obj_location[2] = p3;
    obj_location[3] = b1;
    obj_location[4] = b2;
    obj_location[5] = b3;
end

logic data_valid_in;
logic data_valid_out;
logic [2:0] input_valid;

displaying to_screen(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .valid_in(data_valid_in),
    .game_obj_loc(obj_location),
    .smth(data_valid_out)
);

localparam max_count = 10000;
logic [13:0] clk_count;

always_ff @(posedge clk_100mhz) begin
    if (sys_rst) begin
        clk_count <= 0;
    end else begin
        if (clk_count == (max_count - 1)) begin
            clk_count <= 0;
            data_valid_in <= 1;
        end else begin
            clk_count <= clk_count + 1;
            data_valid_in <= 0;
        end
    end
end


manta my_manta (
    .clk(clk_100mhz),
    .rx(uart_rxd),
    .tx(uart_txd),
    .val1_in(smth_out), 
    .val2_out(p1), 
    .val3_out(p2), 
    .val4_out(p3), 
    .val5_out(b1), 
    .val6_out(b2), 
    .val7_out(b3), 
    .val8_out(exval4), 
    .val9_out(exval5)
);

endmodule //top_level
`default_nettype wire