`timescale 1ns / 1ps
`default_nettype none

module display_tb();
    logic [9:0] vertex_ax;
    logic [9:0] vertex_ay;
    logic [9:0] vertex_bx;
    logic [9:0] vertex_by;
    logic [9:0] vertex_cx;
    logic [9:0] vertex_cy; 
    logic [19:0] point_out;

    logic data_valid_in;
    logic data_valid_out;
    logic last_out;

    logic clk_in;
    logic sys_rst;


    triangle_color #(.WIDTH(40), .HEIGHT(10)) uut (
    .clk_in(clk_in),
    .rst_in(sys_rst),
    .valid_in(data_valid_in),
    .vertex_a({vertex_ax, vertex_ay}),
    .vertex_b({vertex_bx, vertex_by}),
    .vertex_c({vertex_cx, vertex_cy}),
    .valid_out(data_valid_out), // Note: this is not single cycle
    .pixel_to_color(point_out),
    .last_out(last_out)
);

    always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_in = !clk_in;
    end

    initial begin
      $dumpfile("display.vcd"); //file to store value change dump (vcd)
      $dumpvars(0,display_tb);
      $display("Starting Sim"); 
      clk_in = 0;
      #10;
      vertex_ax = 'd0;
      vertex_ay = 'd0;
      vertex_bx = 'd5;
      vertex_by = 'd15;
      vertex_cx = 'd10;
      vertex_cy = 'd0;
      data_valid_in = 1;
      #10;
      data_valid_in = 0;
      #10000;
      $finish;
    end
endmodule
`default_nettype wire