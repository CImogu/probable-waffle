`timescale 1ns / 1ps
`default_nettype none

module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );

  //your code here, friend
  logic [3:0] n_1;
  logic [3:0] n_0;
  
  always_comb begin
    n_1 = data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7];
    n_0 = 'd8 - n_1;
    if ((n_1 > 'd4) || ((n_1 == 'd4) && !data_in[0])) begin
        qm_out[0] = data_in[0];
        for(integer i=1; i < 8; i = i+1) begin
          qm_out[i] = qm_out[i-1] ~^ data_in[i];
        end
      qm_out[8] = 0;
    end else begin
        qm_out[0] = data_in[0];
        for(integer i=1; i < 8; i = i+1) begin
            qm_out[i] = qm_out[i-1] ^ data_in[i];
        end
      qm_out[8] = 1;
    end
  end
endmodule //end tm_choice


module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,  // video data (red, green or blue)
  input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
  input wire ve_in,  // video data enable, to choose between control or video signal
  output logic [9:0] tmds_out
);

  logic [8:0] q_m;
  //you can assume a functioning (version of tm_choice for you.)
  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m));

  //your code here.
  logic[4:0] tally;
  logic [3:0] n_1;
  logic [3:0] n_0;

  always_comb begin
    n_1 = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7];
    n_0 = 'd8 - n_1;
  end

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
        tally <= 0;
        tmds_out <= 0;

    end else if (ve_in) begin
       if ((tally == 0)|| (n_1 == n_0)) begin
        tmds_out[9] <= ~q_m[8];
        tmds_out[8] <= q_m[8];
        tmds_out[7:0] <= (q_m[8]) ? q_m[7:0] : ~q_m[7:0];

        if (!q_m[8]) begin
            tally <= tally + (n_0 - n_1);
        end else begin
            tally <= tally + (n_1 - n_0);
        end

       end else begin

        if ((!tally[4] && (n_1 > n_0)) || (tally[4] && (n_0 > n_1))) begin
            tmds_out[9] <= 1;
            tmds_out[8] <= q_m[8];
            for (integer i = 0; i < 8; i = i+1) begin
                tmds_out[i] <= !q_m[i];
            end
            if (q_m[8]) begin
                tally <= tally + 2'b10 + (n_0 - n_1);
            end else begin
                tally <= tally + (n_0 - n_1);
            end

        end else begin
            tmds_out[9] <= 0;
            tmds_out[8:0] <= q_m;
            if (!q_m[8]) begin
                tally <= tally - 2'b10 + (n_1 - n_0);
            end else begin
                tally <= tally + (n_1 - n_0);
            end
        end
       end

    end else begin
        tally <= 0;
        case (control_in)
            2'b00: tmds_out <= 10'b1101010100;
            2'b01: tmds_out <= 10'b0010101011;
            2'b10: tmds_out <= 10'b0101010100;
            2'b11: tmds_out <= 10'b1010101011;
        endcase
    end
  end

endmodule //end tmds_encoder
`default_nettype wire