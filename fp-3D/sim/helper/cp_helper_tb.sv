`timescale 1ns / 1ps
`default_nettype none

module cp_helper_tb();
    logic [5:0] point_ax;
    logic [5:0] point_ay;
    logic [5:0] point_bx;
    logic [5:0] point_by;
    logic [5:0] point_cx;
    logic [5:0] point_cy; 
    logic signed [6:0] vec_ab_out_x;
    logic signed [6:0] vec_ab_out_y;
    logic signed [6:0] vec_ac_out_x;
    logic signed [6:0] vec_ac_out_y;

    logic data_valid_in;
    logic data_valid_out;
    logic signed [12:0] value_out;

    logic clk_in;


    p2v_wrap #(.SYS_BIT_WIDTH(6)) uut1 (
        .point_ax(point_ax),
        .point_ay(point_ay),
        .point_bx(point_bx),
        .point_by(point_by),
        .vec_ab_out_x(vec_ab_out_x),
        .vec_ab_out_y(vec_ab_out_y)
        );

    p2v_wrap #(.SYS_BIT_WIDTH(6)) uut2 (
        .point_ax(point_ax),
        .point_ay(point_ay),
        .point_bx(point_cx),
        .point_by(point_cy),
        .vec_ab_out_x(vec_ac_out_x),
        .vec_ab_out_y(vec_ac_out_y)
        );
    
    cp_helper #(.SYS_BIT_WIDTH(6)) uut3 (
        .clk_in(clk_in),
        .valid_in(data_valid_in),
        .vec_ax(vec_ab_out_x),
        .vec_ay(vec_ab_out_y),
        .vec_bx(vec_ac_out_x),
        .vec_by(vec_ac_out_y),
        .valid_out(data_valid_out),
        .value_out(value_out)
    );

    always begin
      #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
      clk_in = !clk_in;
    end

    initial begin
      $dumpfile("cp_helper.vcd"); //file to store value change dump (vcd)
      $dumpvars(0,cp_helper_tb);
      $display("Starting Sim"); 
      clk_in = 0;
      #10;
      point_ax = 'd0;
      point_ay = 'd0;
      point_bx = 'd10;
      point_by = 'd30;
      point_cx = 'd20;
      point_cy = 'd0;
      data_valid_in = 1;
      #10;
      data_valid_in = 0;
      #1000;
      $finish;
    end
endmodule
`default_nettype wire