module block_sprite #(
  parameter WIDTH=70, HEIGHT=70, COLOR=24'hFF_FF_FF)(
  input wire [10:0] hcount_in,
  input wire [9:0] vcount_in,
  input wire [10:0] x_in,
  input wire [9:0]  y_in,
  output logic [7:0] red_out,
  output logic [7:0] green_out,
  output logic [7:0] blue_out);

  logic in_sprite;
  assign in_sprite = ((hcount_in >= x_in && hcount_in < (x_in + WIDTH)) &&
                      (vcount_in >= y_in && vcount_in < (y_in + HEIGHT)));
  always_comb begin
    if (in_sprite)begin
      red_out = COLOR[23:16];
      green_out = COLOR[15:8];
      blue_out = COLOR[7:0];
    end else begin
      red_out = 0;
      green_out = 0;
      blue_out = 0;
    end
  end
endmodule

module move_boxes (
  input wire clk_in, //
  input wire rst_in,
  input wire nf_in,
  input wire [2:0] b_con_in,
  input wire [2:0] c_con_in,
  input wire [2:0] d_con_in,
  input wire [1:0] dead,
  output logic [10:0] box_x,
  output logic [9:0] box_y,
  output logic [10:0] c_box_x,
  output logic [9:0] c_box_y, 
  output logic [10:0] d_box_x,
  output logic [9:0] d_box_y
  );
  localparam BOX_DIM = 90;
  localparam MOVE_AMT = 5; //amount to move per frame

  localparam RIGHT = 1;
  localparam LEFT = 2; 
  localparam UP = 3;
  localparam DOWN = 4;

  always_ff @(posedge clk_in) begin

        if (rst_in) begin
            box_x <= 500;
            box_y <= 500;
            c_box_x <= 100;
            c_box_y <= 100;
            d_box_x <= 1000;
            d_box_y <= 100;

        end else if (nf_in) begin
          if (dead != 0) begin
            box_x <= 500;
            box_y <= 500;
            c_box_x <= 100;
            c_box_y <= 100;
            d_box_x <= 1000;
            d_box_y <= 100;
          end else begin

            if ((b_con_in == RIGHT) && ((box_x+BOX_DIM) < 1280) ) begin //move right
                box_x <= box_x + MOVE_AMT;
            end else if ((b_con_in == LEFT) && (box_x > 0 ) ) begin //move left
                box_x <= box_x - MOVE_AMT;
            end 
            if ((b_con_in == DOWN) && ((box_y+BOX_DIM) < 720) ) begin //move down
                box_y <= box_y + MOVE_AMT;
            end else if ((b_con_in == UP) && ((box_y) > 0) ) begin //move down
                box_y <= box_y - MOVE_AMT;
            end

            if ((c_con_in == RIGHT) && ((c_box_x+BOX_DIM) < 1280) ) begin //move right
                c_box_x <= c_box_x + MOVE_AMT;
            end else if ((c_con_in == LEFT) && ((c_box_x) > 0) ) begin //move left
                c_box_x <= c_box_x - MOVE_AMT;
            end 
            if ((c_con_in == DOWN) && ((c_box_y+BOX_DIM) < 720) ) begin //move down
                c_box_y <= c_box_y + MOVE_AMT;
            end else if ((c_con_in == UP) && ((c_box_y) > 0) ) begin //move up
                c_box_y <= c_box_y - MOVE_AMT;
            end

            if ((d_con_in == RIGHT) && ((d_box_x+BOX_DIM) < 1280) ) begin //move right
                d_box_x <= d_box_x + MOVE_AMT;
            end else if ((d_con_in == LEFT) && ((d_box_x) > 0) ) begin //move left
                d_box_x <= d_box_x - MOVE_AMT;
            end 
            if ((d_con_in == DOWN) && ((d_box_y+BOX_DIM) < 720) ) begin //move down
                d_box_y <= d_box_y + MOVE_AMT;
            end else if ((d_con_in == UP) && ((d_box_y) > 0) ) begin //move up
                d_box_y <= d_box_y - MOVE_AMT;
            end
            
          end
        end
  end

endmodule

