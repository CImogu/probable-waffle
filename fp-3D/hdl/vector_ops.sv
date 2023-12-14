`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

/*
Pipeline: Take out values as they arrive! 
32 cycle latency ?
*/

module make_vector3 (
    input wire [31:0] vector_x,
    input wire [31:0] vector_y,
    input wire [31:0] vector_z,
    output logic [31:0] vector_3 [2:0]
);
always_comb begin
    vector_3[0] = vector_x;
    vector_3[1] = vector_y;
    vector_3[2] = vector_z;
end
endmodule //make_vector

//Might need to pass ready as an output dot product and cross_product >_<

module dot_product (
    input wire clk_in,
    input wire valid_in,
    input wire [31:0] vector1 [2:0], 
    input wire [31:0] vector2 [2:0],
    output wire vectors_ready,
    output logic [31:0] value_out,
    output logic valid_out,
    input wire dot_product_ready
);

localparam VECTOR_SIZE = 3;
logic [31:0] complete_vector [2:0];

generate
    genvar i;
    for(i=0; i<VECTOR_SIZE; i=i+1) begin: multiply
        logic multiply_done;
        logic x_ready;
        logic y_ready;
        logic multiply_ready;

        multiplier vector_mul (
            .aclk(clk_in),
            .s_axis_a_tvalid(valid_in),
            .s_axis_a_tready(x_ready),
            .s_axis_a_tdata(vector1[i]),
            .s_axis_b_tvalid(valid_in),
            .s_axis_b_tready(y_ready),
            .s_axis_b_tdata(vector2[i]),
            .m_axis_result_tvalid(multiply_done),
            .m_axis_result_tready(multiply_ready),
            .m_axis_result_tdata(complete_vector[i])
        );
    end
endgenerate

assign vectors_ready = multiply[0].multiply_ready && multiply[1].multiply_ready && multiply[2].multiply_ready;

logic first_sum_done;
logic [31:0] first_sum;
logic first_sum_ready;

adder first_add(
    .aclk(clk_in),
    .s_axis_a_tvalid(multiply[0].multiply_done),
    .s_axis_a_tready(multiply[0].multiply_ready),
    .s_axis_a_tdata(complete_vector[0]),
    .s_axis_b_tvalid(multiply[1].multiply_done),
    .s_axis_b_tready(multiply[1].multiply_ready),
    .s_axis_b_tdata(complete_vector[1]),
    .m_axis_result_tvalid(first_sum_done),
    .m_axis_result_tready(first_sum_ready),
    .m_axis_result_tdata(first_sum)
);

adder second_add(
    .aclk(clk_in),
    .s_axis_a_tvalid(first_sum_done),
    .s_axis_a_tready(first_sum_ready),
    .s_axis_a_tdata(first_sum),
    .s_axis_b_tvalid(multiply[2].multiply_done),
    .s_axis_b_tready(multiply[2].multiply_ready),
    .s_axis_b_tdata(complete_vector[2]),
    .m_axis_result_tvalid(valid_out),
    .m_axis_result_tready(dot_product_ready),
    .m_axis_result_tdata(value_out)
);
endmodule // dot_product

module magnitude(
    input wire clk_in,
    input wire valid_in,
    input wire [31:0] vector_x,
    input wire [31:0] vector_y,
    input wire [31:0] vector_z,
    output wire vectors_ready,
    output logic [31:0] magnitude,
    output logic valid_out,
    input wire magnitude_ready
); // Takes 625ns to calculate
/*
Since BRAM takes two cycles to read, consider pipelining this module
*/
logic [31:0] vector_in [2:0];
always_comb begin
    vector_in[0] = vector_x;
    vector_in[1] = vector_y;
    vector_in[2] = vector_z;
end

logic [31:0] mag_square;
logic ms_valid;
logic ms_ready;

dot_product vector_dot_self(
    .clk_in(clk_in),
    .valid_in(valid_in),
    .vector1(vector_in),
    .vector2(vector_in),
    .vectors_ready(vectors_ready),
    .value_out(mag_square),
    .valid_out(ms_valid),
    .dot_product_ready(ms_ready)
);
// Maybe use squares in computation. Watch for resource allocation problems on Vivado
sqrt vec2_sqrt(
    .aclk(clk_in),
    .s_axis_a_tvalid(ms_valid),
    .s_axis_a_tready(ms_ready),
    .s_axis_a_tdata(mag_square),
    .m_axis_result_tvalid(valid_out),
    .m_axis_result_tready(magnitude_ready),
    .m_axis_result_tdata(magnitude)
);

endmodule //magnitude

module cp_helper(
    input wire clk_in,
    input wire valid_in,
    input wire [31:0] val1_in,
    input wire [31:0] val2_in,
    input wire [31:0] val3_in,
    input wire [31:0] val4_in,
    output wire values_ready,
    output logic [31:0] value_out,
    output logic valid_out,
    input wire cp_ready
);

    logic val1_ready;
    logic val2_ready;
    logic [31:0] mul_result_1;
    logic mul1_valid;
    logic mul1_ready;

    multiplier mul_1 (
        .aclk(clk_in),
        .s_axis_a_tvalid(valid_in),
        .s_axis_a_tready(val1_ready),
        .s_axis_a_tdata(val1_in),
        .s_axis_b_tvalid(valid_in),
        .s_axis_b_tready(val2_ready),
        .s_axis_b_tdata(val2_in),
        .m_axis_result_tvalid(mul1_valid),
        .m_axis_result_tready(mul1_ready),
        .m_axis_result_tdata(mul_result_1)
    );

    logic val3_ready;
    logic val4_ready;
    logic [31:0] mul_result_2;
    logic mul2_valid;
    logic mul2_ready;

    multiplier mul_2 (
        .aclk(clk_in),
        .s_axis_a_tvalid(valid_in),
        .s_axis_a_tready(val3_ready),
        .s_axis_a_tdata(val3_in),
        .s_axis_b_tvalid(valid_in),
        .s_axis_b_tready(val4_ready),
        .s_axis_b_tdata(val4_in),
        .m_axis_result_tvalid(mul2_valid),
        .m_axis_result_tready(mul2_ready),
        .m_axis_result_tdata(mul_result_2)
    );

    difference diff(
        .aclk(clk_in),
        .s_axis_a_tvalid(mul1_valid),
        .s_axis_a_tready(mul1_ready),
        .s_axis_a_tdata(mul_result_1),
        .s_axis_b_tvalid(mul2_valid),
        .s_axis_b_tready(mul2_ready),
        .s_axis_b_tdata(mul_result_2),
        .m_axis_result_tvalid(valid_out),
        .m_axis_result_tready(cp_ready),
        .m_axis_result_tdata(value_out)
    );

    assign values_ready = val1_ready && val2_ready && val3_ready && val4_ready;
endmodule // cp_helper

module cross_product(
    input wire clk_in,
    input wire valid_in,
    input wire [31:0] vec_a [2:0], 
    input wire [31:0] vec_b [2:0],
    output wire vec_ready,
    output logic [31:0] value_out [2:0],
    output logic valid_out,
    input wire cross_product_ready
);

logic vec_x_valid;
logic vec_x_ready;
cp_helper cross_vec_x(
    .clk_in(clk_in),
    .valid_in(valid_in),
    .val1_in(vec_a[1]),
    .val2_in(vec_b[2]),
    .val3_in(vec_b[1]),
    .val4_in(vec_a[2]),
    .values_ready(vec_x_ready),
    .value_out(value_out[0]),
    .valid_out(vec_x_valid),
    .cp_ready(cross_product_ready)
);

logic vec_y_valid;
logic vec_y_ready;
cp_helper cross_vec_y(
    .clk_in(clk_in),
    .valid_in(valid_in),
    .val1_in(vec_b[0]),
    .val2_in(vec_a[2]),
    .val3_in(vec_a[0]),
    .val4_in(vec_b[2]),
    .values_ready(vec_y_ready),
    .value_out(value_out[1]),
    .valid_out(vec_y_valid),
    .cp_ready(cross_product_ready)
);

logic vec_z_valid;
logic vec_z_ready;
cp_helper cross_vec_z(
    .clk_in(clk_in),
    .valid_in(valid_in),
    .val1_in(vec_a[0]),
    .val2_in(vec_b[1]),
    .val3_in(vec_b[0]),
    .val4_in(vec_a[1]),
    .values_ready(vec_z_ready),
    .value_out(value_out[2]),
    .valid_out(vec_z_valid),
    .cp_ready(cross_product_ready)
);

logic [2:0] valid_flag;
always_ff @(posedge clk_in ) begin
    if (valid_flag == 'b111) begin
        valid_flag <= 0;
    end else begin
        if (vec_x_valid) begin
            valid_flag[0] <= 1;
        end
        if (vec_y_valid) begin
            valid_flag[1] <= 1;
        end
        if (vec_z_valid) begin
            valid_flag[2] <= 1;
        end
    end
end

assign valid_out = valid_flag == 'b111;
assign vec_ready = vec_x_ready && vec_y_ready && vec_z_ready;
endmodule // cross_product

module cp_wrapper(
    input wire clk_in,
    input wire valid_in,
    input wire [31:0] vec_ax, 
    input wire [31:0] vec_ay, 
    input wire [31:0] vec_az, 
    input wire [31:0] vec_bx,
    input wire [31:0] vec_by,
    input wire [31:0] vec_bz,
    output wire vec_ready,
    output logic [31:0] value_out_x,
    output logic [31:0] value_out_y,
    output logic [31:0] value_out_z,
    output logic valid_out,
    input wire cross_product_ready
); //Takes approximately 225ns to complete 

logic [31:0] vec_a [2:0];
make_vector3 vec_1(
    .vector_x(vec_ax),
    .vector_y(vec_ay),
    .vector_z(vec_az),
    .vector_3(vec_a)
);
logic [31:0] vec_b [2:0];
make_vector3 vec_2(
    .vector_x(vec_bx),
    .vector_y(vec_by),
    .vector_z(vec_bz),
    .vector_3(vec_b)
);

logic [31:0] value_out [2:0];
cross_product crossp(
    .clk_in(clk_in),
    .valid_in(valid_in),
    .vec_a(vec_a), 
    .vec_b(vec_b),
    .vec_ready(vec_ready),
    .value_out(value_out),
    .valid_out(valid_out),
    .cross_product_ready(cross_product_ready)
);

always_comb begin
    value_out_x = value_out[0];
    value_out_y = value_out[1];
    value_out_z = value_out[2];
end

endmodule //cp_wrapper

`default_nettype wire