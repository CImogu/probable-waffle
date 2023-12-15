// set the timestep on the internal simulation clock
`timescale 1ns / 1ps
`default_nettype none
 
//The timescale specifies the timestep size (1ns) and time resolution of rounding (1ps)
//we'll usually use 1ns/1ps in our class
 
module rtp_tb();
 
  //make inputs and outputs of appropriate size for the module testing:
  logic clk_in;
  logic rst_in;
  logic data_in;
  logic data_valid_in;
  logic prepare_for_data;
  logic [7:0] data_out;
  logic valid_out; 
  logic ready_for_data;
  logic [15:0] payload_size;
  logic [31:0] rtp_timestamp;
  logic [15:0] bit_counter;
  logic marker_in;

  BitwiseRTPModule testing(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .data_in(data_in),
  .data_valid_in(data_valid_in),
  .prepare_for_data(prepare_for_data),
  .data_out(data_out),
  .valid_out(valid_out), 
  .ready_for_data(ready_for_data),
  .bit_counter(bit_counter), 
  .payload_size(payload_size),
  .rtp_timestamp(rtp_timestamp), 
  .rtp_marker_in(marker_in));

  always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
  end

  //Time passes using the # notation. (#10 is 10 nanoseconds)

  initial begin
    $dumpfile("rtp.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,rtp_tb); //store everything at the current level and below
    $display("Starting Sim"); //print nice message

    clk_in = 0; //initialize clk (super important)
    rst_in = 0; //initialize rst (super important) for sel_in
    data_in = 0;
    data_valid_in = 0;
    prepare_for_data = 0;
    
    
 
    #10; //wait 10 ns
    rst_in = 1;
    #10
    rst_in = 0;
    prepare_for_data = 1;
    payload_size = 16;
    rtp_timestamp = 200;
    marker_in = 1;

    #900
    prepare_for_data =0;
    data_valid_in =1;
    data_in = 1;
    #10
    data_in = 0;
    #10
    data_in = 1;
    #10
    data_in = 0;
    #10
    data_in = 1;
    #10
    data_in = 1;
    #10
    data_in = 0;
    #10
    data_in = 1;
    


    //#100;

       #10; //wait 10 ns
    //rst_in = 1;
   // #10
    //rst_in = 0;
   // prepare_for_data = 1;

   // #900
   // prepare_for_data =0;
   // data_valid_in =1;
    data_in = 1;
    #10
    data_in = 1;
    #10
    data_in = 1;
    #10
    data_in = 0;
    #10
    data_in = 1;
    #10
    data_in = 1;
    #10
    data_in = 1;
    #10
    data_in = 1;
    #10
    data_valid_in = 0;


    #100;
 
    $display("\n---------\nFinishing Simulation!");
    $finish; //finish simulation.
  end
endmodule // rtp_tb