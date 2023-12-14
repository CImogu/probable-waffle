`timescale 1ns / 1ps
`default_nettype none

module dotp_tb();
    logic clk_in;

    logic [31:0] x_vector;
    logic [31:0] y_vector;
    logic [31:0] z_vector;

    logic [31:0] magnitude_out;
    logic data_valid_in;
    logic data_valid_out;

    magnitude uut(
      .clk_in(clk_in),
      .valid_in(data_valid_in),
      .vector_x(x_vector),
      .vector_y(y_vector),
      .vector_z(z_vector),
      .magnitude(magnitude_out),
      .valid_out(data_valid_out),
      .magnitude_ready(1'b1)
    );

    always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_in = !clk_in;
    end

    //https://www.h-schmidt.net/FloatConverter/IEEE754.html
    
    initial begin
      $dumpfile("vector_tb.vcd"); //file to store value change dump (vcd)
      $dumpvars(0,dotp_tb);
      $display("Starting Sim"); //print nice message at start
      clk_in = 0;
      #10;

      x_vector = 32'h4080_0000; // 4 in floating point notation
      y_vector = 32'h4110_0000; // 9 in floating point notation
      z_vector = 32'h0;
      data_valid_in = 1;
      #10;
      data_valid_in = 0;
      #1000;
      $finish;
    end
endmodule

`default_nettype wire