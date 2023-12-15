module packetizer(
        input wire rst,
        input wire clk_100mhz,
        output logic stream_out,
        output logic stream_out_valid,
        input logic ready_out, // is the RTP module ready?
        output logic prepare_out,
        output logic [15:0] packet_nbits,
        output logic [31:0] packet_timestamp,
        input logic eth_busy
    );

    logic encoder_out;
    logic encoder_out_valid;
    logic encoder_pause;
    logic frame_start;
    logic gob_start;
    logic mb_start;
  
    logic [5:0] mba;
    encoder encoder_m(
        .rst(rst),
        .clk_100mhz(clk_100mhz),
        .stream_out(encoder_out),
        .stream_out_valid(encoder_out_valid),
        .timestamp_out(packet_timestamp),
        .pause(encoder_pause),
        .frame_start(frame_start),
        .gob_start(gob_start),
        .mb_start(mb_start),
        .gob_num(gob_num),
        .mba_abs(mba)
    );

    typedef enum { IDLE, PREPARING, HEADER, DATA, FINISH } state_t;
    state_t state;

    localparam [15:0] header_length = 32;
    localparam [2:0] start_bit = 3'b000;
    logic [2:0] end_bit;
    logic [0:header_length-1] header;
    localparam has_intra = 1'b1;
    localparam has_motion = 1'b0;
    logic [3:0] gob_num; // TODO
    logic [4:0] mbap; // TODO
    logic [4:0] quant = 8; // TODO
    logic [9:0] mv_data = 0;
    assign header = { start_bit, end_bit, has_intra, has_motion, gob_num, mbap, quant, mv_data };
    logic [13:0] bit_idx;

    logic [13:0] data_length;
    logic [13:0] data_length_stuffed;
    logic data_buffer_out;
    logic [13:0] data_buffer_idx;
    bram_sdp #(.DATA_WIDTH(1), .RAM_DEPTH(1500*8)) data_buffer (
        .rst(rst),
        .clk(clk_100mhz),
        .data_in(encoder_out),
        .enable(!rst),
        .write_enable(state == IDLE),
        .addr(state == IDLE ? data_length : data_buffer_idx),
        .data_out(data_buffer_out)
    );

    logic [13:0] n_mbs;

    always_ff @(posedge clk_100mhz) begin
        if (rst) begin
            state <= IDLE;
            prepare_out <= 0;
            bit_idx <= 0;
            stream_out <= 0;
            stream_out_valid <= 0;
            encoder_pause <= 0;
            data_length <= 0;
            data_length_stuffed <= 0;
            n_mbs <= 0;
            data_buffer_idx <= 0;
            mbap <= 0;
        end else begin
            case (state)
            IDLE: begin
                if (~eth_busy && data_length > 2048 && mb_start && n_mbs > 1) begin
                    // Send the next packet
                    prepare_out <= 1;
                    end_bit <= ((header_length + data_length) & 3'b111) == 0 ? 0 : (8 - (header_length + data_length) & 3'b111);
                    data_length_stuffed = (data_length & 3'b111) == 0 ? data_length : (8 + (data_length & 14'b1111_1111_1110_00));
                    packet_nbits <= header_length + data_length_stuffed; // bits
                    state <= PREPARING;
                    encoder_pause <= 1;
                    mbap <= (mba > 1) ? (mba - 2) : 0;
                end else begin
                    if (gob_start) begin
                        n_mbs <= 0;
                    end else if(mb_start) begin
                        n_mbs <= n_mbs + 1;
                    end
                    encoder_pause <= 0;
                    if (encoder_out_valid) begin
                        data_length <= data_length + 1;
                    end
                end
            end PREPARING: begin
                prepare_out <= 0;
                if (ready_out) begin
                    state <= HEADER;
                end
            end HEADER: begin
                stream_out <= header[bit_idx];
                stream_out_valid <= 1'b1;
                bit_idx <= bit_idx + 1;
                if (bit_idx == header_length - 1) begin
                    data_buffer_idx <= 1;
                    bit_idx <= 0;
                    state <= DATA;
                end
                if (bit_idx == header_length - 2) begin
                    data_buffer_idx <= 0;
                end
            end DATA: begin
                data_buffer_idx <= data_buffer_idx + 1;
                stream_out <= (data_buffer_idx > data_length - 1) ? 1'b0 : data_buffer_out; // data_buffer_out is delayed
                stream_out_valid <= 1; //bit_idx > 0;
                if (data_buffer_idx == data_length_stuffed - 1) begin
                    state <= FINISH;
                end
            end FINISH: begin
                stream_out_valid <= 1'b0;
                state <= IDLE;
                n_mbs <= 0;
                data_length <= 0;
                data_length_stuffed <= 0;
                bit_idx <= 0;
            end
            endcase
        end
    end

endmodule