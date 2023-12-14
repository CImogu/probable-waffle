module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );


  logic [$clog2(8):0] sum_of_digits;
  
  assign sum_of_digits = data_in[0] + data_in[1] + data_in[2] + data_in[3] + data_in[4] + data_in[5] + data_in[6] + data_in[7];

  always_comb begin 
    if ( (sum_of_digits > 4) || ( (sum_of_digits == 4) && (data_in[0] == 0) ) ) begin //option 2
      qm_out[8] = 0;
      qm_out[0] = data_in[0];
      qm_out[1] = ~(~data_in[1] == qm_out[0]);
      qm_out[2] = ~(~data_in[2] == qm_out[1]);
      qm_out[3] = ~(~data_in[3] == qm_out[2]);
      qm_out[4] = ~(~data_in[4] == qm_out[3]);
      qm_out[5] = ~(~data_in[5] == qm_out[4]);
      qm_out[6] = ~(~data_in[6] == qm_out[5]);
      qm_out[7] = ~(~data_in[7] == qm_out[6]);
      
    end else begin //option 1
      qm_out[8] = 1;
      qm_out[0] = data_in[0];
      qm_out[1] = (~data_in[1] == qm_out[0]);
      qm_out[2] = (~data_in[2] == qm_out[1]);
      qm_out[3] = (~data_in[3] == qm_out[2]);
      qm_out[4] = (~data_in[4] == qm_out[3]);
      qm_out[5] = (~data_in[5] == qm_out[4]);
      qm_out[6] = (~data_in[6] == qm_out[5]);
      qm_out[7] = (~data_in[7] == qm_out[6]);
      
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
  logic [4:0] tally;
  //you can assume a functioning (version of tm_choice for you.)
  tm_choice mtm(
    .data_in(data_in),
    .qm_out(q_m));

  //your code here.
  logic [$clog2(10):0] q_m_sum;
  assign q_m_sum = q_m[0] + q_m[1] + q_m[2] + q_m[3] + q_m[4] + q_m[5] + q_m[6] + q_m[7];


always_ff @(posedge clk_in) begin

        if (rst_in) begin
            tmds_out <= 0;
            tally <= 0;
        end else begin
            if (ve_in) begin
                if ( (tally == 0) || (q_m_sum == 4)) begin //triangle 1 true
             
                    tmds_out[9] <= !q_m[8];
                    tmds_out[8] <= q_m[8];
                    //tmds_out[7:0] <= (q_m[8])? q_m[7:0]: (~q_m[7:0]);
                    if (q_m[8]) begin
                        tmds_out[7:0] <= q_m[7:0];
                    end else begin
                        tmds_out[7:0] <= ~q_m[7:0];
                    end

                    if (q_m[8] == 0) begin //triangle 2 true
                        tally <= tally + 8 - q_m_sum - q_m_sum; 
                    end else begin //triangle 2 false
                        tally <= tally + q_m_sum - (8- q_m_sum);
                    end 
                  

                end else begin //triangle 1 false
       
                    if ( ((tally[4] == 0) && (q_m_sum > 4)) || ((tally[4] == 1) && (q_m_sum < 4))) begin //triangle 3 true
                        tmds_out[9] <= 1;
                        tmds_out[8] <= q_m[8];
                        tmds_out[7:0] <= ~q_m[7:0];
                        tally <= tally + q_m[8] + q_m[8] + (8 - q_m_sum) - q_m_sum;
                      
                    end else begin //triangle 3 false
                        tmds_out[9] <= 0;
                        tmds_out[8] <= q_m[8];
                        tmds_out[7:0] <= q_m[7:0];
                        tally <= tally - !q_m[8] - !q_m[8] + q_m_sum + q_m_sum - 8;
                    end

                end 
            end else begin
                tally <= 0;
                if (control_in == 2'b00) begin
                    tmds_out <= 10'b1101010100;
                end else if (control_in == 2'b01) begin
                    tmds_out <= 10'b0010101011;
                end else if (control_in == 2'b10) begin
                    tmds_out <= 10'b0101010100;
                end else if (control_in == 2'b11) begin
                    tmds_out <= 10'b1010101011;
                end
            end
        end
end

endmodule //end tmds_encoder
