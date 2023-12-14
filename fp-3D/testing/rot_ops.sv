`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)

//Two options, create sine lookup table using BRAM or calculate it with IP.
// First might be better, from 6.115 intuition

module make_mat3 (
    input wire [31:0] r1c1,
    input wire [31:0] r1c2,
    input wire [31:0] r1c3,
    input wire [31:0] r2c1,
    input wire [31:0] r2c2,
    input wire [31:0] r2c3,
    input wire [31:0] r3c1,
    input wire [31:0] r3c2,
    input wire [31:0] r3c3,
    output logic [31:0] mat3_c1 [2:0];
    output logic [31:0] mat3_c2 [2:0]; 
    output logic [31:0] mat3_c3 [2:0]; 
);
always_comb begin
    mat3_c1[0] = r1c1;
    mat3_c1[1] = r1c2;
    mat3_c1[2] = r1c3;

    mat3_c2[0] = r2c1;
    mat3_c2[1] = r2c2;
    mat3_c2[2] = r2c3;

    mat3_c3[0] = r3c1;
    mat3_c3[1] = r3c2;
    mat3_c3[2] = r3c3;
end
endmodule //make_mat3

module mvmul (
    input wire clk_in,
    input wire valid_in,
    input wire [31:0] mat_a1 [2:0], //col 1 of matrix a 
    input wire [31:0] mat_a2 [2:0], //col 2 of matrix a
    input wire [31:0] mat_a3 [2:0], //col 3 of matrix a
    input wire [31:0] vec_b [2:0],
    output logic [31:0] vec_out [2:0],
    output logic valid_out,
    input wire mvmul_ready
);

//Looks like r(i) dot b for each index i
localparam MAT_SIZE = 3;
generate
    genvar i;
    for (i=0; i<MAT_SIZE; i=i+1) begin: dot_product
        logic [31:0] row [2:0];
        always_comb begin
            row[0] = mat_a1[i];
            row[1] = mat_a2[i];
            row[2] = mat_a3[i];
        end

        logic [31:0] result;
        logic result_valid;
        logic vectors_ready;

        dot_product product (
            .clk_in(clk_in),
            .valid_in(valid_in),
            .vector1(row), 
            .vector2(vec_b),
            .vectors_ready(vectors_ready),
            .value_out(vec_out[i]),
            .valid_out(result_valid),
            .dot_product_ready(mvmul_ready)
        );
    end
endgenerate
endmodule //mvmul

// 2 3x3 matrix mul, looks like dot product of desired row and column

module mtvmul (
    ports
);
//Looks like each col(i) dot b for each index i
endmodule //mtvmul

`default_nettype wire