`timescale 1ns / 1 ps
`default_nettype none

module top_level_tb();

    logic clk_100mhz;
    logic rst;
    logic [15:0] led;
    logic eth_refclk;
    logic eth_rstn;
    logic [1:0] ja;
    logic eth_txen;
    logic [1:0] eth_txd;
    logic eth_mdio;
    logic eth_mdc;
    logic eth_busy = 1'b0;

    always begin
        #5;
        clk_100mhz = ~clk_100mhz;
    end


    logic [31:0] packet_timestamp;

    logic stream;
    logic stream_valid;
    packetizer packetizer_m(
        .rst(rst),
        .clk_100mhz(clk_100mhz),
        .stream_out(stream),
        .stream_out_valid(stream_valid),
        .ready_out(rtp_ready_for_data),
        .prepare_out(rtp_prepare_for_data),
        .packet_nbits(rtp_payload_size),
        .packet_timestamp(packet_timestamp),
        .eth_busy(eth_busy)
    );

    logic [15:0] rtp_payload_size;// = 64*8;
    logic rtp_ready_for_data;
    logic rtp_prepare_for_data;
    BitwiseRTPModule rtp_sender (
        .clk_in(clk_100mhz),
        .rst_in(rst),
        .data_in(stream),
        .data_valid_in(stream_valid),
        .prepare_for_data(rtp_prepare_for_data),
        .payload_size(rtp_payload_size),
        .rtp_timestamp(packet_timestamp),
        .rtp_marker_in(1'b1),
        .data_out(eth_data),
        .valid_out(eth_data_valid),
        .ready_for_data(rtp_ready_for_data),
        .send_out(eth_send_data)
    );

    logic [7:0] eth_data;
    logic eth_data_valid;
    logic eth_send_data;

    initial begin
        $dumpfile("top_level_tb.vcd");
        $dumpvars(0, top_level_tb);

        clk_100mhz = 0;
        rst = 1;
        #100;
        rst = 0;

        #1000000;

        $finish;
    end

endmodule