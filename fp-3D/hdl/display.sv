/* Helper function that returns pixels on the screen contained in a given triangle
*/
module max(
    input wire [9:0] v1,
    input wire [9:0] v2,
    input wire [9:0] v3,
    output logic [9:0] max
);
logic [9:0] v12;
logic [9:0] v23;

assign v12 = v1 >= v2 ? v1 : v2;
assign v23 = v2 >= v3 ? v2 : v3;
assign max = v12 >= v23 ? v12 : v23; 
endmodule // max

module min(
    input wire [9:0] v1,
    input wire [9:0] v2,
    input wire [9:0] v3,
    output logic [9:0] min
);
logic [9:0] v12;
logic [9:0] v23;

assign v12 = v1 <= v2 ? v1 : v2;
assign v23 = v2 <= v3 ? v2 : v3;
assign min = v12 <=  v23 ? v12 : v23; 
endmodule // min

module triangle_color #(
    parameter WIDTH = 1024,
    parameter HEIGHT = 720
) (
    input wire clk_in,
    input wire rst_in,
    input wire valid_in,
    input wire [19:0] vertex_a,
    input wire [19:0] vertex_b,
    input wire [19:0] vertex_c,
    output logic valid_out, // Note: this is not single cycle !!
    output logic [19:0] pixel_to_color,
    output logic last_out
);
    localparam WORKER_COUNT = 5; // Still need to manually adjust in WAIT state
    typedef enum {IDLE=0, INIT=1, TRIGGER=2, WAIT=3} state;

    state fsm_state;
    logic [19:0] pixel_queue [WORKER_COUNT-1:0]; 
    logic [WORKER_COUNT-1:0] inside_check;

    // generate single-cycle signals for workers
    logic [WORKER_COUNT-1:0] pixel_valid_in; 
    logic [WORKER_COUNT-1:0] pvalid_flags;
    
    // to calculate screen coordinates to check
    logic [9:0] check_pixels_x [WORKER_COUNT-1:0]; 
    logic [9:0] check_pixels_y [WORKER_COUNT-1:0];
    logic [9:0] min_coord [1:0];
    logic [9:0] max_coord [1:0];
    logic [19:0] starting_pixel;

    // Initialize mini-workers
    generate
        genvar i;        
        for (i = 0; i < WORKER_COUNT; i = i+1) begin: workers
            logic is_inside;
            logic w_valid_out;

            in_triangle_wrap #(.SYS_BIT_WIDTH(10)) pixel_check (
            .clk_in(clk_in),
            .valid_in(pixel_valid_in[i]),
            .vertex_ax(vertex_a[19:10]),
            .vertex_ay(vertex_a[9:0]),
            .vertex_bx(vertex_b[19:10]),
            .vertex_by(vertex_b[9:0]),
            .vertex_cx(vertex_c[19:10]),
            .vertex_cy(vertex_c[9:0]),
            .point_x(check_pixels_x[i]),
            .point_y(check_pixels_y[i]),
            .valid_out(w_valid_out),
            .is_inside(is_inside)
            );

            always_ff @( posedge clk_in ) begin
                if (w_valid_out) begin
                    pvalid_flags[i] <= 1;
                    inside_check[i] <= is_inside;
                    pixel_queue[i] <= {check_pixels_x[i], check_pixels_y[i]};
                end
            end
        end
    endgenerate

    logic [WORKER_COUNT-1:0] complete;
    logic [WORKER_COUNT-1:0] not_working;
    logic [9:0] last_x;
    logic [9:0] last_y;
    logic out_of_bounds;

    logic [9:0] upper_bound_x;
    logic [9:0] upper_bound_y;


    always_comb begin
        last_x = starting_pixel[19:10];
        last_y = starting_pixel[9:0];
        upper_bound_x = max_coord[0] + 1;
        upper_bound_y = max_coord[1] + 1;
    end

    min y_min (.v1(vertex_a[9:0]), .v2(vertex_b[9:0]), .v3(vertex_c[9:0]), .min(min_coord[1]));
    min x_min (.v1(vertex_a[19:10]), .v2(vertex_b[19:10]), .v3(vertex_c[19:10]), .min(min_coord[0]));

    max y_max (.v1(vertex_a[9:0]), .v2(vertex_b[9:0]), .v3(vertex_c[9:0]), .max(max_coord[1]));
    max x_max (.v1(vertex_a[19:10]), .v2(vertex_b[19:10]), .v3(vertex_c[19:10]), .max(max_coord[0]));


    always_ff @( posedge clk_in) begin
        if (rst_in) begin
            starting_pixel <= {min_coord[0], min_coord[1]};
            fsm_state <= IDLE;

        end else begin
            if (fsm_state == IDLE) begin
                if (valid_in) begin
                    starting_pixel <= {min_coord[0], min_coord[1]};
                    fsm_state <= INIT;
                    last_out <= 0;
                end

                if (last_out) begin
                    last_out <= 0;
                end

            end else if (fsm_state == INIT) begin
                for (integer i = 0; i < WORKER_COUNT; i = i+1) begin
                    if ((((upper_bound_x - last_x) < (i+1)) && (last_y == upper_bound_y - 1)) || out_of_bounds) begin
                        not_working[i] <= 1;

                    end else begin
                        if (upper_bound_x - last_x < (i+1)) begin
                            check_pixels_y[i] <= last_y + 1;
                            check_pixels_x[i] <= last_x + i - upper_bound_x;
                        end else begin
                            check_pixels_y[i] <= last_y;
                            check_pixels_x[i] <= last_x + i;;
                        end
                        pixel_valid_in[i] <= 1;
                        not_working[i] <= 0;
                    end
                end

                if (&not_working == 1) begin
                    fsm_state <= IDLE;
                    last_out <= 1;
                end else begin
                    fsm_state <= TRIGGER;
                end

            end else if (fsm_state == TRIGGER) begin
                for (integer i = 0; i < WORKER_COUNT; i = i+1) begin
                    pixel_valid_in[i] <= 0;
                end
                fsm_state <= WAIT;

            end else if (fsm_state == WAIT) begin
                if (pvalid_flags[0]) begin
                    if (inside_check[0]) begin
                        pixel_to_color <= pixel_queue[0];
                    end
                    pvalid_flags[0] <= 0;
                    complete[0] <= 1;
                    valid_out <= inside_check[0]; // only assert valid_out if value in triangle

                end else if (pvalid_flags[1]) begin
                    if (inside_check[1]) begin
                        pixel_to_color <= pixel_queue[1];
                    end 
                    pvalid_flags[1] <= 0;
                    complete[1] <= 1;
                    valid_out <= inside_check[1];

                end else if (pvalid_flags[2]) begin
                    if (inside_check[2]) begin
                        pixel_to_color <= pixel_queue[2];
                    end
                    pvalid_flags[2] <= 0;
                    complete[2] <= 1;
                    valid_out <= inside_check[2];

                end else if (pvalid_flags[3]) begin
                    if (inside_check[3]) begin
                        pixel_to_color <= pixel_queue[3];
                    end
                    pvalid_flags[3] <= 0;
                    complete[3] <= 1;
                    valid_out <= inside_check[3];

                end else if (pvalid_flags[4]) begin
                    if (inside_check[4]) begin
                        pixel_to_color <= pixel_queue[4];
                    end
                    pvalid_flags[4] <= 0;
                    complete[4] <= 1;
                    valid_out <= inside_check[4];

                // Only the ones that started can complete
                end else if (&(complete | not_working) == 1) begin 
                    complete <= 0;
                    fsm_state <= INIT;
                    valid_out <= 0;
                    if ((last_x + WORKER_COUNT) >= upper_bound_x) begin
                        if (last_y == upper_bound_y - 1) begin
                            out_of_bounds <= 1; //is there a way to speed this up? maybe set last_out here
                        end 
                        last_y <= last_y + 1;
                        last_x <= last_x + WORKER_COUNT - upper_bound_x;                
                    end else begin
                        last_x <= last_x + WORKER_COUNT;  
                    end

                end else begin
                    valid_out <= 0;
                end

            end
        end
    end
