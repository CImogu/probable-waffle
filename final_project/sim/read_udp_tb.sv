// set the timestep on the internal simulation clock
`timescale 1ns / 1ps
`default_nettype none
 
//The timescale specifies the timestep size (1ns) and time resolution of rounding (1ps)
//we'll usually use 1ns/1ps in our class
 
module read_udp_tb();
 
  //make inputs and outputs of appropriate size for the module testing:
  logic clk_in;
  logic rst_in;
  logic [7:0] data_in;
  logic data_valid_in;
  logic [2:0] p1_movement; //5 values needed / 3 bits
  logic [2:0] p1_shooting;
  logic [2:0] p2_movement;
  logic [2:0] p2_shooting;
  logic [2:0] p3_movement;
  logic [2:0] p3_shooting;
  logic [2:0] p4_movement;
  logic [2:0] p4_shooting;
  logic valid_out;

  ReceiveUDPModule testing(
  .clk_in(clk_in),
  .rst_in(rst_in),
  .data_in(data_in),
  .data_valid_in(data_valid_in),
  .p1_movement(p1_movement), 
  .p1_shooting(p1_shooting),
  .p2_movement(p2_movement), 
  .p2_shooting(p2_shooting),
  .p3_movement(p3_movement), 
  .p3_shooting(p3_shooting),
  .p4_movement(p4_movement), 
  .p4_shooting(p4_shooting),
  .valid_out(valid_out));

  always begin
        #5;  //every 5 ns switch...so period of clock is 10 ns...100 MHz clock
        clk_in = !clk_in;
  end

  //Time passes using the # notation. (#10 is 10 nanoseconds)

  initial begin
    $dumpfile("udp.vcd"); //file to store value change dump (vcd)
    $dumpvars(0,read_udp_tb); //store everything at the current level and below
    $display("Starting Sim"); //print nice message

    clk_in = 0; //initialize clk (super important)
    rst_in = 0; //initialize rst (super important) for sel_in
    data_in = 0;
    data_valid_in = 0;
    
    
 
    #10; //wait 10 ns
    rst_in = 1;
    #10
    rst_in = 0;
    #10

data_valid_in = 1;
          data_in = 8'b11111111;
          #10

        for (int i = 0; i<18; i= i+1)begin
          data_in = 0;
          #10;
        end

        data_in = 8'b11111111;

        #10
        data_valid_in = 0;

        #10

data_valid_in = 1;
          data_in = 8'b11111110;
          #10

        for (int i = 0; i<6; i= i+1)begin
          data_in = 0;
          #10;
        end

        data_in = 8'b111111110;

        #10

        data_in = 8'b11010101;
        #10
        data_in = 8'b01110111;
        #10
        data_in = 8'b10101010;
        #10
        data_in = 8'b00000001;
        #10
     

     //restart again

data_valid_in = 1;
          data_in = 8'b11111111;
          #10

        for (int i = 0; i<18; i= i+1)begin
          data_in = 0;
          #10;
        end

        data_in = 8'b11111111;

        #10
        data_valid_in = 0;

        #10

data_valid_in = 1;
          data_in = 8'b11111111;
          #10

        for (int i = 0; i<6; i= i+1)begin
          data_in = 0;
          #10;
        end

        data_in = 8'b10110011;

        #10

        data_in = 8'b11010111;
        #10
        data_in = 8'b01110101;
        #10
        data_in = 8'b10101011;
        #10
        data_in = 8'b00000011;
        #10
        data_valid_in = 0;
      

    #100;
 
    $display("\n---------\nFinishing Simulation!");
    $finish; //finish simulation.
  end
endmodule // rtp_tb