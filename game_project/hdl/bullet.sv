
module move_bullet (
  input wire clk_in, //
  input wire rst_in,
  input wire nf_in,
  input wire [2:0] b_bullet_in,
  input wire [2:0] c_bullet_in,
  input wire [2:0] d_bullet_in,
  input wire [10:0] box_x,
  input wire [9:0] box_y,
  input wire [10:0] c_box_x,
  input wire [9:0] c_box_y,
  output logic [10:0] d_box_x,
  output logic [9:0] d_box_y,
  output logic [10:0] b_bullet_x,
  output logic [9:0] b_bullet_y,
  output logic [10:0] c_bullet_x,
  output logic [9:0] c_bullet_y, 
  output logic [10:0] d_bullet_x,
  output logic [9:0] d_bullet_y

  );
  localparam BOX_DIM = 90;
  localparam MOVE_AMT = 15; //amount to move per 
  
  localparam NEUTRAL = 0;
  localparam RIGHT = 1;
  localparam LEFT = 2; 
  localparam UP = 3;
  localparam DOWN = 4;

  always_ff @(posedge clk_in) begin

        if (rst_in) begin

        end else if (nf_in) begin
          case (b_bullet_in)
            NEUTRAL: begin
              b_bullet_x <= box_x + (BOX_DIM/2);
              b_bullet_y <= box_y + (BOX_DIM/2);
            end
            RIGHT: begin
              b_bullet_x <= b_bullet_x + MOVE_AMT;
            end 
            LEFT: begin
              b_bullet_x <= b_bullet_x - MOVE_AMT;
            end 
            UP: begin
              b_bullet_y <= b_bullet_y - MOVE_AMT;
            end 
            DOWN: begin
              b_bullet_y <= b_bullet_y + MOVE_AMT;
            end

          endcase

          case (c_bullet_in)
            NEUTRAL: begin
              c_bullet_x <= c_box_x + (BOX_DIM/2);
              c_bullet_y <= c_box_y + (BOX_DIM/2);
            end
            RIGHT: begin
              c_bullet_x <= c_bullet_x + MOVE_AMT;
            end 
            LEFT: begin
              c_bullet_x <= c_bullet_x - MOVE_AMT;
            end 
            UP: begin
              c_bullet_y <= c_bullet_y - MOVE_AMT;
            end 
            DOWN: begin
              c_bullet_y <= c_bullet_y + MOVE_AMT;
            end
          endcase

          case (d_bullet_in)
            NEUTRAL: begin
              d_bullet_x <= d_box_x + (BOX_DIM/2);
              d_bullet_y <= d_box_y + (BOX_DIM/2);
            end
            RIGHT: begin
              d_bullet_x <= d_bullet_x + MOVE_AMT;
            end 
            LEFT: begin
              d_bullet_x <= d_bullet_x - MOVE_AMT;
            end 
            UP: begin
              d_bullet_y <= d_bullet_y - MOVE_AMT;
            end 
            DOWN: begin
              d_bullet_y <= d_bullet_y + MOVE_AMT;
            end
          endcase

        end
  end

endmodule