endmodule // triangle_color

/* Can rework function above to do the calculation over a fixed list of triangle data and finding the min_z. 
But this requires knowing all the triangles before hand, and will need TRIANGLE cycles to lookup this information. :(*/
/* Is this better than having to wait 2 cycles at each pixel to read the z-index of it previous triangle*/

/*
when transforming (x_3, y_3, z_3) to (x_2, y_2, t, z_3) -> store z_3 because this is the z-index we need? might not be accurate on a point to point level, 
so baycentric could be used to interpolate (P = uA + vB+ wC, u+v+w=1) ? ---> need to create interpolate module with floatops

else have to perform find_t for each pixel given a triangle
*/

module displaying #(
    parameter WIDTH = 1024,
    parameter HEIGHT = 720
)(
    input wire clk_in,
    input wire rst_in,
    input wire valid_in,
    input wire [20:0] game_obj_loc [5:0],
    output logic smth
);

logic [31:0] screen_distance = 'd1;

logic ftvalid;
logic [31:0] fvec_x;
logic [31:0] fvec_y;
logic [31:0] fvec_z;
logic [23:0] color; 
logic gen_last_out;

threegen #(.PLAYERS(3)
) triangle_gen(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .valid_in(valid_in),
    .obj_location(game_obj_loc),
    .valid_out(ftvalid),
    .triangle_x(fvec_x),
    .triangle_y(fvec_y),
    .triangle_z(fvec_z),
    .color(color),
    .t_last_out(gen_last_out)
); // returns vertices by triangle and their corresponding color

