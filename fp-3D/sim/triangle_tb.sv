`timescale 1ns / 1ps
`default_nettype none

module triangle_tb();
    logic [5:0] vertex_ax;
    logic [5:0] vertex_ay;
    logic [5:0] vertex_bx;
    logic [5:0] vertex_by;
    logic [5:0] vertex_cx;
    logic [5:0] vertex_cy; 
    logic [5:0] point_x;
    logic [5:0] point_y; 

    logic data_valid_in;
    logic data_valid_out;
    logic is_inside;

    logic clk_in;

    
    in_triangle_wrap #(.SYS_BIT_WIDTH(6)) uut (
        .clk_in(clk_in),
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
        .is_inside(is_inside)
    );

    always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_in = !clk_in;
    end

    initial begin
      $dumpfile("triangle.vcd"); //file to store value change dump (vcd)
      $dumpvars(0,triangle_tb);
      $display("Starting Sim"); 
      clk_in = 0;
      #10;
      vertex_ax = 'd0;
      vertex_ay = 'd0;
      vertex_bx = 'd10;
      vertex_by = 'd30;
      vertex_cx = 'd20;
      vertex_cy = 'd0;
      point_x = 'd10;
      point_y = 'd15;
      data_valid_in = 1;
      #10;
      data_valid_in = 0;
      #1000;
      $finish;
    end
endmodule
`default_nettype wire