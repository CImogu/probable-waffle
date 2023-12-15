module mac_transmit_byte(
    input logic rst,
    input logic clk,
    input logic transmit_clk,
    output logic [1:0] eth_txd,
    output logic eth_txen,
    input logic do_transmit_byte,
    input logic [7:0] transmit_byte
    );

    logic [7:0] dibit_count;
    logic [7:0] transmit_byte_cache;
    logic is_transmitting;

    logic last_transmit_clk;
    always_ff @(posedge clk) begin
        last_transmit_clk <= transmit_clk;
    end

    always_ff @(posedge clk) begin
        if(rst) begin
            dibit_count <= 0;
            transmit_byte_cache <= 0;
            is_transmitting <= 0;
            eth_txen <= 0;
            eth_txd <= 0;
        end else if (transmit_clk && ~last_transmit_clk) begin
            if (is_transmitting) begin
                eth_txd[0] <= transmit_byte_cache[dibit_count << 1];
                eth_txd[1] <= transmit_byte_cache[(dibit_count << 1) + 1];
                dibit_count <= dibit_count + 1;
                eth_txen <= 1'b1;
            end
            if((!is_transmitting || (is_transmitting && dibit_count == 3)) && do_transmit_byte) begin
                transmit_byte_cache <= transmit_byte;
                dibit_count <= 0;
                is_transmitting <= 1'b1;
            end else if (!is_transmitting || (is_transmitting && dibit_count == 4 && !do_transmit_byte)) begin
                eth_txen <= 1'b0;
                dibit_count <= 0;
                is_transmitting <= 1'b0;
            end
        end
    end

endmodule 