module bullet_master(
  input wire clk_in, //
  input wire rst_in,
  input wire nf_in,
  input wire [2:0] b_bullet_in,
  input wire [2:0] c_bullet_in,
  input wire [10:0] box_x,
  input wire [9:0] box_y,
  input wire [10:0] c_box_x,
  input wire [9:0] c_box_y,
  output logic [10:0] b_bullet_x,
  output logic [9:0] b_bullet_y,
  output logic [10:0] c_bullet_x,
  output logic [9:0] c_bullet_y, 
  input wire [2:0] d_bullet_in,
  output logic [10:0] d_box_x,
  output logic [9:0] d_box_y,
  output logic [10:0] d_bullet_x,
  output logic [9:0] d_bullet_y,

  output logic [1:0] dead
  );

  localparam NEUTRAL = 0;
  localparam RIGHT = 1;
  localparam LEFT = 2; 
  localparam UP = 3;
  localparam DOWN = 4;

    localparam BOX_DIM = 90;


  logic [2:0] parsed_b;
  logic [2:0] parsed_c;
  logic [2:0] parsed_d;

   always_ff @(posedge clk_in) begin

        if (rst_in) begin
          parsed_b <= NEUTRAL;
          parsed_c <= NEUTRAL;
          parsed_d <= NEUTRAL;
        end else if (nf_in) begin
          dead <= 0;
          case (parsed_b)
            NEUTRAL: begin
              parsed_b <= b_bullet_in;
            end
            RIGHT: begin
              if (b_bullet_x > 1260) begin
                parsed_b <= NEUTRAL;
              end
            end 
            LEFT: begin
              if (b_bullet_x < 17) begin
                parsed_b <= NEUTRAL;
              end
            end 
            UP: begin
              if (b_bullet_y < 17) begin
                parsed_b <= NEUTRAL;
              end
            end 
            DOWN: begin
              if (b_bullet_y > 700) begin
                parsed_b <= NEUTRAL;
              end
            end
            default: parsed_b <= NEUTRAL;
          endcase

          case (parsed_c)
            NEUTRAL: begin
              parsed_c <= c_bullet_in;
            end
            RIGHT: begin
              if (c_bullet_x > 1260) begin
                parsed_c <= NEUTRAL;
              end
            end 
            LEFT: begin
              if (c_bullet_x < 17) begin
                parsed_c <= NEUTRAL;
              end
            end 
            UP: begin
              if (c_bullet_y < 17) begin
                parsed_c <= NEUTRAL;
              end
            end 
            DOWN: begin
              if (c_bullet_y > 700) begin
                parsed_c <= NEUTRAL;
              end
            end
            default: parsed_c <= NEUTRAL;
          endcase

          case (parsed_d)
            NEUTRAL: begin
              parsed_d <= d_bullet_in;
            end
            RIGHT: begin
              if (d_bullet_x > 1260) begin
                parsed_d <= NEUTRAL;
              end
            end 
            LEFT: begin
              if (d_bullet_x < 17) begin
                parsed_d <= NEUTRAL;
              end
            end 
            UP: begin
              if (d_bullet_y < 17) begin
                parsed_d <= NEUTRAL;
              end
            end 
            DOWN: begin
              if (d_bullet_y > 700) begin
                parsed_d <= NEUTRAL;
              end
            end
            default: parsed_d <= NEUTRAL;
          endcase

        if (((b_bullet_x > c_box_x) && (b_bullet_x < (c_box_x+BOX_DIM)) && (b_bullet_y > c_box_y) && (b_bullet_y < (c_box_y+BOX_DIM))) || ((d_bullet_x > c_box_x) && (d_bullet_x < (c_box_x+BOX_DIM)) && (d_bullet_y > c_box_y) && (d_bullet_y < (c_box_y+BOX_DIM)))) begin
          parsed_b <= NEUTRAL;
          parsed_c <= NEUTRAL;
          parsed_d <= NEUTRAL;
          dead <= 2;
        end else if (((c_bullet_x > box_x) && (c_bullet_x < (box_x+BOX_DIM)) && (c_bullet_y > box_y) && (d_bullet_y < (box_y+BOX_DIM))) || ((d_bullet_x > box_x) && (d_bullet_x < (box_x+BOX_DIM)) && (d_bullet_y > box_y) && (d_bullet_y < (box_y+BOX_DIM)))) begin
          parsed_b <= NEUTRAL;
          parsed_c <= NEUTRAL;
          parsed_d <= NEUTRAL;
          dead <= 1;
        end else if (((b_bullet_x > d_box_x) && (b_bullet_x < (d_box_x+BOX_DIM)) && (b_bullet_y > d_box_y) && (b_bullet_y < (d_box_y+BOX_DIM))) || ((c_bullet_x > d_box_x) && (c_bullet_x < (d_box_x+BOX_DIM)) && (c_bullet_y > d_box_y) && (c_bullet_y < (d_box_y+BOX_DIM)))) begin
          parsed_b <= NEUTRAL;
          parsed_c <= NEUTRAL;
          parsed_d <= NEUTRAL;
          dead <= 3;

        end


        end
   end


  move_bullet movingbullets(
    .clk_in(clk_in), //
    .rst_in(rst_in),
    .nf_in(nf_in),
    .b_bullet_in(parsed_b),
    .c_bullet_in(parsed_c),
    .d_bullet_in(parsed_d),
    .box_x(box_x),
    .box_y(box_y),
    .c_box_x(c_box_x),
    .c_box_y(c_box_y),
    .d_box_x(d_box_x),
    .d_box_y(d_box_y),
    .b_bullet_x(b_bullet_x),
    .b_bullet_y(b_bullet_y),
    .c_bullet_x(c_bullet_x),
    .c_bullet_y(c_bullet_y), 
    .d_bullet_x(d_bullet_x),
    .d_bullet_y(d_bullet_y)
  );


endmodule