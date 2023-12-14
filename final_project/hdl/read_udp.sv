`timescale 1ns / 1ps
`default_nettype none

module ReceiveUDPModule (
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,
  input wire data_valid_in,
  output reg [2:0] p1_movement, //5 values needed / 3 bits
  output reg [2:0] p1_shooting,
  output reg [2:0] p2_movement,
  output reg [2:0] p2_shooting,
  output reg [2:0] p3_movement,
  output reg [2:0] p3_shooting,
  output reg [2:0] p4_movement,
  output reg [2:0] p4_shooting,
  output reg valid_out);

  //payload bytes will represent a player based on its location in the order
  //byte format: {0, p movement (3 bits), 0, p shooting (3 bits)}

localparam UDP_HEADER_SIZE = 64; //8 bytes
localparam IPV4_HEADER_SIZE = 160; // 20 bytes
localparam FULL_HEADER_SIZE = UDP_HEADER_SIZE + IPV4_HEADER_SIZE;

//send a out bytes but receive bits

// States for FSM
logic [1:0] state;
localparam RECEIVE_IP_HEADER = 2'b00;
localparam RECEIVE_UDP_HEADER = 2'b01;
localparam RECEIVE_PAYLOAD = 2'b11;

logic [1:0] player;
localparam P1 = 2'b00;
localparam P2 = 2'b01;
localparam P3 = 2'b10;
localparam P4 = 2'b11;

// Internal variables
logic [UDP_HEADER_SIZE-1:0] udp_header;
logic [IPV4_HEADER_SIZE-1:0] ipv4_header;

logic [15:0] bit_counter;

always_ff @(posedge clk_in)begin
  if (rst_in)begin
    state <= RECEIVE_IP_HEADER;
    valid_out <= 0;
    bit_counter <= 0;
    p1_movement <= 0;
    p1_shooting <= 0;
    p2_movement <= 0;
    p2_shooting <= 0;
    p3_movement <= 0;
    p3_shooting <= 0;
    p4_movement <= 0;
    p4_shooting <= 0;
  end else begin
    case (state)
      RECEIVE_IP_HEADER: begin
        if (data_valid_in) begin
          if (bit_counter < (IPV4_HEADER_SIZE-8)) begin
            bit_counter <= bit_counter + 8;
          end else begin
            bit_counter <= 0;
            state <= RECEIVE_UDP_HEADER;
          end

          ipv4_header[(IPV4_HEADER_SIZE-bit_counter-1) -: 8] <= data_in;
        end
        valid_out <= 0;
      end
      RECEIVE_UDP_HEADER: begin
        if (data_valid_in) begin
          if (bit_counter < (UDP_HEADER_SIZE-8)) begin
            bit_counter <= bit_counter + 8;
          end else begin
            bit_counter <= 0;
            state <= RECEIVE_PAYLOAD;
            player <= P1;
          end

          udp_header[(UDP_HEADER_SIZE-bit_counter-1) -: 8] <= data_in;
        end
      end
      RECEIVE_PAYLOAD: begin
        if (data_valid_in) begin
          case (player)
            P1: begin
              p1_movement <= data_in[6:4];
              p1_shooting <= data_in[2:0];
              player <= P2;
            end
            P2: begin
              p2_movement <= data_in[6:4];
              p2_shooting <= data_in[2:0];
              player <= P3;
            end
            P3: begin
              p3_movement <= data_in[6:4];
              p3_shooting <= data_in[2:0];
              player <= P4;
            end
            P4: begin
              p4_movement <= data_in[6:4];
              p4_shooting <= data_in[2:0];
              state <= RECEIVE_IP_HEADER;
              valid_out <= 1;
            end

          endcase
        end
      end
    endcase

  end
end


//always_comb begin 
  
//end


endmodule


`default_nettype wire