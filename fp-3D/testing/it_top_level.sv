`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

module top_level(
    input wire clk_100mhz,
    input wire [15:0] sw, //all 16 input slide switches
    output logic [15:0] led, //16 green output LEDs (located right above switches)
    output logic uart_txd,
    input wire uart_rxd,
    output logic [2:0] rgb0 //rgb led
);

// would like to drive rgb0 with in_triangle output. Can I simply...
assign rgb0 = in_triangle;

logic sys_rst;

logic [9:0] vertex_ax;
logic [9:0] vertex_ay;
logic [9:0] vertex_bx;
logic [9:0] vertex_by;
logic [9:0] vertex_cx;
logic [9:0] vertex_cy;
logic [9:0] point_x;
logic [9:0] point_y;

logic in_triangle;
logic data_valid_in;
logic data_valid_out;

in_triangle_wrap #(.SYS_BIT_WIDTH(10)) pixel_check (
    .clk_in(clk_100mhz),
    .valid_in(data_valid_in),
    .vertex_ax(vertex_ax),
    .vertex_ay(vertex_ay),
    .vertex_bx(vertex_bx),
    .vertex_by(vertex_by),
    .vertex_cx(vertex_cx),
    .vertex_cy(vertex_cy),
    .point_x(point_x),
    .point_y(point_y),
    .valid_out(data_valid_out),
    .is_inside(in_triangle)
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
    .val1_in(in_triangle), 
    .val2_out(vertex_ax), 
    .val3_out(vertex_ay), 
    .val4_out(vertex_bx), 
    .val5_out(vertex_by), 
    .val6_out(vertex_cx), 
    .val7_out(vertex_cy), 
    .val8_out(point_x), 
    .val9_out(point_y)
);

endmodule //top_level
`default_nettype wire