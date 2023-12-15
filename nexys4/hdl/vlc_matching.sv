module block_vlc(
    input wire rst_in,
    input wire clk_in,
    input logic data_valid,
    input logic signed [7:0] data [7:0][7:0],
    input logic isIntra,
    output logic out_stream,
    output logic out_valid,
    output logic vlc_streaming,
    input logic pause
);
    logic [5:0] xy;
    logic [2:0] x;
    logic [2:0] y;
    assign x = xy[5:3];
    assign y = xy[2:0];

    logic [7:0] level;
    assign level = 8'd10; //data[x][y];
    logic [7:0] abslevel;
    assign abslevel = (level[7] == 1'b1) ? -level : level;
    logic sign;
    assign sign = level[7];

    logic [6:0] bit_idx;
    logic get_vlc;
    logic [5:0] run;

    logic [22:0] vlc;
    logic [5:0] vlc_size;
    logic [19:0] bitstream;
    logic [4:0] size;
    logic eob_idx;
    logic eob;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin //rest
            xy <= 0;
            bit_idx <= 0;
            vlc_streaming <= 0;
            out_stream <= 0;
            out_valid <= 0;
            get_vlc <= 0;
            vlc <= 0;
            vlc_size <= 0;
            run <= 0;
            eob <= 0;
            eob_idx <= 0;
        end else if (~pause) begin
            if(~vlc_streaming) begin
                if (data_valid) begin
                    vlc_streaming <= 1;
                    get_vlc <= 1;
                    xy <= 0;
                    run <= 0;
                end
                out_valid <= 0;
            end else if (get_vlc) begin
                if ((xy == 0) && isIntra) begin //GetVCL part of the code
                    vlc <= {3'b000, level};
                    vlc_size <= 8 + 3; // HACK: add 3 0's because of bad pipelining
                end else begin
                    if ((xy == 0) && (abslevel == 1)) begin
                        vlc <= {1'b1, sign};
                        vlc_size <= 2;
                    end else if (level ==0) begin
                        run <= run + 1;
                    end else begin
                        vlc <= bitstream;
                        vlc_size <= size;
                        run <= 0;
                    end
                end
                get_vlc <= 0;
                out_valid <= 0;
            end else if (eob) begin
                out_valid <= 1;
                out_stream <= ~eob_idx;
                eob_idx <= eob_idx + 1;
                if (eob_idx == 1) begin
                    eob <= 0;
                    eob_idx <= 0;
                    vlc_streaming <= 0;
                end
            end else begin
                bit_idx <= bit_idx + 1;
                out_stream <= vlc[vlc_size - 1 - bit_idx];
                out_valid <= 1;
                if (bit_idx == vlc_size - 1) begin
                    xy <= xy + 1;
                    if (xy == 6'd63) begin
                        eob <= 1;
                        eob_idx <= 0;
                    end else begin
                        get_vlc <= 1;  
                    end
                    bit_idx <= 0;
                end
            end
        end
    end

    TcoeffTable looking_up(
        .clk_in(clk_in),
        .rst_in(rst_in),
        .run(run),
        .level(level), // 8-bit to include sign bit
        .bitstream(bitstream),
        .size(size)
    );

endmodule



module TcoeffTable(
    input wire clk_in,
    input wire rst_in,
    input wire [5:0] run,
    input wire signed [7:0] level, // 8-bit to include sign bit
    output reg [19:0] bitstream,
    output reg [4:0] size
);

logic [7:0] abslevel;
assign abslevel = (level[7] == 1'b1) ? -level : level;
logic sign;
assign sign = level[7];

always_ff @(posedge clk_in) begin
    if (rst_in) begin
        bitstream <= 0;
        size <= 0;
    end else begin
        if (level == (-127)) begin
            bitstream <= 8'b1000_0001; 
            size <= 8;
        end else begin

            case (run)
                5'd0: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {2'b11, sign}; size <= 3; end
                        8'd2: begin bitstream <= {4'b0100, sign}; size <= 5; end
                        8'd3: begin bitstream <= {5'b00101, sign}; size <= 6; end
                        8'd4: begin bitstream <= {7'b0000110, sign}; size <= 8; end
                        8'd5: begin bitstream <= {8'b001_00110, sign}; size <= 9; end
                        8'd6: begin bitstream <= {8'b0010_0001, sign}; size <= 9; end
                        8'd7: begin bitstream <= {10'b0000_0010_10, sign}; size <= 11; end

                        8'd8: begin bitstream <= {12'b0000_0001_1101, sign}; size <= 13; end
                        8'd9: begin bitstream <= {12'b0000_0001_1000, sign}; size <= 13; end
                        8'd10: begin bitstream <= {12'b0000_0001_0011, sign}; size <= 13; end
                        8'd11: begin bitstream <= {12'b0000_0001_0000, sign}; size <= 13; end

                        8'd12: begin bitstream <= {13'b0000_0000_1101_0, sign}; size <= 14; end
                        8'd13: begin bitstream <= {13'b0000_0000_1100_1, sign}; size <= 14; end
                        8'd14: begin bitstream <= {13'b0000_0000_1100_0, sign}; size <= 14; end
                        8'd15: begin bitstream <= {13'b0000_0000_1011_1, sign}; size <= 14; end

                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end
                    endcase
                end
                5'd1: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {3'b011, sign}; size <= 4; end
                        8'd2: begin bitstream <= {6'b000110, sign}; size <= 7; end
                        8'd3: begin bitstream <= {8'b0010_0101, sign}; size <= 9; end
                        8'd4: begin bitstream <= {10'b0000_0011_00, sign}; size <= 11; end

                        8'd5: begin bitstream <= {12'b0000_0001_1011, sign}; size <= 13; end
                        8'd6: begin bitstream <= {13'b0000_0000_1011_0, sign}; size <= 14; end
                        8'd7: begin bitstream <= {13'b0000_0000_1010_1, sign}; size <= 14; end

                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end
                    endcase
                end
                5'd2: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {4'b0101, sign}; size <= 5; end
                        8'd2: begin bitstream <= {7'b0000_100, sign}; size <= 8; end
                        8'd3: begin bitstream <= {10'b0000_0010_11, sign}; size <= 11; end

                        8'd4: begin bitstream <= {12'b0000_0001_0100, sign}; size <= 13; end
                        8'd5: begin bitstream <= {13'b0000_0000_1010_0, sign}; size <= 14; end
                    
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end
                    endcase
                end
                5'd3: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {5'b0011_1, sign}; size <= 6; end
                        8'd2: begin bitstream <= {8'b0010_0100 , sign}; size <= 9; end

                        8'd3: begin bitstream <= {12'b0000_0001_1100 , sign}; size <= 13; end
                        8'd4: begin bitstream <= {13'b0000_0000_1001_1, sign}; size <= 14; end

                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end
                    endcase
                end

                5'd4: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {5'b0011_0, sign}; size <= 6; end
                        8'd2: begin bitstream <= {10'b0000_0011_11, sign}; size <= 11; end

                        8'd3: begin bitstream <= {12'b0000_0001_0010, sign}; size <= 13; end

                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end
                    endcase
                end
                5'd5: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {6'b0001_11, sign}; size <= 7; end
                        8'd2: begin bitstream <= {10'b0000_0010_01, sign}; size <= 11; end

                        8'd3: begin bitstream <= {13'b0000_0000_1001_0, sign}; size <= 14; end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end
                    endcase
                end
                5'd6: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {6'b0001_01, sign}; size <= 7; end
                        8'd2: begin bitstream <= {12'b0000_0001_1110, sign}; size <= 13; end

                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase
                end
                5'd7: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {6'b0001_00, sign}; size <= 7; end
                        8'd2: begin bitstream <= {12'b0000_0001_0101, sign}; size <= 13; end

                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase
                end
                5'd8: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {7'b0000_111, sign}; size <= 8; end
                        8'd2: begin bitstream <= {12'b0000_0001_0001, sign}; size <= 13; end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase
                end
                5'd9: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {7'b0000_101, sign}; size <= 8; end
                        8'd2: begin bitstream <= {13'b0000_0000_1000_1, sign}; size <= 14; end
                        
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end
                    endcase
                end
                5'd10: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {8'b0010_0111, sign}; size <= 9; end
                        8'd2: begin bitstream <= {13'b0000_0000_1000_0, sign}; size <= 14; end

                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase
                end
                5'd11: begin
                    case (abslevel)
                        8'd1: begin
                        bitstream <= {8'b0010_0011, sign}; 
                        size <= 9;
                        end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd12: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {8'b0010_0010, sign}; 
                    size <= 9;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd13: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {8'b0010_0000, sign}; 
                    size <= 9;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd14: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {10'b0000_0011_10, sign}; 
                    size <= 11;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd15: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {10'b0000_0011_01, sign}; 
                    size <= 11;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd16: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {10'b0000_0010_00, sign}; 
                    size <= 11;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd17: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {12'b0000_0001_1111, sign}; 
                    size <= 13;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd18: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {12'b0000_0001_1010, sign}; 
                    size <= 13;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd19: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {12'b0000_0001_1001, sign}; 
                    size <= 13;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd20: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {12'b0000_0001_0111, sign}; 
                    size <= 13;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd21: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {12'b0000_0001_0110, sign}; 
                    size <= 13;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd22: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {13'b0000_0000_1111_1, sign}; 
                    size <= 14;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd23: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {13'b0000_0000_1111_0, sign}; 
                    size <= 14;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd24: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {13'b0000_0000_1110_1, sign}; 
                    size <= 14;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd25: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {13'b0000_0000_1110_0, sign}; 
                    size <= 14;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd26: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {13'b0000_0000_1101_1, sign}; 
                    size <= 14;
                    end
                        default: begin
                            bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                
                // Add more cases for other run values

                default: begin
                    bitstream <= {6'b0000_01, run, level};
                            size <= 20;
                end
            endcase

        end
    end
end

endmodule