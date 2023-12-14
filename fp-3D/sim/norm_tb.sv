`timescale 1ns / 1ps
`default_nettype none

module norm_tb();
    logic clk_in;

    logic [31:0] vector1_x;
    logic [31:0] vector1_y;
    logic [31:0] vector1_z;

    logic [31:0] vector2_x;
    logic [31:0] vector2_y;
    logic [31:0] vector2_z;

    logic [31:0] vector3_x;
    logic [31:0] vector3_y;
    logic [31:0] vector3_z;

    logic [31:0] norm_x;
    logic [31:0] norm_y;
    logic [31:0] norm_z;

    logic data_valid_in;
    logic data_valid_out;

    get_normal_wrap uut(
      .clk_in(clk_in),
      .valid_in(data_valid_in),
      .vec_ax(vector1_x), 
      .vec_ay(vector1_y), 
      .vec_az(vector1_z), 
      .vec_bx(vector2_x),
      .vec_by(vector2_y),
      .vec_bz(vector2_z),
      .vec_cx(vector3_x),
      .vec_cy(vector3_y),
      .vec_cz(vector3_z),
      .normal_x(norm_x),
      .normal_y(norm_y),
      .normal_z(norm_z),
      .valid_out(data_valid_out)
    );

    always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_in = !clk_in;
    end

    //https://www.h-schmidt.net/FloatConverter/IEEE754.html
    
    initial begin
      $dumpfile("norm_tb.vcd"); //file to store value change dump (vcd)
      $dumpvars(0,norm_tb);
      $display("Starting Sim"); //print nice message at start
      clk_in = 0;
      #10;
      vector1_x = 32'h4080_0000; // 4 in floating point notation
      vector1_y = 32'h4110_0000; // 9 in floating point notation
      vector1_z = 32'h40c0_0000;
      vector2_x = 32'h4040_0000; // 3
      vector2_y = 32'h4110_0000;
      vector2_z = 32'h40c0_0000;
      vector3_x = 32'h4040_0000;
      vector3_y = 32'h0;
      vector3_z = 32'h40c0_0000;
      data_valid_in = 1;
      #10;
      data_valid_in = 0;
      #2000;
      $finish;
    end
endmodule

`default_nettype wire