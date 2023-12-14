`timescale 1ns / 1ps
`default_nettype none

module p2v_tb ();
    logic [5:0] point_ax;
    logic [5:0] point_ay;
    logic [5:0] point_bx;
    logic [5:0] point_by;
    logic signed [6:0] vec_ab_out_x;
    logic signed [6:0] vec_ab_out_y;


    p2v_wrap #(.MAX_BIT_WIDTH(6)) uut (
        .point_ax(point_ax),
        .point_ay(point_ay),
        .point_bx(point_bx),
        .point_by(point_by),
        .vec_ab_out_x(vec_ab_out_x),
        .vec_ab_out_y(vec_ab_out_y)
        );
    
    initial begin
        #10;
        $display("\n---------\nStarting Simulation!");
        point_ax = 'd0;
        point_ay = 'd0;
        point_bx = 'd10;
        point_by = 'd30;
        #10;
        $display("Out: %d  %d ", vec_ab_out_x, vec_ab_out_y);
        $finish;
    end
endmodule