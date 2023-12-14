/*
t will be used to scale the input vector < vec_x, vec_y, vec_z > to determine the pixel on which the vector
from the camera to a point on a shape intersects the screen. Then that pixel will appear at (t*vec_x, t*vec_y)
*/
module find_t (
    input wire clk_in,
    input wire [31:0] camera_distance,
    input wire [31:0] vec_x, vec_y, vec_z,
    output wire vec_ready,
    input wire valid_in,
    output wire [31:0] t_out,
    output wire valid_out,
    input wire find_t_ready
); // takes 716ns

// Calculating magnitude of input vector
logic magnitude_valid;
logic [31:0] magnitude;
logic magnitude_ready;
logic vect
magnitude vec_mag (
    .clk_in(clk_in),
    .valid_in(valid_in),
    .vector_x(vec_x),
    .vector_y(vec_y),
    .vector_z(vec_z),
    .vectors_ready(vec_ready)
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