module bram_sdp #(
    parameter DATA_WIDTH = 8,
    parameter RAM_DEPTH = 1500
) (
    input logic rst,
    input logic clk,
    input logic enable,
    input logic [DATA_WIDTH-1:0] data_in,
    input logic write_enable,
    input logic [$clog2(RAM_DEPTH)-1:0] addr,
    output logic [DATA_WIDTH-1:0] data_out
    );

    reg [DATA_WIDTH-1:0] bram [RAM_DEPTH-1:0];

    always_ff @(posedge clk) begin
        if (rst) begin
        end else begin
            if (enable) begin
                if (write_enable)
                    bram[addr] <= data_in;
                else
                    data_out <= bram[addr];
            end
        end     
    end

endmodule