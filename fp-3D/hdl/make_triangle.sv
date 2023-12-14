`default_nettype none
`timescale 1ns/1ps

/* Takes in floating points as values and returns 2D position it intersects with the screen
Takes in a (floatx, floaty, floatz) and returns (fixedx, fixedy)
*/
module scale_vec (
    input wire clk_in,
    input wire rst_in,
    input wire [31:0] camera_distance,
    input wire [31:0] vec_x,
    input wire [31:0] vec_y,
    input wire [31:0] vec_z,
    input wire valid_in,
    output logic [31:0] screen_x,
    output logic [31:0] screen_y,
    output logic valid_out
);

// Calculating screen_x
logic xfactor_valid;
logic [31:0] x_factor;
logic [32:0] xf_user;
divide_many xfactor (
    .aclk(clk_in),
    .s_axis_a_tvalid(valid_in),
    .s_axis_a_tdata(vec_x),
    .s_axis_a_tuser(camera_distance),
    .s_axis_b_tvalid(valid_in),
    .s_axis_b_tdata(vec_z),
    .m_axis_result_tvalid(xfactor_valid),
    .m_axis_result_tdata(x_factor),
    .m_axis_result_tuser(xf_user)
);

logic floatx_valid;
logic [31:0] floatx;
multiply_many get_screenx (
    .aclk(clk_in),
    .s_axis_a_tvalid(xfactor_valid && !xf_user[0]),
    .s_axis_a_tdata(x_factor),
    .s_axis_b_tvalid(xfactor_valid && !xf_user[0]),
    .s_axis_b_tdata(xf_user[32:1]),
    .m_axis_result_tvalid(floatx_valid),
    .m_axis_result_tdata(floatx)
);

logic screen_x_valid;
logic [31:0] u_screen_x;
float2fixed_many fixedx (
    .aclk(clk_in),
    .s_axis_a_tvalid(floatx_valid),
    .s_axis_a_tdata(floatx),
    .m_axis_result_tvalid(screen_x_valid),
    .m_axis_result_tdata(u_screen_x)
);

logic [9:0] max_x = 'd1024;
assign screen_x = u_screen_x <= max_x ? u_screen_x : max_x;

// Calculating screen_y
logic yfactor_valid;
logic [31:0] y_factor;
logic [32:0] yf_user;
divide_many yfactor (
    .aclk(clk_in),
    .s_axis_a_tvalid(valid_in),
    .s_axis_a_tdata(vec_y),
    .s_axis_a_tuser(camera_distance),
    .s_axis_b_tvalid(valid_in),
    .s_axis_b_tdata(vec_z),
    .m_axis_result_tvalid(yfactor_valid),
    .m_axis_result_tdata(y_factor),
    .m_axis_result_tuser(yf_user)
);

logic floaty_valid;
logic [31:0] floaty;
multiply_many get_screeny (
    .aclk(clk_in),
    .s_axis_a_tvalid(yfactor_valid && !yf_user[0]),
    .s_axis_a_tdata(y_factor),
    .s_axis_b_tvalid(yfactor_valid && !yf_user[0]),
    .s_axis_b_tdata(yf_user[32:1]),
    .m_axis_result_tvalid(floaty_valid),
    .m_axis_result_tdata(floaty)
);

logic screen_y_valid;
logic [31:0] u_screen_y;
float2fixed_many fixedy (
    .aclk(clk_in),
    .s_axis_a_tvalid(floaty_valid),
    .s_axis_a_tdata(floaty),
    .m_axis_result_tvalid(screen_y_valid),
    .m_axis_result_tdata(u_screen_y)
);

logic [9:0] max_y = 'd720;
assign screen_y = u_screen_y <= max_y ? u_screen_y : max_y;

assign valid_out = screen_x_valid && screen_y_valid; // expected to finish at the same time

// maybe simply just propagate invalid signal!!
endmodule // scale_vec

module float_p2v(
    input wire clk_in,
    input wire valid_in,
    input wire [31:0] vertex_a [2:0],
    input wire [31:0] vertex_b [2:0],
    output wire valid_out,
    output wire [31:0] vector_out [2:0]
);
localparam VECTOR_SIZE = 3;
generate
    genvar i;
    for(i=0; i<VECTOR_SIZE; i=i+1) begin: difference
        logic done;
        difference_many vector_calc (
            .aclk(clk_in),
            .s_axis_a_tvalid(valid_in),
            .s_axis_a_tdata(vertex_b[i]),
            .s_axis_b_tvalid(valid_in),
            .s_axis_b_tdata(vertex_a[i]),
            .m_axis_result_tvalid(done),
            .m_axis_result_tdata(vector_out[i])
        );
    end
