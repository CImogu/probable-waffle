// Check if point is in a triangle -> Calculate Baycentric coordinates using cross-product module
// Identify color of triangle

/*
t will be used to scale the input vector < vec_x, vec_y, vec_z > to determine the pixel on which the vector
from the camera to a point on a shape intersects the screen. Then that pixel will appear at (t*vec_x, t*vec_y)
*/
module find_t (
    input wire clk_in,
    input wire [31:0] camera_distance,
    input wire [31:0] vec_x,
    input wire [31:0] vec_y,
    input wire [31:0] vec_z,
    input wire valid_in,
    output wire [31:0] t_out,
    output wire valid_out,
    input wire find_t_ready,
);

logic [31:0] vector3_in [2:0];
always_comb begin
    vector3_in[0] = vec_x;
    vector3_in[1] = vec_y;
    vector3_in[2] = vec_z;
end

// Calculating magnitude of input vector
logic magnitude_valid;
logic [31:0] magnitude;
logic magnitude_ready;
magnitude vec_mag (
    .clk_in(clk_in),
    .valid_in(valid_in),
    .vector_x(vec_x),
    .vector_y(vec_y),
    .vector_z(vec_z),
    .magnitude(magnitude),
    .valid_out(magnitude_valid),
    .magnitude_ready(magnitude_ready)
);

// Insert fp-division module
logic cd_ready;
logic z_ready;

logic constant_valid;
logic [31:0] constant;
logic constant_ready;
divider divide (
    .aclk(clk_in),
    .s_axis_a_tvalid(valid_in),
    .s_axis_a_tready(cd_ready),
    .s_axis_a_tdata(camera_distance),
    .s_axis_b_tvalid(valid_in),
    .s_axis_b_tready(z_ready),
    .s_axis_b_tdata(vec_z),
    .m_axis_result_tvalid(constant_valid),
    .m_axis_result_tready(constant_ready),
    .m_axis_result_tdata(constant)
);

// Find t
multiplier vector_mul (
    .aclk(clk_in),
    .s_axis_a_tvalid(magnitude_valid),
    .s_axis_a_tready(magnitude_ready),
    .s_axis_a_tdata(magnitude),
    .s_axis_b_tvalid(constant_valid),
    .s_axis_b_tready(constant_ready),
    .s_axis_b_tdata(constant),
    .m_axis_result_tvalid(valid_out),
    .m_axis_result_tready(find_t_ready),
    .m_axis_result_tdata(t_out)
);
endmodule // find_t

/*
Need to add a number to floating point operator here
*/
module cp_2 ( // Might possibly need to rewrite this module !!
    input wire clk_in,
    input wire valid_a_in,
    input wire valid_b_in,
    input wire [31:0] vec_ax, 
    input wire [31:0] vec_ay,
    input wire [31:0] vec_bx,
    input wire [31:0] vec_by,
    output logic [31:0] value_out,
    output logic valid_out,
    input wire cp_ready
);
//Save values until both have been found
logic [31:0] vec_a [1:0];
logic [31:0] vec_b [1:0];
logic [1:0] valid_in_flag;

