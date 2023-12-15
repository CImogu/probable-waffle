// set the timestep on the internal simulation clock
`timescale 1ns / 1ps
`default_nettype none
 
//The timescale specifies the timestep size (1ns) and time resolution of rounding (1ps)
//we'll usually use 1ns/1ps in our class
 
module rtp_tb();
  
  //make inputs and outputs of appropriate size for the module testing:
  logic clk;
  logic rst;
  logic eth_txen;
  logic [1:0] eth_txd;
  logic block_output_valid;

  logic waiting_rtp;
  logic rtp_sending;
  logic [15:0] rtp_send_count;
  always_ff @(posedge clk) begin
      if (rst) begin
          encoder_out_valid <= 0;
          rtp_prepare_for_data <= 0;
          waiting_rtp <= 0;
          rtp_sending <= 0;
          rtp_send_count <= 0;
      end else begin
          if (rtp_sending) begin
              encoder_out_valid <= 1;
              rtp_send_count <= rtp_send_count + 1;
              if (rtp_send_count == rtp_payload_size - 1) begin
                  rtp_send_count <= 0;
                  rtp_sending <= 0;
              end
          end else begin
            encoder_out_valid <= 0;
            if (waiting_rtp) begin
                if (rtp_ready_for_data) begin
                    rtp_sending <= 1;
                    waiting_rtp <= 0;
                end
                rtp_prepare_for_data <= 0;
            end else if (~eth_busy && block_output_valid) begin
                rtp_prepare_for_data <= 1;
                waiting_rtp <= 1;
            end
          end
      end
  end

  logic encoder_out = 1'b1;
  logic encoder_out_valid;
  logic encoder_marker;
  logic [31:0] encoder_timestamp = $urandom;
  logic [15:0] rtp_payload_size = 64 << 3;
  logic rtp_data_valid;

  logic rtp_ready_for_data;
  logic rtp_prepare_for_data;
  BitwiseRTPModule rtp_sender (
      .clk_in(clk),
      .rst_in(rst),
      .data_in(encoder_out),
      .data_valid_in(encoder_out_valid),
      .prepare_for_data(rtp_prepare_for_data),
      .payload_size(rtp_payload_size),
      .rtp_timestamp(encoder_timestamp),
      .rtp_marker_in(encoder_marker),
      .data_out(eth_data),
      .valid_out(eth_data_valid),
      .ready_for_data(rtp_ready_for_data),
      .send_out(eth_send_data)
  );


  logic eth_refclk;


  logic [7:0] eth_data;
  logic eth_data_valid;
  logic eth_send_data;
  logic eth_busy;
  //logic [10:0] eth_data_count;
  //logic eth_sending;

  localparam MAC_DEST = 48'hff_ff_ff_ff_ff_ff;
  logic [3:0] eth_debug_state;
  /*
  assign ja[0] = eth_rxd[0];
  assign ja[1] = eth_rxd[1];*/
  mac_transmit mac_transmitter (
      .rst(rst),
      .clk_100mhz(clk),
      .eth_refclk(eth_refclk),
      .eth_txen(eth_txen),
      .eth_txd(eth_txd),
      .send_data(eth_send_data), // when asserted, sends the data
      .data_in(eth_data),
      .data_valid_in(eth_data_valid),
      .mac_dest(MAC_DEST),
      .busy(eth_busy),
      .debug_state(eth_debug_state)
  );


  always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk = !clk;
  end

  always begin
      #10;
      eth_refclk = !eth_refclk;
  end

  //Time passes using the # notation. (#10 is 10 nanoseconds)

  initial begin
    $dumpfile("rtp.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,rtp_tb); //store everything at the current level and below
    $display("Starting Sim"); //print nice message

    eth_refclk = 0;
    clk = 0; //initialize clk (super important)
    rst = 0; //initialize rst (super important) for sel_in
 
    #10; //wait 10 ns
    rst = 1;
    #10
    rst = 0;
    encoder_timestamp = 200;
    encoder_marker = 1;

    #900

    for (int i = 0; i < 10; i = i + 1) begin
      block_output_valid <= 1;
      #10 
      block_output_valid <= 0;

      #100000;
    end
 
    $display("\n---------\nFinishing Simulation!");
    $finish; //finish simulation.
  end
endmodule // rtp_tb