endgenerate
assign valid_out = difference[0].done && difference[1].done && difference[2].done;
endmodule //float_p2v

/*Takes in vertices in the form of floats (float_x, float_y) and returns the normal 
*/
module get_normal ( // make this blocking for now, just for testing purposes
    input wire clk_in,
    input wire valid_in,
    input wire [31:0] vertex_a [2:0], 
    input wire [31:0] vertex_b [2:0],
    input wire [31:0] vertex_c [2:0],
    output logic [31:0] normal_out [2:0],
    output logic valid_out // should really specify ready here :/ later lol
);
logic AB_done;
logic [31:0] AB [2:0];
float_p2v calc_AB(
    .clk_in(clk_in),
    .valid_in(valid_in),
    .vertex_a(vertex_a),
    .vertex_b(vertex_b),
    .valid_out(AB_done),
    .vector_out(AB)
);

logic AC_done;
logic [31:0] AC [2:0];
float_p2v calc_AC(
    .clk_in(clk_in),
    .valid_in(valid_in),
    .vertex_a(vertex_a),
    .vertex_b(vertex_c),
    .valid_out(AC_done),
    .vector_out(AC)
);

logic vec_ready;
cross_product crossp(
    .clk_in(clk_in),
    .valid_in(AB_done && AC_done),
    .vec_a(AB), 
    .vec_b(AC),
    .vec_ready(vec_ready),
    .value_out(normal_out),
    .valid_out(valid_out),
    .cross_product_ready(1'b1)
);

endmodule //get_normal

module get_normal_wrap (
    input wire clk_in,
    input wire valid_in,
    input wire [31:0] vec_ax,
    input wire [31:0] vec_ay,
    input wire [31:0] vec_az,
    input wire [31:0] vec_bx,
    input wire [31:0] vec_by,
    input wire [31:0] vec_bz,
    input wire [31:0] vec_cx,
    input wire [31:0] vec_cy,
    input wire [31:0] vec_cz,
    output logic [31:0] normal_x,
    output logic [31:0] normal_y,
    output logic [31:0] normal_z,
    output logic valid_out
);

logic [31:0] vec_a [2:0];
make_vector3 vec_1( .vector_x(vec_ax), .vector_y(vec_ay),
    .vector_z(vec_az), .vector_3(vec_a));

logic [31:0] vec_b [2:0];
make_vector3 vec_2(.vector_x(vec_bx), .vector_y(vec_by),
    .vector_z(vec_bz), .vector_3(vec_b));

logic [31:0] vec_c [2:0];
make_vector3 vec_(.vector_x(vec_cx), .vector_y(vec_cy),
    .vector_z(vec_cz), .vector_3(vec_c));

logic [31:0] normal_out [2:0];
get_normal find_n(
    .clk_in(clk_in),
    .valid_in(valid_in),
    .vertex_a(vec_a), 
    .vertex_b(vec_b),
    .vertex_c(vec_c),
    .normal_out(normal_out),
    .valid_out(valid_out) 
);

always_comb begin
    normal_x = normal_out[0];
    normal_y = normal_out[1];
    normal_z = normal_out[2];
end
endmodule // get_normal_wrap

/* Finds the z-index of a pixel within a triangle
*/
module z_index (
    input wire clk_in,
    input wire valid_in,
    input wire [31:0] normal,
    input wire [31:0] camera_distance,
    input wire [20:0] screen_data,
    output logic valid_out,
    output logic z_index_out
);

logic vectors_ready;
// dot_product vector_dot_self(
//     .clk_in(clk_in),
//     .valid_in(valid_in),
//     .vector1(vector_in),
//     .vector2(vector_in),
//     .vectors_ready(vectors_ready),
//     .value_out(mag_square),
//     .valid_out(ms_valid),
//     .dot_product_ready(ms_ready)
// );
    
endmodule // z_index
/*
# Convert 2D triangles, (in BRAM) to 3D for each character  <x, y, z-offset>
// 288 bit for each triangle a_{x-z}, b_{x-z}, c_{x-z} can get all the data we need in one read
// take game state and then render the frame
// maybe count the number of triangles entered and use as tlast??


- 2D position of character from game (need to convert to floats) & BRAM w/ each triangle in 3D model of the character -> add to transform to 3d space
# hardcode into .mem file
- To 2D when vectors from camera to vertices hit the screen. Gather all and store in BRAM (done)
- Then take triangles and color screen with pixels
- Z-index calculations with z-buffer. Need to calculate normal with cross product, and with vec O (can simply use <vertex_A_x, vertex_A_y, d>) calculate z-index
*/
`default_nettype wire