always_ff @(posedge clk_in) begin 
    if (valid_in_flag == 'b11) begin
        valid_flag <= 0;
    end else begin
        if (valid_a_in) begin
            vec_a[0] <= vec_ax;
            vec_a[1] <= vec_ay;
            valid_in_flag[0] <= 1;
        end
        if (valid_b_in) begin
            vec_b[0] <= vec_bx;
            vec_b[1] <= vec_by;
            valid_in_flag[1] <= 1;
        end
    end
end

cp_helper cp2 (
    .clk_in(clk_in),
    .valid_in(valid_in_flag == 'b11),
    .val1_in(vec_a[0]), //vec_ax
    .val2_in(vec_b[1]), //vec_by
    .val3_in(vec_a[1]), //vec_ay
    .val4_in(vec_b[0]), //vec_bx
    .value_out(value_out),
    .valid_out(valid_out),
    .cp_ready(cp_ready)
);
endmodule // cp_2

/*
Error: given points are not in floating point notation
Turn this into regular subtraction module
*/
module p2v (
    input wire clk_in,
    input wire valid_in,
    input wire [31:0] point_a [1:0],
    input wire [31:0] point_b [1:0],
    output logic valid_out,
    output logic [31:0] vec_ab_out [1:0]
    input wire p2v_ready
);
generate
    genvar i;

    logic point_a_ready;
    logic point_b_ready;
    logic valid_diff_out;
    for (i = 0; i < 2; i = i + 1) begin: sub
        difference ab(
            .aclk(clk_in),
            .s_axis_a_tvalid(valid_in),
            .s_axis_a_tready(point_a_ready),
            .s_axis_a_tdata(point_b[i]),
            .s_axis_b_tvalid(valid_in),
            .s_axis_b_tready(point_a_ready),
            .s_axis_b_tdata(point_a[i]),
            .m_axis_result_tvalid(valid_diff_out),
            .m_axis_result_tready(p2v_ready),
            .m_axis_result_tdata(vec_ab_out[i])
        );
    end
endgenerate

logic [1:0] valid_flag;
always_ff @(posedge clk_in ) begin
    if (valid_flag == 'b11) begin
        valid_flag <= 0;
    end else begin
        if (sub.valid_diff_out[0]) begin
            valid_flag[0] <= 1;
        end
        if (sub.valid_diff_out[1]) begin
            valid_flag[1] <= 1;
        end
    end
end

assign valid_out = valid_flag == 'b11;
endmodule //p2v

/**
Given the vertices of a triangle, and its associated color, return True if point is contained in triangle
**/
module in_triangle( // wait for a single valid signal? Or for each individual input?
    input wire clk_in,
    input wire valid_in,
    input wire [31:0] vertex_a [1:0],
    input wire [31:0] vertex_b [1:0],
    input wire [31:0] vertex_c [1:0],
    input wire [31:0] point [1:0], // how about checking for all points in a single module
    output logic valid_out;
    output logic is_inside;
    input wire is_ready;
);


// Calculate vectors AB and AC
logic [31:0] vector_AB [1:0];
logic AB_valid;
p2v ab(
    .clk_in(clk_in),
    .valid_in(valid_in),
    .point_a(vertex_a),
    .point_b(vertex_b),
    .valid_out(AB_valid),
    .vec_ab_out(vector_AB),
    .p2v_ready(is_ready)
);

logic [31:0] vector_AC [1:0];
logic AC_valid;
p2v ac(
    .clk_in(clk_in),
    .valid_in(valid_in),
    .point_a(vertex_a),
    .point_b(vertex_c),
    .valid_out(AB_valid),
    .vec_ab_out(vector_AC),
    .p2v_ready(is_ready)
);

// Calculate PA, PB, PC
logic [31:0] vector_PA [1:0];
logic PA_valid;
p2v pa(
    .clk_in(clk_in),
    .valid_in(valid_in),
    .point_a(point),
    .point_b(vertex_a),
    .valid_out(PA_valid),
    .vec_ab_out(vector_PA),
    .p2v_ready(is_ready)
);

logic [31:0] vector_PB [1:0];
logic PB_valid;
p2v pb(
    .clk_in(clk_in),
    .valid_in(valid_in),
    .point_a(point),
    .point_b(vertex_b),
    .valid_out(PB_valid),
    .vec_ab_out(vector_PB),
    .p2v_ready(is_ready)
);

logic [31:0] vector_PC [1:0];
logic PC_valid;

p2v pb(
    .clk_in(clk_in),
    .valid_in(valid_in),
    .point_a(point),
    .point_b(vertex_c),
    .valid_out(PC_valid),
    .vec_ab_out(vector_PC),
    .p2v_ready(is_ready)
);

// Calculate ka = ||PB X PC||
logic [31:0] ka_constant;
logic ka_valid;
logic ka_ready;
cp_2 ka(
    .clk_in(clk_in),
    .valid_a_in(PB_valid),
    .valid_b_in(PC_valid),
    .vec_ax(vector_PB[0]), 
    .vec_ay(vector_PB[1]),
    .vec_bx(vector_PC[0]),
    .vec_by(vector_PC[1]),
    .value_out(ka_constant),
    .valid_out(ka_valid),
    .cp_ready(ka_ready)
);

// Calculate kb = ||PC X PA||
logic [31:0] kb_constant;
logic kb_valid;
logic kb_ready;
cp_2 kb(
    .clk_in(clk_in),
    .valid_a_in(PC_valid),
    .valid_b_in(PA_valid),
    .vec_ax(vector_PC[0]), 
    .vec_ay(vector_PC[1]),
    .vec_bx(vector_PA[0]),
    .vec_by(vector_PA[1]),
    .value_out(kb_constant),
    .valid_out(kb_valid),
    .cp_ready(kb_ready)
);

// Calculate d = ||AB X AC||
logic [31:0] d_constant;
logic d_valid;
logic d_ready;
cp_2 d(
    .clk_in(clk_in),
    .valid_a_in(AB_valid),
    .valid_b_in(AC_valid),
    .vec_ax(vector_AB[0]), 
    .vec_ay(vector_AB[1]),
    .vec_bx(vector_AC[0]),
    .vec_by(vector_AC[1]),
    .value_out(d_constant),
    .valid_out(d_valid),
    .cp_ready(d_ready)
);

// Calculate f = ka + kb
logic [31:0] f_constant;
logic f_valid;
logic f_ready;
adder ka_kb(
    .aclk(clk_in),
    .s_axis_a_tvalid(ka_valid),
    .s_axis_a_tready(ka_ready),
    .s_axis_a_tdata(ka_constant),
    .s_axis_b_tvalid(kb_valid),
    .s_axis_b_tready(kb_ready),
    .s_axis_b_tdata(kb_constant),
    .m_axis_result_tvalid(f_valid),
    .m_axis_result_tready(f_ready),
    .m_axis_result_tdata(f_constant)
);

// Calculate c_check = d - f
logic [31:0] c_check;
logic c_check_valid;
logic c_check_ready;

difference ab(
    .aclk(clk_in),
    .s_axis_a_tvalid(d_valid),
    .s_axis_a_tready(d_ready),
    .s_axis_a_tdata(d_constant),
    .s_axis_b_tvalid(f_valid),
    .s_axis_b_tready(f_ready),
    .s_axis_b_tdata(f_constant),
    .m_axis_result_tvalid(c_check_valid),
    .m_axis_result_tready(c_check_ready),
    .m_axis_result_tdata(c_check)
);

logic pos_a;
logic pos_b;
logic pos_c;

logic ka_done_flag;
logic kb_done_flag;
logic d_done_flag;

logic complete;

always_ff @(posedge clk_in) begin
    // Setup Flags
    if (ka_valid) begin
        ka_done_flag <= 1;
    end
    if (kb_valid) begin
        kb_done_flag <= 1;
    end
    if (d_valid) begin
        d_done_flag <= 1;
    end
    if (valid_out) begin
        valid_out <= 0;
    end

    if (valid_in && is_ready) begin
        complete <= 0;
        ka_done_flag <= 0;
        kb_done_flag <= 0;
        d_done_flag <= 0;
    end

    // Containment Checks - FSM
    if (ka_done_flag && kb_done_flag && d_done_flag) begin
        pos_a = (ka_constant[31] == d_constant[31]) || (ka_constant == 0);
        pos_b = (kb_constant[31] == d_constant[31]) || (kb_constant == 0);
        if (!pos_a || !pos_b) begin
            valid_out <= 1;
            is_inside <= 0;
            complete <= 1;
        end
    end else if (f_valid && !complete) begin
        if (f_constant == d_constant) begin
            valid_out <= 1;
            is_inside <= 1;
            complete <= 1;
        end
    end else if (c_check_valid && !complete) begin
        is_inside <= c_check[31] == d_constant[31];
        valid_out <= 1;
        complete <= 1;
    end
end

/* 
 Attempting to use an FSM to reduce unneccessary computation or fail early.
 Conditions to be inside a triangle? All must be true
 * if (sign(ka) == sign(d) or ka == 0)
 * if (sign(kb) == sign(d) or kb == 0)
 * if (sign(d - (ka+kb)) == sign(d) or (ka+kb) == d)
*/
    
endmodule // in_triangle

/*
Given the vertices of a triangle, and its associated color, update pixels on the screen within the
triangle to have the same color using a BRAM
*/
module color_points_in_triangle #(
    parameter S_WIDTH = 20, S_HEIGHT = 20;
) (
    input wire clk_in,
    input wire valid_in,
    input wire [31:0] vertex_a [1:0],
    input wire [31:0] vertex_b [1:0],
    input wire [31:0] vertex_c [1:0],
    input wire [31:0] color,
);
// Calculate vectors AB and AC

    
endmodule //color_points_in_triangle

/* Helper function that returns pixels on the screen contained in a given triangle
*/

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
    localparam WORKER_COUNT = 6;
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

    always_comb begin
        last_x = starting_pixel[19:10];
        last_y = starting_pixel[9:0];
    end


    always_ff @( posedge clk_in) begin
        if (rst_in) begin
            starting_pixel <= 20'b0;
            fsm_state <= IDLE;

        end else begin
            if (fsm_state == IDLE) begin
                if (valid_in) begin
                    starting_pixel <= 20'b0;
                    fsm_state <= INIT;
                    last_out <= 0;
                end

                if (last_out) begin
                    last_out <= 0;
                end

            end else if (fsm_state == INIT) begin
                for (integer i = 0; i < WORKER_COUNT; i = i+1) begin
                    if ((((WIDTH - last_x) < (i+1)) && (last_y == HEIGHT - 1)) || out_of_bounds) begin
                        not_working[i] <= 1;

                    end else begin
                        if (WIDTH - last_x < (i+1)) begin
                            check_pixels_y[i] <= last_y + 1;
                            check_pixels_x[i] <= last_x + i - WIDTH;
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
                // IS THERE A WAY TO SCALE THIS WITHOUT EDITING IT MANUALLY ????
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

                end else if (pvalid_flags[5]) begin
                    if (inside_check[5]) begin
                        pixel_to_color <= pixel_queue[5];
                    end
                    pvalid_flags[5] <= 0;
                    complete[5] <= 1;
                    valid_out <= inside_check[5];

                // Only the ones that started can complete
                end else if (&(complete | not_working) == 1) begin 
                    complete <= 0;
                    fsm_state <= INIT;
                    valid_out <= 0;
                    if ((last_x + WORKER_COUNT) >= WIDTH) begin
                        if (last_y == HEIGHT - 1) begin
                            out_of_bounds <= 1; //is there a way to speed this up? maybe set last_out here
                        end 
                        last_y <= last_y + 1;
                        last_x <= last_x + WORKER_COUNT - WIDTH;                
                    end else begin
                        last_x <= last_x + WORKER_COUNT;  
                    end

                end else begin
                    valid_out <= 0;
                end

            end
        end
    end

endmodule // color_points_in_triangle