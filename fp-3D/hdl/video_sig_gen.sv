`timescale 1ns / 1ps
`default_nettype none

module video_sig_gen
#(
  parameter ACTIVE_H_PIXELS = 1280,
  parameter H_FRONT_PORCH = 110,
  parameter H_SYNC_WIDTH = 40,
  parameter H_BACK_PORCH = 220,
  parameter ACTIVE_LINES = 720,
  parameter V_FRONT_PORCH = 5,
  parameter V_SYNC_WIDTH = 5,
  parameter V_BACK_PORCH = 20)
(
  input wire clk_pixel_in,
  input wire rst_in,
  output logic [$clog2(TOTAL_PIXELS)-1:0] hcount_out,
  output logic [$clog2(TOTAL_LINES)-1:0] vcount_out,
  output logic vs_out,
  output logic hs_out,
  output logic ad_out,
  output logic nf_out,
  output logic [5:0] fc_out);
 
  localparam TOTAL_PIXELS = (ACTIVE_H_PIXELS + H_FRONT_PORCH + H_SYNC_WIDTH + H_BACK_PORCH);
  localparam TOTAL_LINES = (ACTIVE_LINES + V_FRONT_PORCH + V_SYNC_WIDTH + V_BACK_PORCH);
  localparam H_SYNC_START = (ACTIVE_H_PIXELS + H_FRONT_PORCH - 1);
  localparam V_SYNC_START = (ACTIVE_LINES + V_FRONT_PORCH - 1);
  localparam frequency = 60;
  logic start;
 
  //your code here
  always_ff @( posedge clk_pixel_in ) begin
    if (rst_in) begin
        hcount_out <= 0;
        vcount_out <= 0;
        vs_out <= 0;
        hs_out <= 0;
        nf_out <= 0;
        fc_out <= 0;
        ad_out <= 0;
        start <= 1;
    end else begin
        if (start) begin
            ad_out <= 1;
            start <= 0;
        end else begin
            if (vcount_out < (TOTAL_LINES - 1)) begin
                if(hcount_out < (TOTAL_PIXELS - 1)) begin
                    hcount_out <=  hcount_out + 1;
                    if (hcount_out == (ACTIVE_H_PIXELS - 1)) begin
                        ad_out <= 0;
                    end

                    //ADJUST hs_out if entering horizontal sync region
                    if (hcount_out < H_SYNC_START) begin
                        hs_out <= 0;
                    end else if (hcount_out < (H_SYNC_START + H_SYNC_WIDTH)) begin
                        hs_out <= 1;
                    end else begin
                        hs_out <= 0;
                    end

                    //ADJUST fc_out, nf_out if entering pure blanking period
                    if ((vcount_out == ACTIVE_LINES) && (hcount_out == (ACTIVE_H_PIXELS - 1))) begin
                        nf_out <= 1;
                        if (fc_out == (frequency - 1)) begin
                            fc_out <= 0;
                        end else begin
                            fc_out <= fc_out + 1;
                        end
                    end

                end else begin
                    hcount_out <= 0;
                    vcount_out <= vcount_out + 1;
                    //ADJUST ad_out if entering active region
                    if (vcount_out < (ACTIVE_LINES - 1)) begin
                        ad_out <= 1;
                    end

                    //ADJUST vs_out if entering vertical sync region
                    if (vcount_out < V_SYNC_START) begin
                        vs_out <= 0;
                    end else if (vcount_out < (V_SYNC_START + V_SYNC_WIDTH)) begin
                        vs_out <= 1;
                    end else begin
                        vs_out <= 0;
                    end
                end
            end else begin
                if(hcount_out < (TOTAL_PIXELS - 1)) begin
                    hcount_out <= hcount_out + 1;

                    //ADJUST hs_out if entering horizontal sync region
                    if (hcount_out < H_SYNC_START) begin
                        hs_out <= 0;
                    end else if (hcount_out < (H_SYNC_START + H_SYNC_WIDTH)) begin
                        hs_out <= 1;
                    end else begin
                        hs_out <= 0;
                    end

                end else begin
                    hcount_out <= 0;
                    vcount_out <= 0;
                    ad_out <= 1;
                end
            end
            if (nf_out) begin
                nf_out <= 0;
            end
        end
    end
    end
endmodule

`default_nettype wire