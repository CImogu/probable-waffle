`timescale 1ns / 1ps
`default_nettype none

module threegen_tb();
    logic [31:0] vertex_x;
    logic [31:0] vertex_y;
    logic [31:0] vertex_z; 
    logic [23:0] color;

    logic [20:0] player1;
    logic [20:0] player2;
    logic [20:0] bullet1;
    logic [20:0] bullet2;

    logic data_valid_in;
    logic data_valid_out;
    logic last_out;

    logic clk_in;
    logic sys_rst;

    
    threegen_wrap2 uut(
    .clk_in(clk_in),
    .rst_in(sys_rst),
    .valid_in(data_valid_in),
    .player1(player1), // {x(11 bits), y(10 bits)} -> get all at once for now
    .player2(player2),
    .bullet1(bullet1),
    .bullet2(bullet2), 
    .valid_out(data_valid_out),
    .triangle_x(vertex_x),
    .triangle_y(vertex_y),
    .triangle_z(vertex_z),
    .color(color),
    .last_out(last_out)
    );

    always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_in = !clk_in;
    end

    initial begin
      $dumpfile("triangle.vcd"); //file to store value change dump (vcd)
      $dumpvars(0,threegen_tb);
      $display("Starting Sim"); 
      clk_in = 0;
      #10;
      sys_rst = 1;
      #10;
      sys_rst = 0;
      #10;
      player1 = {11'd5, 10'd4};
      player2 = {11'd10, 10'd6};
      bullet1 = {11'd7, 10'd4};
      bullet2 = {11'd14, 10'd6};
      data_valid_in = 1;
      #10;
      data_valid_in = 0;
      #4000;
      $finish;
    end
endmodule
`default_nettype wire