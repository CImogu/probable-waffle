`timescale 1ns / 1ps
`default_nettype none

// `ifdef SYNTHESIS
`define FPATH(X) `"X`"
// `else /* ! SYNTHESIS */
// `define FPATH(X) `"data/X`"
// `endif  /* ! SYNTHESIS */

module convert_player #(
  parameter PLAYERS = 3
) (
  input wire clk_in,
  input wire valid_in,
  input wire [20:0] location [PLAYERS-1:0],
  output logic valid_out,
  output logic [63:0] float_location [PLAYERS-1:0]
);

logic [PLAYERS-1:0] all_done;

generate
    genvar i;
    for(i=0; i<PLAYERS; i=i+1) begin: convert

        logic [10:0] x_in;
        assign x_in = location[i][20:10];

        logic [31:0] float_x;
        logic fx_ready;
        logic fx_valid;
        fixed2float convertx (
          .aclk(clk_in),
          .s_axis_a_tvalid(valid_in),
          .s_axis_a_tready(fx_ready),
          .s_axis_a_tdata(32'(x_in)),
          .m_axis_result_tvalid(fx_valid),
          .m_axis_result_tready(1'b1),
          .m_axis_result_tdata(float_x)
        );

        logic [9:0] y_in;
        assign y_in = location[i][9:0];

        logic [31:0] float_y;
        logic fy_ready;
        logic fy_valid;

        fixed2float converty (
          .aclk(clk_in),
          .s_axis_a_tvalid(valid_in),
          .s_axis_a_tready(fy_ready),
          .s_axis_a_tdata(32'(y_in)),
          .m_axis_result_tvalid(fy_valid),
          .m_axis_result_tready(1'b1),
          .m_axis_result_tdata(float_y)
        );

        always_ff @( posedge clk_in ) begin
          if (fx_valid && fy_valid) begin
            float_location[i] <= {float_x, float_y};
            all_done[i] <= 1;
          end
        end
    end
endgenerate

always_ff @( posedge clk_in ) begin
  if (valid_in) begin
    all_done <= 0;
  end 
  if (valid_out) begin
    all_done <= 0;
  end
end
assign valid_out = &all_done;

endmodule

/* Given player locations maps them to triangles with floating point vertices in 3D space
*/
module threegen #(
    parameter PLAYERS = 3
) (
    input wire clk_in,
    input wire rst_in,
    input wire valid_in,
    input wire [20:0] obj_location [PLAYERS+PLAYERS-1:0], // {x(11 bits), y(10 bits)} -> get all at once for now
    output logic valid_out,
    output logic [31:0] triangle_x,
    output logic [31:0] triangle_y,
    output logic [31:0] triangle_z,
    output logic [23:0] color,
    output logic t_last_out
);

localparam TRIANGLES = 12; // there are 12 triangles in a cube

logic [3:0] triangle_addr;
logic [287:0] vertices; //A{x-z}, B{x-z}, C{x-z}
typedef enum {A=0, D=1, B=2, C=3, E=4 } state;
state fsm_state;


// Start with single port ram for now
xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(288),                       
    .RAM_DEPTH(TRIANGLES),                     
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
    .INIT_FILE(`FPATH(model.mem))        
) player_BROM (
    .addra(triangle_addr),
    .dina(288'b0),
    .clka(clk_in), // what clock cycle should this run at?
    .wea(1'b0),
    .ena(1'b1),
    .rsta(rst_in),
    .regcea(1'b1),
    .douta(vertices)
  );

logic [287:0] bul_vertices;
xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(288),                       
    .RAM_DEPTH(TRIANGLES),                     
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), 
    .INIT_FILE(`FPATH(bul_model.mem))        
) bullet_BROM (
    .addra(triangle_addr),
    .dina(288'b0),
    .clka(clk_in), // what clock cycle should this run at?
    .wea(1'b0),
    .ena(1'b1),
    .rsta(rst_in),
    .regcea(1'b1),
    .douta(bul_vertices)
  );

logic [63:0] obj [PLAYERS+PLAYERS-1:0];
logic converted;
convert_player #(.PLAYERS(2*PLAYERS)) convert (
  .clk_in(clk_in),
  .valid_in(valid_in),
  .location(obj_location),
  .valid_out(converted),
  .float_location(obj)
);

logic [23:0] color_search;
logic [$clog2(PLAYERS)-1:0] clookup; 
always_comb begin : color_lookups;
  case (clookup)
    0: color_search = 24'hFFFFFF;
    1: color_search = 24'hFF0000;
    2: color_search = 24'h00FF00;
    3: color_search = 24'h0000FF;
    default: color_search = 24'h000000;
  endcase
end

logic [95:0] t_focus [2:0];
logic [$clog2(PLAYERS)-1:0] player_ix; 
logic [63:0] obj_copy [PLAYERS-1:0];

//include two add_many with color and z as user value

logic tr_valid;
logic [31:0] trx_data;
logic [31:0] trx_vx_data;
logic trx_out_valid;
logic tx_last;
adder_many tr_x(
  .aclk(clk_in),
  .s_axis_a_tvalid(tr_valid),
  .s_axis_a_tdata(trx_data),
  .s_axis_a_tuser(32'(color_search)),
  .s_axis_a_tlast(last_out),
  .s_axis_b_tvalid(tr_valid),
  .s_axis_b_tdata(trx_vx_data),
  .m_axis_result_tvalid(trx_out_valid),
  .m_axis_result_tdata(triangle_x),
  .m_axis_result_tuser(color),
  .m_axis_result_tlast(tx_last)
);

logic [31:0] try_data;
logic [31:0] try_vy_data;
logic [31:0] try_vz_data;
logic try_out_valid;
logic ty_last;
adder_many tr_y(
  .aclk(clk_in),
  .s_axis_a_tvalid(tr_valid),
  .s_axis_a_tdata(try_data),
  .s_axis_a_tlast(last_out),
  .s_axis_a_tuser(try_vz_data),
  .s_axis_b_tvalid(tr_valid),
  .s_axis_b_tdata(try_vy_data),
  .m_axis_result_tvalid(try_out_valid),
  .m_axis_result_tdata(triangle_y),
  .m_axis_result_tuser(triangle_z),
  .m_axis_result_tlast(ty_last)
);

assign valid_out = trx_out_valid && try_out_valid;
assign t_last_out = tx_last && ty_last;

logic is_read;
logic [2:0] stage_check; //one bit encoding
logic is_bullet;
logic calculating;
logic last_out;

always_ff @( posedge clk_in ) begin
  if (rst_in) begin
    fsm_state <= A;
    triangle_addr <= 0;
  end else begin
    case (fsm_state)
      A: begin
        if (last_out) begin
          last_out <= 0;
        end

        if (is_bullet) begin
          player_ix <= 0;
          fsm_state <= D;
        end else if (converted) begin
          player_ix <= 0;
          fsm_state <= D;
          is_bullet <= 0;
          calculating <= 1;
        end else if (calculating) begin
          fsm_state <= D;
        end
        
      end

      D: begin // updating t_focus
        if (!is_read) begin
          is_read = 1;
        end else begin
          if (!is_bullet) begin
            t_focus[0] <= vertices[287:193];
            t_focus[1] <= vertices[192:96];
            t_focus[2] <= vertices[95:0];
            for (integer i = 0; i < PLAYERS ; i = i+1) begin
              obj_copy[i] <= obj[i];
            end

          end else begin // need to make sure obj does not change in-between calculations
            t_focus[0] <= bul_vertices[287:193];
            t_focus[1] <= bul_vertices[192:96];
            t_focus[2] <= bul_vertices[95:0];
            for (integer i = 0; i < PLAYERS ; i = i+1) begin
              obj_copy[i] <= obj[i+PLAYERS];
            end
          end

          is_read <= 0;
          fsm_state <= B;
          stage_check <= 'b100;

        end
      end

      B: begin // start up adder for each player

        // calculate x, y, z values of one of stored triangles
        trx_vx_data <= t_focus[0][95:64];
        try_vy_data <= t_focus[0][63:32];
        try_vz_data <= t_focus[0][31:0];

        // get player-ix's position
        trx_data <= obj_copy[0][63:32];
        try_data <= obj_copy[0][31:0];

        // get color
        clookup <= player_ix;

        if (player_ix == (PLAYERS - 1)) begin
          fsm_state <= C;
          tr_valid <= 0;

        end else begin
          for (integer i = 0; i < (PLAYERS-1) ; i = i+1) begin
            obj_copy[i] <= obj_copy[i+1];
          end
          player_ix <= player_ix + 1;
          tr_valid <= 1;
        end
      end
      
      C: begin // grab next vertex
        t_focus[0] <= t_focus[1];
        t_focus[1] <= t_focus[2];

        // halt additions and move to next stage
        tr_valid <= 0;
        stage_check <= stage_check >> 1; 

        if (stage_check == 1) begin // done adding all vertices in current triangle
          fsm_state <= E;
        end else begin
          fsm_state <= B;
        end
        player_ix <= 0;
      end

      E: begin // grab next triangle
        if (triangle_addr == (TRIANGLES-1)) begin
          last_out <= is_bullet;
          if (is_bullet) begin
            calculating <= 0;
          end
          is_bullet <= !is_bullet;
          triangle_addr <= 0;
        end else begin
          triangle_addr <= triangle_addr + 1;
        end
        fsm_state <= A;
      end

    endcase
  end
  
end    
endmodule // threegen

module threegen_wrap2 (
    input wire clk_in,
    input wire rst_in,
    input wire valid_in,
    input wire [20:0] player1, // {x(11 bits), y(10 bits)} -> get all at once for now
    input wire [20:0] player2,
    input wire [20:0] bullet1,
    input wire [20:0] bullet2, 
    output logic valid_out,
    output logic [31:0] triangle_x,
    output logic [31:0] triangle_y,
    output logic [31:0] triangle_z,
    output logic [23:0] color,
    output logic last_out
);
logic [20:0] obj_location [3:0];
always_comb begin
  obj_location[0] = player1;
  obj_location[1] = player2;
  obj_location[2] = bullet1;
  obj_location[3] = bullet2;
end

threegen #(.PLAYERS(2)
) triangle_gen(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .valid_in(valid_in),
    .obj_location(obj_location),
    .valid_out(valid_out),
    .triangle_x(triangle_x),
    .triangle_y(triangle_y),
    .triangle_z(triangle_z),
    .color(color),
    .t_last_out(last_out)
);
endmodule //threegen_wrap2

`default_nettype none