`timescale 1ns / 1ps
`default_nettype none

/* Decodes ethernet UDP bit stream and returns connected players actions
*/
module decoder (
    input wire clk_in,
    input wire rst_in,
    input wire data_in,
    output logic [31:0] info_out
);

typedef enum {IDLE=0, HEADER=1, DATA=2, VALID=3, LOOKUP=4} state;
state fsm_state;
logic [15:0] buffer;
logic [3:0] next_index;
logic [2:0] header_section;

logic valid_in; // is there a valid_in signal of some sort? How to know when to start recording?

// how to create an array with variable length, depending on input and not the parameter
// maybe just used fix length and then overwrite when done? 

always_ff @(posedge clk_in ) begin
    if (rst_in) begin
        fsm_state <= IDLE;
    end else begin
        case (fsm_state)
            IDLE: begin
                if (valid_in) begin
                    fsm_state <= HEADER;
                    next_index <= 0;
                    header_section <= 0;
                end 
            end

            HEADER: begin
                for (integer i = 0; i < 15; i = i+1) begin
                    buffer[i+1] <= buffer[i];
                end
                buffer[0] <= data_in;
                next_index <= next_index + 1;
                if (next_index == 4'b1111) begin
                    header_section <= header_section + 1;
                end
            end 

            default: 
        endcase
    end

end
endmodule // decoder

`default_nettype wire