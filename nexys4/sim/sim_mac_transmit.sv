`timescale 1ns / 1 ps
`default_nettype none

module mac_transmit_tb();

    logic clk_100mhz;
    logic eth_refclk;
    logic rst;
    logic eth_txen;
    logic [1:0] eth_txd;
    logic [7:0] data_in;
    logic data_valid_in;
    logic send_data;

    logic [0:5][7:0] MAC_DEST = 48'hff_ff_ff_ff_ff_ff;

    always begin
        #5;
        clk_100mhz = ~clk_100mhz;
    end

    always_ff @(posedge clk_100mhz) begin
        eth_refclk <= ~eth_refclk;
    end

    mac_transmit mac_transmitter (
        .rst(rst),
        .clk_100mhz(clk_100mhz),
        .eth_refclk(eth_refclk),
        .eth_txen(eth_txen),
        .eth_txd(eth_txd),
        .send_data(send_data), // when asserted, sends the data
        .data_in(data_in),
        .data_valid_in(data_valid_in),
        .mac_dest(MAC_DEST)
    );

    initial begin
        $dumpfile("mac_transmit_tb.vcd");
        $dumpvars(0, mac_transmitter);

        clk_100mhz = 0;
        eth_refclk = 0;
        rst = 1;
        send_data = 0;
        data_in = 0;
        data_valid_in <= 0;
        #100;
        rst = 0;
        data_valid_in <= 1;

        for(int i = 0; i < 50; i++) begin
            data_in <= i;
            #10;
        end

        data_valid_in <= 0;
        send_data <= 1;
        #20
        send_data <= 0;

        #1000000;

        $finish;
    end

endmodule