logic [9:0] pixel_x;
logic [9:0] pixel_y;
logic pixel_valid;
scale_vec get2d (
    .clk_in(clk_in),
    .rst_in(rst_in),
    .camera_distance(screen_distance),
    .vec_x(fvec_x),
    .vec_y(fvec_y),
    .vec_z(fvec_z),
    .valid_in(ftvalid),
    .screen_x(pixel_x),
    .screen_y(pixel_y),
    .valid_out(pixel_valid)
); // transforms these 3D vertices to 2D screen coordinates

localparam TRIANGLES = 72; // 6 objects * 12 triangles each
logic [$clog2(TRIANGLES)-1:0] wt_addr;
logic twrite;
logic [59:0] tv_in;
logic [59:0] prev_tv_out;

xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(60), // A{x, y}, B{x y}, C{x, y}
    .RAM_DEPTH(72))
    triangle_data (
    // writing output from scale_vec
    .addra(wt_addr),
    .clka(clk_in),
    .wea(twrite),
    .dina(tv_in),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(rst_in),
    .douta(prev_tv_out),
    // reading triangles for triangle_color
    .addrb(rt_addr),
    .dinb(1'b0),
    .clkb(clk_in),
    .web(1'b0),
    .enb(1'b1),
    .rstb(rst_in),
    .regceb(1'b1),
    .doutb(tv_out)
  );


always_comb begin
    tv_in = {screen_px[0], screen_px[1], screen_px[2]};
    twrite = stage_check == 1;
end

logic [19:0] screen_px [2:0];
logic [3:0] stage_check;
logic write_done;

typedef enum {A=0, B=1, C=2, D=3 } read_fsm;
read_fsm read_state;
logic [$clog2(TRIANGLES)-1:0] rt_addr;
logic [59:0] tv_out;
logic read_done;

always_ff @( posedge clk_in ) begin
    if (rst_in) begin
        wt_addr <= 0;
        rt_addr <= 0;
        stage_check <= 4'b1000;
        read_state <= A;
    end else begin

        // Writing FSM
        if (stage_check == 1) begin
            stage_check <= 4'b1000;
            if (wt_addr == (TRIANGLES - 1)) begin
                write_done <= 1;
            end else begin
                wt_addr <= wt_addr + 1;
            end

        end else if (pixel_valid) begin
            write_done <= 0;
            screen_px[0] <= {pixel_x, pixel_y};
            for (integer i = 0; i < 2; i = i+1) begin
                screen_px[i+1] <= screen_px[i];
            end
            stage_check <= stage_check >> 1;
        end
        
        // Reading FSM
        case (read_state)
            A: begin
                read_state <= B;
                cvalid_in <= 0;
            end
            B: read_state <= C;
            C: begin
                cvalid_in <= 1;
                cvertex_a <= tv_out[59:40];
                cvertex_b <= tv_out[39:20];
                cvertex_c <= tv_out[19:0];
                if (clast) begin
                    read_state <= A;
                    rt_addr <= rt_addr + 1;
                end
            end
        endcase
    end
end 

logic [19:0] cvertex_a;
logic [19:0] cvertex_b;
logic [19:0] cvertex_c;
logic cvalid_in;
logic clast;

logic [19:0] pixel_to_color;
logic to_color;

localparam SOURCE_SIZE = WIDTH * HEIGHT;
triangle_color #(.WIDTH(WIDTH), .HEIGHT(HEIGHT)
  ) color_screen(
    .clk_in(clk_in),
    .rst_in(rst_in),
    .valid_in(cvalid_in),
    .vertex_a(cvertex_a),
    .vertex_b(cvertex_b),
    .vertex_c(cvertex_c),
    .valid_out(to_color), // Note: this is not single cycle !!
    .pixel_to_color(pixel_to_color),
    .last_out(clast)
);
logic [$clog2(SOURCE_SIZE)-1:0] sr_add;     

logic pixel_value;
logic [23:0] previous;

logic [$clog2(SOURCE_SIZE)-1:0] pixel_addr;
assign pixel_addr = pixel_to_color[19:10] + (pixel_to_color[9:0] * WIDTH);

xilinx_true_dual_port_read_first_2_clock_ram #(
    .RAM_WIDTH(24), // A{x, y}, B{x y}, C{x, y}
    .RAM_DEPTH(SOURCE_SIZE))
    screen_data (
    // writing pixel values
    .addra(pixel_addr),
    .clka(clk_in),
    .wea(to_color),
    .dina(color),
    .ena(1'b1),
    .regcea(1'b1),
    .rsta(rst_in),
    .douta(previous),
    // reading pixels
    .addrb(sr_add),
    .dinb(1'b0),
    .clkb(clk_in),
    .web(1'b0),
    .enb(1'b1),
    .rstb(rst_in),
    .regceb(1'b1),
    .doutb(color)
  );
endmodule