module shape_party(
  input wire clk_in, //
  input wire rst_in,
  input wire [10:0] hcount_in,
  input wire [9:0] vcount_in,
  input wire nf_in,
  input wire [2:0] b_con_in,
  input wire [2:0] c_con_in,
  input wire [2:0] d_con_in,
  input wire [2:0] b_bullet_in,
  input wire [2:0] c_bullet_in,
  input wire [2:0] d_bullet_in,
  output logic [10:0] box_x,
  output logic [9:0] box_y,
  output logic [10:0] c_box_x,
  output logic [9:0] c_box_y, 
  output logic [10:0] d_box_x,
  output logic [9:0] d_box_y, 
  output logic [10:0] b_bullet_x,
  output logic [9:0] b_bullet_y,
  output logic [10:0] c_bullet_x,
  output logic [9:0] c_bullet_y, 
  output logic [10:0] d_bullet_x,
  output logic [9:0] d_bullet_y,
  output logic [1:0] dead,
  output logic [7:0] red_out, //COLOR STUFF (delete)
  output logic [7:0] green_out,
  output logic [7:0] blue_out

  );
  localparam BOX_DIM = 90;
  localparam BULLET_DIM = 5;
 
  logic [7:0] box_r, box_g, box_b;  //COLOR STUFF (delete)
  logic [7:0] circle_r, circle_g, circle_b;
  logic [7:0] d_box_r, d_box_g, d_box_b;


  logic [7:0] b_bullet_r, b_bullet_g, b_bullet_b;
  logic [7:0] c_bullet_r, c_bullet_g, c_bullet_b;
  logic [7:0] d_bullet_r, d_bullet_g, d_bullet_b;


 move_boxes moving(
  .clk_in(clk_in), //
  .rst_in(rst_in),
  .nf_in(nf_in),
  .b_con_in(b_con_in),
  .c_con_in(c_con_in),
  .d_con_in(d_con_in),
  .dead(dead),
  .box_x(box_x),
  .box_y(box_y),
  .c_box_x(c_box_x),
  .c_box_y(c_box_y), 
  .d_box_x(d_box_x),
  .d_box_y(d_box_y)
  );

  bullet_master controllingbullets(
    .clk_in(clk_in), //
    .rst_in(rst_in),
    .nf_in(nf_in),
    .b_bullet_in(b_bullet_in),
    .c_bullet_in(c_bullet_in),
    .d_bullet_in(d_bullet_in),
    .box_x(box_x),
    .box_y(box_y),
    .c_box_x(c_box_x),
    .c_box_y(c_box_y),
    .b_bullet_x(b_bullet_x),
    .b_bullet_y(b_bullet_y),
    .c_bullet_x(c_bullet_x),
    .c_bullet_y(c_bullet_y), 
    .d_box_x(d_box_x),
    .d_box_y(d_box_y),
    .d_bullet_x(d_bullet_x),
    .d_bullet_y(d_bullet_y),
    .dead(dead)
  );
 

 //COLOR STUFF LOGIC BELOW (NOT NEEDED FOR PROJECT) (DELETE ALL)
  block_sprite #(
  .WIDTH(BOX_DIM), .HEIGHT(BOX_DIM),.COLOR(24'hFF_7F_00))
  bs(
    .hcount_in(hcount_in),
    .vcount_in(vcount_in),
    .x_in(box_x),
    .y_in(box_y),
    .red_out(box_r),
    .green_out(box_g),
    .blue_out(box_b));

  block_sprite #(
  .WIDTH(BOX_DIM), .HEIGHT(BOX_DIM),.COLOR(24'hFF_FF_FF))
  bs2(
    .hcount_in(hcount_in),
    .vcount_in(vcount_in),
    .x_in(c_box_x),
    .y_in(c_box_y),
    .red_out(circle_r),
    .green_out(circle_g),
    .blue_out(circle_b));

  block_sprite #(
  .WIDTH(BOX_DIM), .HEIGHT(BOX_DIM),.COLOR(24'hFF_00_FF))
  bs3(
    .hcount_in(hcount_in),
    .vcount_in(vcount_in),
    .x_in(d_box_x),
    .y_in(d_box_y),
    .red_out(d_box_r),
    .green_out(d_box_g),
    .blue_out(d_box_b));

  block_sprite #(
  .WIDTH(BULLET_DIM), .HEIGHT(BULLET_DIM),.COLOR(24'hFF_FF_FF))
  bullet_1(
    .hcount_in(hcount_in),
    .vcount_in(vcount_in),
    .x_in(b_bullet_x),
    .y_in(b_bullet_y),
    .red_out(b_bullet_r),
    .green_out(b_bullet_g),
    .blue_out(b_bullet_b));

  block_sprite #(
  .WIDTH(BULLET_DIM), .HEIGHT(BULLET_DIM),.COLOR(24'hFF_7F_00))
  bullet_2(
    .hcount_in(hcount_in),
    .vcount_in(vcount_in),
    .x_in(c_bullet_x),
    .y_in(c_bullet_y),
    .red_out(c_bullet_r),
    .green_out(c_bullet_g),
    .blue_out(c_bullet_b));

  block_sprite #(
  .WIDTH(BULLET_DIM), .HEIGHT(BULLET_DIM),.COLOR(24'hFF_00_00))
  bullet_3(
    .hcount_in(hcount_in),
    .vcount_in(vcount_in),
    .x_in(d_bullet_x),
    .y_in(d_bullet_y),
    .red_out(d_bullet_r),
    .green_out(d_bullet_g),
    .blue_out(d_bullet_b));

  //Instructions:
  /*
    parameter ACTIVE_H_PIXELS = 1280,
  parameter H_FRONT_PORCH = 110,
  parameter H_SYNC_WIDTH = 40,
  parameter H_BACK_PORCH = 220,
  parameter ACTIVE_LINES = 720,
  Create two sprites:
  * One rectangle with H and W 128 pixels
  * One circle with radius of 64 pixels
  * The two sprites should be able to move around the screen
    using four bits of input directions.  How you use them is up to you.
  * The sprites should not be able to move off the edge of the screen.
  * The sprites are allowed to collide/overlap. How you handle that is up
    to you.
  */
  //your code here.

  assign red_out = box_r + circle_r + d_box_r + b_bullet_r + c_bullet_r + d_bullet_r;
  assign blue_out = box_b + circle_b + d_box_b + b_bullet_b + c_bullet_b + d_bullet_b;
  assign green_out = box_g + circle_g + d_box_g + b_bullet_g + c_bullet_g + d_bullet_g;

endmodule //shape_party