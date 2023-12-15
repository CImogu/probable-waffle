`timescale 1ns / 1 ps
`default_nettype none

module smi_device_tb();

    logic clk_100mhz;
    logic rst;
    logic mdio;
    logic mdc;
    logic [4:0] phy_addr;
    logic [4:0] reg_addr;
    logic [15:0] in_data;
    logic do_read;
    logic do_write;
    logic [15:0] out_data;
    logic out_data_valid;
    logic [2:0] debug_state;

    always begin
        #5;
        clk_100mhz = ~clk_100mhz;
    end

    smi_device eth_smi(
        .clk_100mhz(clk_100mhz),
        .rst(rst),
        .mdio(mdio),
        .mdc(mdc),
        .phy_addr(phy_addr),
        .reg_addr(reg_addr),
        .do_read(do_read),
        .do_write(do_write),
        .in_data(in_data),
        .out_data(out_data),
        .out_data_valid(out_data_valid),
        .debug_state(debug_state)
    );

    initial begin
        $dumpfile("smi_device_tb.vcd");
        $dumpvars(0, eth_smi);

        clk_100mhz = 0;
        rst = 1;
        phy_addr = 1;
        reg_addr = 1;
        do_read = 1;
        #10;
        rst = 0;

        #1000000;

        $finish;
    end

endmodule