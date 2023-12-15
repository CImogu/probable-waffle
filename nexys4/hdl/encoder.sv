module encoder(
        input logic rst,
        input logic clk_100mhz,
        output logic stream_out,
        output logic stream_out_valid,
        output logic [31:0] timestamp_out,
        output logic frame_start,
        output logic gob_start,
        output logic mb_start,
        input logic pause,
        output logic [3:0] gob_num,
        output logic [5:0] mba_abs
    );

    localparam INITIAL_TIMESTAMP = 32'd38127687; // random

    logic [10:0] clk_90khz_counter;
    logic [31:0] timestamp; // 90 khz clock
    always_ff @(posedge clk_100mhz) begin
        if (rst) begin
            clk_90khz_counter <= 0;
            timestamp <= INITIAL_TIMESTAMP;
        end else if(clk_90khz_counter == 11'd1110) begin
            clk_90khz_counter <= 0;
            timestamp <= timestamp + 1;
        end else
            clk_90khz_counter <= clk_90khz_counter + 1;
    end

    logic signed [8:0] sampled_blocks [5:0][7:0][7:0];
    logic signed [7:0] transformed_blocks [5:0][7:0][7:0];
    logic block_output_valid[5:0];
    logic block_do_compute;
    logic block_computing[5:0];
    logic mb_is_intra = 1'b1;

    /*block_transform transform[5:0] (
        .rst(rst),
        .clk(clk_100mhz),
        .do_compute(block_do_compute),
        .computing(block_computing),
        .is_intra(mb_is_intra),
        .data(sampled_blocks),
        .data_out(transformed_blocks),
        .output_valid(block_output_valid)
    );*/

    logic [15:0] frame_idx;
    logic [3:0] gob_idx;
    logic [5:0] mb_idx;
    logic [2:0] block_idx;
    logic [7:0] bit_idx;

    logic vlc_out;
    logic vlc_valid;
    logic do_vlc;
    logic vlc_streaming;
    block_vlc vlc (
        .rst_in(rst),
        .clk_in(clk_100mhz),
        .data_valid(do_vlc),
        //.data(transformed_blocks[block_idx]),
        .isIntra(mb_is_intra),
        .out_stream(vlc_out),
        .out_valid(vlc_valid),
        .vlc_streaming(vlc_streaming),
        .pause(pause)
    );

    localparam fpr = 1'b1; // freeze picture release
    localparam is_cif = 1'b0;
    localparam [4:0] gquant = 5'd8; 

    localparam mba = 1'b1; // hardcoded for now bc we transmit all 
    localparam [5:0] cbp = 6'b001100; // for inter encoded macroblocks only; we send all blocks

    logic [0:31] picture_header;
    assign picture_header = {
        20'b0000_0000_0000_0001_0000, frame_idx[4:0], 2'b00, fpr, is_cif, 3'b010
    };
    assign gob_num = is_cif ? (gob_idx + 1) : ((gob_idx << 1) + 1);
    logic [0:25] gob_header;
    assign gob_header = {
        16'b1, gob_num, gquant, 1'b0
    };
    localparam mb_header_intra_length = 5;
    localparam [0:mb_header_intra_length-1] mb_header_intra = { mba, 4'b0001 };
    localparam mb_header_inter_length = 8;
    localparam [0:mb_header_inter_length-1] mb_header_inter = { mba, 1'b1, cbp };
    typedef enum { START_FRAME, WAIT, PICTURE_HEADER, GOB_HEADER, MB_HEADER, BLOCK_DATA } state_t;

    state_t state;
    logic last_pause;
    logic last_vlc_streaming;

    assign mba_abs = mb_idx + 1;

    always_ff @(posedge clk_100mhz) begin
        last_pause <= pause;
        last_vlc_streaming <= vlc_streaming;
        if (rst) begin
            frame_idx <= 0;
            gob_idx <= 0;
            mb_idx <= 0;
            block_do_compute <= 0;
            state <= START_FRAME;
            bit_idx <= 0;
            block_idx <= 0;
            stream_out_valid <= 0;
            stream_out <= 0;
            frame_start <= 0;
            gob_start <= 0;
            mb_start <= 0;
            do_vlc <= 0;
        end else if (frame_start || gob_start || mb_start) begin
            stream_out_valid <= 0;
            frame_start <= 0;
            gob_start <= 0;
            mb_start <= 0; // wait for one cycle for all three signals
        end else if (pause) begin
            stream_out_valid <= 0;
            if (~last_pause) begin
                block_do_compute <= 1;
            end
        end else begin
            case(state)
            START_FRAME: begin
                timestamp_out <= timestamp;
                state <= PICTURE_HEADER;
                frame_start <= 1;
                stream_out_valid <= 0;
            end PICTURE_HEADER: begin
                gob_idx <= 0;
                bit_idx <= bit_idx + 1;
                stream_out_valid <= 1;
                stream_out <= picture_header[bit_idx];
                if (bit_idx == 31) begin
                    state <= GOB_HEADER;
                    gob_start <= 1;
                    bit_idx <= 0;
                end
            end GOB_HEADER: begin
                mb_idx <= 0;
                bit_idx <= bit_idx + 1;
                stream_out <= gob_header[bit_idx];
                stream_out_valid <= 1;
                if (bit_idx == 25) begin
                    state <= MB_HEADER;
                    mb_start <= 1;
                    bit_idx <= 0;
                end
            end MB_HEADER: begin
                block_idx <= 0;
                bit_idx <= bit_idx + 1;
                if (mb_is_intra) begin
                    stream_out <= mb_header_intra[bit_idx];
                    if (bit_idx == mb_header_intra_length-1) begin
                        state <= BLOCK_DATA;
                        bit_idx <= 0;
                        do_vlc <= 1;
                    end
                end else begin
                    stream_out <= mb_header_inter[bit_idx];
                    if (bit_idx == mb_header_inter_length-1) begin
                        state <= BLOCK_DATA;
                        bit_idx <= 0;
                        do_vlc <= 1;
                    end
                end
                stream_out_valid <= 1;
            end BLOCK_DATA: begin
                if (vlc_valid) begin
                    stream_out <= vlc_out;
                    stream_out_valid <= 1;
                end else
                    stream_out_valid <= 0;
                if (last_vlc_streaming && ~vlc_streaming) begin
                    block_idx <= block_idx + 1;
                    do_vlc <= 1;
                    if (block_idx == 5) begin
                        block_idx <= 0;
                        mb_idx <= mb_idx + 1;
                        if (mb_idx == 32) begin
                            mb_idx <= 0;
                            gob_idx <= gob_idx + 1;
                            if (gob_idx == (is_cif ? 11 : 2)) begin
                                gob_idx <= 0;
                                frame_idx <= frame_idx + 1;
                                state <= START_FRAME;
                            end else begin
                                state <= GOB_HEADER;
                                gob_start <= 1;
                            end
                        end else begin
                            state <= MB_HEADER;
                            mb_start <= 1;
                        end
                    end
                end else
                    do_vlc <= 0;
            end
            endcase
        end
    end

endmodule