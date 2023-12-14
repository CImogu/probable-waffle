module block_transform(
    input wire rst,
    input wire clk,
    input logic data_valid,
    input logic signed [8:0] data [7:0][7:0],
    input logic isIntra,
    output logic out_stream,
    output logic out_valid
);

    logic [5:0] idx;
    logic [5:0] run;
    logic signed [7:0] level;
    logic [5:0] line;
    logic [4:0] i;
    logic [5:0] x;
    logic [5:0] y;
    logic up;
    logic [19:0] bitstream;
    logic [4:0] counter_size;
    logic [4:0] size;
    logic [19:0] vlc;
    logic [4:0] vlc_size;
    logic start_bitstream;

    logic streaming;
    logic vcl_found
    logic half;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin //rest
            run <= 0;
            idx <= 0;
            line <= 0;
            counter_size <= 0;
            vcl_found <= 0;
            streaming <= 1;
            half <= 0;
        end else begin
            if (data_valid) begin
                start_bitstream <= 1;
            end
            if (start_bitstream) begin
            
                if (line < 8) begin //first loop
                    if (i < line) begin

                        if (streaming) begin //sends out stream for each nested loop iteration

                            if (vcl_found == 0) begin //find VCL
                                if ((idx == 0) && isIntra) begin //GetVCL part of the code
                                    vlc <= level;
                                    vlc_size <= 8;
                                end else begin
                                    abslevel = (level[7] == 1'b1) ? -level : level; // Compute absolute value
                                    sign <= level[7]; // Sign bit

                                    if ((idx == 0) && (abslevel == 1)) begin
                                        vlc <= {1'b1, sign};
                                        vlc_size <= 2;
                                    end else if (level ==0) begin
                                        run <= run + 1; //DEFINITELY WRONG!!! idk what the * is doing in the OG code
                                    end else begin
                                        vcl <= bitstream;
                                        vcl_size <= size;
                                        run <= 0;
                                    end
                                end
                                vcl_found <= 1;
                            end else begin //Send VCL
                                if (vcl_size > counter_size) begin
                                    out_valid <= 1;
                                    out_stream <= vcl[counter_size];
                                    counter_size <= counter_size +1;
                                end else begin
                                    streaming <= 0;
                                    counter_size <= 0;
                                    out_valid <= 0;
                                end
                            end

                        end else begin //goes to the next nested loop iteration
                            
                            i <= i +1;
                            idx <= idx + 1;
                            streaming <= 1;
                            vcl_found <= 0;
                        end

                    end else begin
                        line <= line + 1;
                        i <= 0;
                    end
                end else begin
                    if (half == 1) begin
                        start_bitstream <= 0;
                        half <= 0;
                    end else begin
                        half <= 1;
                    end
                end
            end

        end
    end

    always_comb begin
        
        if (half == 0) begin
            up = (line%2) == 0;
            x = up ? i : (line - i);
            y = up ? (line - i) : i;
        end else begin
            up = (line%2) == 1;
            x = up ? line_x + i : (7 - i);
            y = up ? (7 - i) : line_x + i;
        end


        level = data[y][x][idx];

    end

    TcoeffTable looking_up(
    .run(run),
    .level(level), // 8-bit to include sign bit
    .bitstream(bitstream),
    .size(size)
);

endmodule



module TcoeffTable(
    input wire [5:0] run,
    input wire signed [7:0] level, // 8-bit to include sign bit
    output reg [19:0] bitstream,
    output reg [4:0] size
);

reg [7:0] abslevel;
reg sign;

always_comb begin
    if (reset) begin
        bitstream <= 0;
        size <= 0;
    end else begin
        abslevel = (level[7] == 1'b1) ? -level : level; // Compute absolute value
        sign = level[7]; // Sign bit

        if (level == (-127)) begin
            bitstream <= 8'b1000 0001; 
            size <= 8;
        end else begin

            case (run)
                5'd0: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {2'b11, sign}; size <= 3; end
                        8'd2: begin bitstream <= {4'b0100, sign}; size <= 5; end
                        8'd3: begin bitstream <= {5'b00101, sign}; size <= 6; end
                        8'd4: begin bitstream <= {7'b0000110, sign}; size <= 8; end
                        8'd5: begin bitstream <= {8'b001 00110, sign}; size <= 9; end
                        8'd6: begin bitstream <= {8'b0010 0001, sign}; size <= 9; end
                        8'd7: begin bitstream <= {10'b0000 0010 10, sign}; size <= 11; end

                        8'd8: begin bitstream <= {12'b0000 0001 1101, sign}; size <= 13; end
                        8'd9: begin bitstream <= {12'b0000 0001 1000, sign}; size <= 13; end
                        8'd10: begin bitstream <= {12'b0000 0001 0011, sign}; size <= 13; end
                        8'd11: begin bitstream <= {12'b0000 0001 0000, sign}; size <= 13; end

                        8'd12: begin bitstream <= {13'b0000 0000 1101 0, sign}; size <= 14; end
                        8'd13: begin bitstream <= {13'b0000 0000 1100 1, sign}; size <= 14; end
                        8'd14: begin bitstream <= {13'b0000 0000 1100 0, sign}; size <= 14; end
                        8'd15: begin bitstream <= {13'b0000 0000 1011 1, sign}; size <= 14; end

                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end
                    endcase
                end
                5'd1: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {3'b011, sign}; size <= 4; end
                        8'd2: begin bitstream <= {6'b000110, sign}; size <= 7; end
                        8'd3: begin bitstream <= {8'b0010 0101, sign}; size <= 9; end
                        8'd4: begin bitstream <= {10'b0000 0011 00, sign}; size <= 11; end

                        8'd5: begin bitstream <= {12'b0000 0001 1011, sign}; size <= 13; end
                        8'd6: begin bitstream <= {13'b0000 0000 1011 0, sign}; size <= 14; end
                        8'd7: begin bitstream <= {13'b0000 0000 1010 1, sign}; size <= 14; end

                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end
                    endcase
                end
                5'd2: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {4'b0101, sign}; size <= 5; end
                        8'd2: begin bitstream <= {7'b0000 100, sign}; size <= 8; end
                        8'd3: begin bitstream <= {10'b0000 0010 11, sign}; size <= 11; end

                        8'd4: begin bitstream <= {12'b0000 0001 0100, sign}; size <= 13; end
                        8'd5: begin bitstream <= {13'b0000 0000 1010 0, sign}; size <= 14; end
                    
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end
                    endcase
                end
                5'd3: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {5'b0011 1, sign}; size <= 6; end
                        8'd2: begin bitstream <= {8'b0010 0100 , sign}; size <= 9; end

                        8'd3: begin bitstream <= {12'b0000 0001 1100 , sign}; size <= 13; end
                        8'd4: begin bitstream <= {13'b0000 0000 1001 1, sign}; size <= 14; end

                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end
                    endcase
                end

                5'd4: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {5'b0011 0, sign}; size <= 6; end
                        8'd2: begin bitstream <= {10'b0000 0011 11, sign}; size <= 11; end

                        8'd3: begin bitstream <= {12'b0000 0001 0010, sign}; size <= 13; end

                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end
                    endcase
                end
                5'd5: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {6'b0001 11, sign}; size <= 7; end
                        8'd2: begin bitstream <= {10'b0000 0010 01, sign}; size <= 11; end

                        8'd3: begin bitstream <= {13'b0000 0000 1001 0, sign}; size <= 14; end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end
                    endcase
                end
                5'd6: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {6'b0001 01, sign}; size <= 7; end
                        8'd2: begin bitstream <= {12'b0000 0001 1110, sign}; size <= 13; end

                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase
                end
                5'd7: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {6'b0001 00, sign}; size <= 7; end
                        8'd2: begin bitstream <= {12'b0000 0001 0101, sign}; size <= 13; end

                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase
                end
                5'd8: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {7'b0000 111, sign}; size <= 8; end
                        8'd2: begin bitstream <= {12'b0000 0001 0001, sign}; size <= 13; end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase
                end
                5'd9: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {7'b0000 101, sign}; size <= 8; end
                        8'd2: begin bitstream <= {13'b0000 0000 1000 1, sign}; size <= 14; end
                        
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end
                    endcase
                end
                5'd10: begin
                    case (abslevel)
                        8'd1: begin bitstream <= {8'b0010 0111, sign}; size <= 9; end
                        8'd2: begin bitstream <= {13'b0000 0000 1000 0, sign}; size <= 14; end

                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase
                end
                5'd11: begin
                    case (abslevel)
                        8'd1: begin
                        bitstream <= {8'b0010 0011, sign}; 
                        size <= 9;
                        end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd12: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {8'b0010 0010, sign}; 
                    size <= 9;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd13: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {8'b0010 0000, sign}; 
                    size <= 9;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd14: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {10'b0000 0011 10, sign}; 
                    size <= 11;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd15: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {10'b0000 0011 01, sign}; 
                    size <= 11;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd16: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {10'b0000 0010 00, sign}; 
                    size <= 11;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd17: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {12'b0000 0001 1111, sign}; 
                    size <= 13;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd18: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {12'b0000 0001 1010, sign}; 
                    size <= 13;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd19: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {12'b0000 0001 1001, sign}; 
                    size <= 13;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd20: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {12'b0000 0001 0111, sign}; 
                    size <= 13;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd21: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {12'b0000 0001 0110, sign}; 
                    size <= 13;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd22: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {13'b0000 0000 1111 1, sign}; 
                    size <= 14;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd23: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {13'b0000 0000 1111 0, sign}; 
                    size <= 14;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd24: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {13'b0000 0000 1110 1, sign}; 
                    size <= 14;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd25: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {13'b0000 0000 1110 0, sign}; 
                    size <= 14;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                5'd26: begin
                    case (abslevel)
                        8'd1: begin
                    bitstream <= {13'b0000 0000 1101 1, sign}; 
                    size <= 14;
                    end
                        default: begin
                            bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                        end

                    endcase

                end
                
                // Add more cases for other run values

                default: begin
                    bitstream <= {6'b0000 01, run, level};
                            size <= 20;
                end
            endcase

        end
    end
end

endmodule