`timescale 1ns / 1 ps
`default_nettype none

module mac_transmit_tb();

    logic clk_100mhz;
    logic rst;
    logic clk;
    logic input_valid;
    logic [8:0] data [7:0][7:0];
    logic [8:0] transformed [7:0][7:0];
    logic output_valid;

    always begin
        #5;
        clk_100mhz = ~clk_100mhz;
    end

    block_transform block_transformer (
        .rst(rst),
        .clk(clk_100mhz),
        .input_valid(input_valid),
        .data(data),
        .transformed(transformed),
        .output_valid(output_valid)
    );

    initial begin
        $dumpfile("block_transform_tb.vcd");
        $dumpvars(0, block_transformer);

        clk_100mhz = 0;
        rst = 1;
        input_valid = 0;
        for(int i = 0; i < 7; i++) begin
            for(int j = 0; j < 7; j++) begin
                data[i][j] <= i*j;
            end
        end
        #100;
        rst = 0;

        input_valid = 1;
        #100
        input_valid = 0;

        #100000;

        input_valid = 1;
        #100
        input_valid = 0;

        #100000;

        $finish;
    end

endmodule