`timescale 1ns / 1ps
`default_nettype none

/*
Given two positive integer pixel locations a, b, return the corresponding vector ab
*/
module p2v_wrap #(
    parameter SYS_BIT_WIDTH = 32
) (
    input wire [SYS_BIT_WIDTH-1:0] point_ax,
    input wire [SYS_BIT_WIDTH-1:0] point_ay,
    input wire [SYS_BIT_WIDTH-1:0] point_bx,
    input wire [SYS_BIT_WIDTH-1:0] point_by,
    output logic signed [SYS_BIT_WIDTH:0] vec_ab_out_x,
    output logic signed [SYS_BIT_WIDTH:0] vec_ab_out_y
);
    always_comb begin 
        vec_ab_out_x = point_bx - point_ax;
        vec_ab_out_y = point_by - point_ay; 
    end
    
endmodule

/*
Given two 2d vectors with integer coordinates, return the corresponding cross product
*/
module cp_helper_wrap #(
    parameter SYS_BIT_WIDTH = 32
) (
    input wire clk_in,
    input wire valid_in,
    input wire [SYS_BIT_WIDTH:0] vec_ax,
    input wire [SYS_BIT_WIDTH:0] vec_ay,
    input wire [SYS_BIT_WIDTH:0] vec_bx,
    input wire [SYS_BIT_WIDTH:0] vec_by,
    output logic valid_out,
    output logic signed [SYS_BIT_WIDTH+SYS_BIT_WIDTH:0] value_out
);
    logic signed [SYS_BIT_WIDTH:0] vec_a [1:0];
    logic signed [SYS_BIT_WIDTH:0] vec_b [1:0];
    logic signed [SYS_BIT_WIDTH+SYS_BIT_WIDTH:0] multiples [1:0]; 
    //might need one more bit here if substrend is negative while number is positive or vice versa
    logic state;

    always_comb begin 
        vec_a[0] = vec_ax;
        vec_a[1] = vec_ay;
        vec_b[0] = vec_bx;
        vec_b[1] = vec_by;
    end

    always_ff @( posedge clk_in ) begin
        if (valid_out) begin
            valid_out <= 0;
        end

        if (valid_in) begin
            multiples[0] <= vec_a[0] * vec_b[1];
            multiples[1] <= vec_a[1] * vec_b[0];
            state <= 1;
        end else if (state == 1) begin
            valid_out <= 1;
            value_out <= multiples[0] - multiples[1];
            state <= 0;
        end

    end
endmodule


