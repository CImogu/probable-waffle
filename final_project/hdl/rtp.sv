`timescale 1ns / 1ps
`default_nettype none

module BitwiseRTPModule (
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

//payload is sent in byte, each byte's order represents their player
//byte representation: {0, p movement (3 bits), 0, p shooting (3 bits)}

//add timestamp receiver, marker

localparam UDP_HEADER_SIZE = 64; //8 bytes
localparam IPV4_HEADER_SIZE = 160; // 20 bytes
//localparam FULL_HEADER_SIZE = UDP_HEADER_SIZE + IPV4_HEADER_SIZE;


// States for FSM
logic [1:0] state;
localparam IDLE = 2'b00;
localparam RECEIVE_HEADER = 2'b01;
localparam RECEIVE = 2'b10; //not currently used
localparam SEND_PAYLOAD = 2'b11;
logic [31:0] SSRC = $urandom;

logic [15:0] UDP_PACKET_LENGTH;
logic [15:0] IPV4_PACKET_LENGTH;

// Internal variables
logic [RTP_HEADER_SIZE-1:0] rtp_header;
logic [15:0] rtp_seq;


logic [UDP_HEADER_SIZE-1:0] udp_header;

logic [IPV4_HEADER_SIZE-1:0] ipv4_header;

logic [FULL_HEADER_SIZE-1:0] full_header;
logic [15:0] read_payload_size;
logic [12:0] payload_size_bytes;
logic [3:0] byte_counter;
logic [15:0] indexer;

//logic [20:0] bit_counter; //TODO: make this the right size

always_ff @(posedge clk_in)begin
  if (rst_in)begin
    state <= IDLE;
    valid_out <= 0;
    ready_for_data <= 0;
    rtp_seq <= $urandom;
  end else begin
    case (state)
      IDLE: begin
        if (prepare_for_data) begin
          bit_counter <= 0;
          state <= SEND_HEADER;
          rtp_header <= {2'b10, 1'b0, 1'b0, 4'b0000, rtp_marker_in, 7'h1F, rtp_seq, rtp_timestamp, SSRC};
          read_payload_size <= payload_size;

          udp_header <= {16'b1111111111111111, 16'b1111111111111111, UDP_PACKET_LENGTH, 16'b0};
          ipv4_header <= {4'b0100, 4'b0101, 8'b0, IPV4_PACKET_LENGTH, 3'b010, 13'b0, 8'b00000111, 8'h11, 16'b0, 32'h0a000001, DESTINATION_IP};
        end
      end
      SEND_HEADER: begin
        if (bit_counter < (FULL_HEADER_SIZE-8)) begin
          data_out <= full_header[indexer -: 8];
          bit_counter <= bit_counter + 8;
          valid_out <= 1;
        end else begin
          state <= SEND_PAYLOAD;
          ready_for_data <= 1;
          valid_out <= 0;
          data_out <= 0;
          byte_counter <= 0;
        end
      end
      SEND_PAYLOAD: begin
        if ((bit_counter < FULL_HEADER_SIZE + read_payload_size-8)) begin
          if (data_valid_in) begin
            if (byte_counter >= 7) begin
              byte_counter <= 0;
              valid_out <= 1;
            end else begin
              byte_counter <= byte_counter + 1;
              valid_out <= 0;
            end
            data_out[byte_counter] <= data_in;
            bit_counter <= bit_counter +1;
            //note if wrong size is sent it will be stuck here forever
          end
        end else begin
          state <= IDLE;
          valid_out <= 0;
          ready_for_data <= 0;
          data_out <= 0;
          rtp_seq <= rtp_seq +1;
      end
      end
    endcase

  end
end


always_comb begin 
  full_header = {ipv4_header, udp_header,rtp_header};
  indexer = FULL_HEADER_SIZE-bit_counter-1;
  UDP_PACKET_LENGTH = (UDP_HEADER_SIZE + RTP_HEADER_SIZE + payload_size)>>3;
  IPV4_PACKET_LENGTH = (UDP_HEADER_SIZE + RTP_HEADER_SIZE + IPV4_HEADER_SIZE + payload_size)>>3;

end


endmodule


`default_nettype wire