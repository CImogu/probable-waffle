module mac_transmit #(
    parameter MODE_100 = 1'b1
) (
    input logic rst,
    input logic clk_100mhz,
    input logic eth_refclk,
    output logic eth_txen,
    output logic [1:0] eth_txd,
    input logic send_data, // when asserted, sends the data
    input logic [7:0] data_in,
    input logic data_valid_in,
    input logic [0:5][7:0] mac_dest,
    output logic busy,
    output logic [3:0] debug_state
    );
    
    // Ethernet II packets
    logic [0:6][7:0] PREAMBLE_P = 56'h55_55_55_55_55_55_55;
    logic [7:0] SFD_P = 8'd213;
    logic [0:5][7:0] MAC_SRC_P = 48'hf2_6a_34_90_cc_01;
    logic [0:1][7:0] ETHERTYPE_P = 16'h08_00;

    logic [15:0] packet_length;
    logic [7:0] packet_buffer_out;
    logic [15:0] byte_count;

    logic [3:0] state; // IDLE, PREAMBLE, SFD, MAC_DST, MAC_SRC, ETHERTYPE, PAYLOAD, CRC, IPG
    logic [0:8][3:0] LENGTH_BYTES = 36'h0_7_1_6_6_2_0_4_c;

    assign debug_state = state;
    assign busy = state != 4'd0/*IDLE*/;

    bram_sdp bram (
        .rst(rst),
        .clk(clk_100mhz),
        .data_in(data_in),
        .enable((state == 4'd6/*PAYLOAD*/ || state == 4'd0/*IDLE*/) && !rst),
        .write_enable(state == 4'd0/*IDLE*/ && data_valid_in),
        .addr(state == 4'd0/*IDLE*/ ? packet_length : ((state == 4'd6/*PAYLOAD*/) ? byte_count : 16'b0)),
        .data_out(packet_buffer_out)
    );

    logic clk_5mhz;
    logic [3:0] clk_5mhz_counter;
    always_ff @(posedge clk_100mhz) begin
        if(rst) begin
            clk_5mhz_counter <= 1;
            clk_5mhz <= 0;
        end else begin
            if (clk_5mhz_counter == 4'd9) begin
                clk_5mhz <= ~clk_5mhz;
                clk_5mhz_counter <= 0;
            end else 
                clk_5mhz_counter <= clk_5mhz_counter + 1;
        end
    end

    logic transmit_clk;
    assign transmit_clk = MODE_100 ? eth_refclk : clk_5mhz;
    logic last_transmit_clk;
    always_ff @(posedge clk_100mhz) begin
        last_transmit_clk <= transmit_clk;
    end

    logic do_transmit_byte;
    logic [7:0] transmit_byte;
    mac_transmit_byte byte_transmitter(
        .rst(rst),
        .clk(clk_100mhz),
        .transmit_clk(transmit_clk),
        .eth_txd(eth_txd),
        .eth_txen(eth_txen),
        .do_transmit_byte(do_transmit_byte),
        .transmit_byte(transmit_byte)
    );

    logic crc_rst;
    logic [31:0] crc_out;
    logic do_crc_byte;
    logic [0:3][7:0] crc_bytes = {
        crc_out[7:0], crc_out[15:8], crc_out[23:16], crc_out[31:24]
    };
    crcbzip2 crc_m(
        .rst(crc_rst),
        .clk(clk_100mhz),
        .transmit_clk(transmit_clk),
        .do_byte_in(do_crc_byte),
        .byte_in(transmit_byte),
        .crc_out(crc_out)
    );

    logic[1:0] byte_clock_counter;

    always_ff @(posedge clk_100mhz) begin
        if (rst) begin
            state <= 4'd0/*IDLE*/;
            packet_length <= 0;
            byte_count <= 0;
            byte_clock_counter <= 0;
            do_transmit_byte <= 0;
            transmit_byte <= 0;
            do_crc_byte <= 0;
            crc_rst <= 1;
        end else begin
            if(state == 4'd0/*IDLE*/) begin
                crc_rst <= 1'b1;
                byte_clock_counter <= 2'b0;
                do_transmit_byte <= 1'b0;
                do_crc_byte <= 1'b0;
                if (send_data)
                    state <= 4'd1/*PREAMBLE*/;
                if (data_valid_in)
                    packet_length <= packet_length + 1;
            end else if (transmit_clk && ~last_transmit_clk) begin
                byte_clock_counter <= byte_clock_counter + 1;
                crc_rst <= 1'b0;
                if(byte_clock_counter == 2'b0) begin
                    transmit_byte <= 
                        state == 4'd1 ? PREAMBLE_P[byte_count] :
                        state == 4'd2 ? SFD_P :
                        state == 4'd3 ? mac_dest[byte_count] : 
                        state == 4'd4 ? MAC_SRC_P[byte_count] : 
                        state == 4'd5 ? ETHERTYPE_P[byte_count] :
                        state == 4'd6 ? packet_buffer_out : 
                        state == 4'd7 ? crc_bytes[byte_count] : 8'bz;
                    do_transmit_byte <= state != 4'd8/*IPG*/;
                    do_crc_byte <= state >= 4'd3/*MAC_DST*/ && state < 4'd7/*CRC*/;

                    if ((LENGTH_BYTES[state] > 0 || state == 4'd6/*PAYLOAD*/) &&
                         byte_count == (state == 4'd6/*PAYLOAD*/ ? packet_length-1 : LENGTH_BYTES[state]-1)) begin
                        if (state == 4'd8/*IPG*/) begin
                            state <= 4'd0/*IDLE*/;
                            packet_length <= 0;
                        end else
                            state <= state + 1;
                        byte_count <= 0;
                    end else
                        byte_count <= byte_count + 1;
                end else begin
                    do_transmit_byte <= 1'b0;
                    do_crc_byte <= 1'b0;
                end
            end
        end
    end

endmodule