module in_triangle #(
    parameter SYS_BIT_WIDTH = 32
) (
    input wire clk_in,
    input wire valid_in,
    input wire [SYS_BIT_WIDTH-1:0] vertex_a [1:0],
    input wire [SYS_BIT_WIDTH-1:0] vertex_b [1:0],
    input wire [SYS_BIT_WIDTH-1:0] vertex_c [1:0],
    input wire [SYS_BIT_WIDTH-1:0] point [1:0],
    output logic valid_out,
    output logic is_inside
);
    logic signed [SYS_BIT_WIDTH:0] vec_AB [1:0];
    logic signed [SYS_BIT_WIDTH:0] vec_AC [1:0];
    logic signed [SYS_BIT_WIDTH:0] vec_PA [1:0];
    logic signed [SYS_BIT_WIDTH:0] vec_PB [1:0];
    logic signed [SYS_BIT_WIDTH:0] vec_PC [1:0];

    logic signed [SYS_BIT_WIDTH+SYS_BIT_WIDTH:0] ka_constant;
    logic signed [SYS_BIT_WIDTH+SYS_BIT_WIDTH:0] kb_constant;
    logic signed [SYS_BIT_WIDTH+SYS_BIT_WIDTH:0] d_constant;

    // Calculate vectors AB and AC
    p2v_wrap #(.SYS_BIT_WIDTH(SYS_BIT_WIDTH)) ab (
        .point_ax(vertex_a[0]),
        .point_ay(vertex_a[1]),
        .point_bx(vertex_b[0]),
        .point_by(vertex_b[1]),
        .vec_ab_out_x(vec_AB[0]),
        .vec_ab_out_y(vec_AB[1])
    );

    p2v_wrap #(.SYS_BIT_WIDTH(SYS_BIT_WIDTH)) ac (
        .point_ax(vertex_a[0]),
        .point_ay(vertex_a[1]),
        .point_bx(vertex_c[0]),
        .point_by(vertex_c[1]),
        .vec_ab_out_x(vec_AC[0]),
        .vec_ab_out_y(vec_AC[1])
    );

    p2v_wrap #(.SYS_BIT_WIDTH(SYS_BIT_WIDTH)) pa (
        .point_ax(point[0]),
        .point_ay(point[1]),
        .point_bx(vertex_a[0]),
        .point_by(vertex_a[1]),
        .vec_ab_out_x(vec_PA[0]),
        .vec_ab_out_y(vec_PA[1])
    );

    p2v_wrap #(.SYS_BIT_WIDTH(SYS_BIT_WIDTH)) pb (
        .point_ax(point[0]),
        .point_ay(point[1]),
        .point_bx(vertex_b[0]),
        .point_by(vertex_b[1]),
        .vec_ab_out_x(vec_PB[0]),
        .vec_ab_out_y(vec_PB[1])
    );

    p2v_wrap #(.SYS_BIT_WIDTH(SYS_BIT_WIDTH)) pc (
        .point_ax(point[0]),
        .point_ay(point[1]),
        .point_bx(vertex_c[0]),
        .point_by(vertex_c[1]),
        .vec_ab_out_x(vec_PC[0]),
        .vec_ab_out_y(vec_PC[1])
    );

    // Calculate ka = ||PB X PC||
    logic ka_valid;
    cp_helper_wrap #(.SYS_BIT_WIDTH(SYS_BIT_WIDTH)) ka (
        .clk_in(clk_in),
        .valid_in(valid_in),
        .vec_ax(vec_PB[0]),
        .vec_ay(vec_PB[1]),
        .vec_bx(vec_PC[0]),
        .vec_by(vec_PC[1]),
        .valid_out(ka_valid),
        .value_out(ka_constant)
    );

    // Calculate kb = ||PC X PA||
    logic kb_valid;
    cp_helper_wrap #(.SYS_BIT_WIDTH(SYS_BIT_WIDTH)) kb (
        .clk_in(clk_in),
        .valid_in(valid_in),
        .vec_ax(vec_PC[0]),
        .vec_ay(vec_PC[1]),
        .vec_bx(vec_PA[0]),
        .vec_by(vec_PA[1]),
        .valid_out(kb_valid),
        .value_out(kb_constant)
    );

    // Calculate d = ||AB X AC||
    logic d_valid;
    cp_helper_wrap #(.SYS_BIT_WIDTH(SYS_BIT_WIDTH)) d (
        .clk_in(clk_in),
        .valid_in(valid_in),
        .vec_ax(vec_AB[0]),
        .vec_ay(vec_AB[1]),
        .vec_bx(vec_AC[0]),
        .vec_by(vec_AC[1]),
        .valid_out(d_valid),
        .value_out(d_constant)
    );

    logic pos_a;
    logic pos_b;

    logic signed [SYS_BIT_WIDTH+SYS_BIT_WIDTH:0] d_abs;
    logic signed [SYS_BIT_WIDTH+SYS_BIT_WIDTH+1:0] f_constant;
    logic [SYS_BIT_WIDTH+SYS_BIT_WIDTH+1:0] f_abs;
    logic f_valid;
    logic signed [SYS_BIT_WIDTH+SYS_BIT_WIDTH+2:0] c_check;
    logic c_check_valid;

    logic complete;


    localparam sign_idx = SYS_BIT_WIDTH + SYS_BIT_WIDTH;
    always_comb begin
        pos_a = (ka_constant[sign_idx] == d_constant[sign_idx]) || (ka_constant == 0);
        pos_b = (kb_constant[sign_idx] == d_constant[sign_idx]) || (kb_constant == 0);
        f_abs = f_constant[sign_idx+1] == 1 ?  0 - f_constant : f_constant;
        d_abs = d_constant[sign_idx] == 1 ?  0 - d_constant : d_constant;
    end

    always_ff @(posedge clk_in ) begin

        if (valid_out) begin
            valid_out <= 0;
        end

        if (valid_in) begin // is this a valid condition?
            complete <= 0;
            valid_out <= 0;
        end

        if (ka_valid && kb_valid && d_valid) begin
            if (!pos_a || !pos_b) begin
                valid_out <= 1;
                is_inside <= 0;
                complete <= 1;
            end else begin
                f_constant <= ka_constant + kb_constant;
                f_valid <= 1;
            end

        end else if (f_valid) begin
            if (f_constant == d_constant) begin
                valid_out <= 1;
                is_inside <= 1;
                complete <= 1;
            end else begin // d - f (subtraction not being done correctly)
                if (!f_constant[sign_idx+1] && d_constant[sign_idx]) begin
                    c_check <= 0 - (d_abs + f_abs);
                end else if (!f_constant[sign_idx+1] && d_constant[sign_idx]) begin
                    c_check <= f_abs + d_abs;
                end else begin
                    c_check <= d_constant - f_constant;
                end
                c_check_valid <= 1;
            end
            is_inside <= c_check[sign_idx+2] == d_constant[sign_idx];
            valid_out <= 1;
            complete <= 1;
        end
    end
endmodule

module in_triangle_wrap #(
    parameter SYS_BIT_WIDTH = 32
) (
    input wire clk_in,
    input wire valid_in,
    input wire [SYS_BIT_WIDTH-1:0] vertex_ax,
    input wire [SYS_BIT_WIDTH-1:0] vertex_ay,
    input wire [SYS_BIT_WIDTH-1:0] vertex_bx,
    input wire [SYS_BIT_WIDTH-1:0] vertex_by,
    input wire [SYS_BIT_WIDTH-1:0] vertex_cx,
    input wire [SYS_BIT_WIDTH-1:0] vertex_cy,
    input wire [SYS_BIT_WIDTH-1:0] point_x,
    input wire [SYS_BIT_WIDTH-1:0] point_y,
    output logic valid_out,
    output logic is_inside
);
    logic [SYS_BIT_WIDTH-1:0] vertex_a [1:0];
    logic [SYS_BIT_WIDTH-1:0] vertex_b [1:0];
    logic [SYS_BIT_WIDTH-1:0] vertex_c [1:0];
    logic [SYS_BIT_WIDTH-1:0] point [1:0];

    always_comb begin 
        vertex_a[0] = vertex_ax;
        vertex_a[1] = vertex_ay;
        vertex_b[0] = vertex_bx;
        vertex_b[1] = vertex_by;
        vertex_c[0] = vertex_cx;
        vertex_c[1] = vertex_cy;
        point[0] = point_x;
        point[1] = point_y;
    end

    in_triangle #(.SYS_BIT_WIDTH(SYS_BIT_WIDTH)) triangle (
        .clk_in(clk_in),
        .valid_in(valid_in),
        .vertex_a(vertex_a),
        .vertex_b(vertex_b),
        .vertex_c(vertex_c),
        .point(point),
        .valid_out(valid_out),
        .is_inside(is_inside)
    );

endmodule
