// Transforms and quantizes a block using the Discrete Cosine Transform
module block_transform(
        input wire rst,
        input wire clk,
        input wire do_compute,
        input logic signed [8:0] data [7:0][7:0],
        output logic signed [7:0] data_out [7:0][7:0],
        input logic is_intra,
        output logic computing,
        output logic output_valid
    );

    logic [5:0] in_xy;
    logic [5:0] out_xy;
    logic [5:0] in_uv;
    logic [5:0] out_uv;
    logic [5:0] res_uv;
    logic [5:0] res_xy;

    logic [2:0] in_x;
    assign in_x = in_xy[5:3];
    logic [2:0] in_y;
    assign in_y = in_xy[2:0];
    logic [2:0] out_x;
    assign out_x = out_xy[5:3];
    logic [2:0] out_y;
    assign out_y = out_xy[2:0];
    logic [2:0] in_u;
    assign in_u = in_uv[5:3];
    logic [2:0] in_v;
    assign in_v = in_uv[2:0];
    logic [2:0] out_u;
    assign out_u = out_uv[5:3];
    logic [2:0] out_v;
    assign out_v = out_uv[2:0];
    logic [2:0] res_u;
    assign res_u = res_uv[5:3];
    logic [2:0] res_v;
    assign res_v = res_uv[2:0];
    logic curoot2;
    assign curoot2 = in_u == 0;
    logic cvroot2;
    assign cvroot2 = in_v == 0;

    logic [63:0] m_a_tdata;
    logic m_a_tvalid;// = 1'b1;
    logic [63:0] m_b_tdata;
    logic m_b_tvalid;// = 1'b1;
    logic [63:0] m_result_tdata;
    logic m_result_tvalid;
    mult_transform mult(
        .aclk(clk),
        .s_axis_a_tdata(m_a_tdata),
        .s_axis_a_tvalid(m_a_tvalid),
        .s_axis_b_tdata(m_b_tdata),
        .s_axis_b_tvalid(m_b_tvalid),
        .m_axis_result_tdata(m_result_tdata),
        .m_axis_result_tvalid(m_result_tvalid)
    );

    logic [63:0] ma_a_tdata;
    logic ma_a_tvalid;// = 1'b1;
    logic [63:0] ma_c_tdata;
    logic ma_c_tvalid;// = 1'b1;
    logic [63:0] ma_result_tdata;
    logic ma_result_tvalid;

    localparam MA_C_DELAY = 15; // 15 cycles for multiplication to finish
    localparam MA_A_DELAY = 9; // 15 cycles for multiplication, minus 6 for float cast

    logic tf_a_tvalid_pipe;
    delay #(.WIDTH(1), .DELAY(MA_A_DELAY)) (
        .clk_in(clk),
        .in(tf_a_tvalid),
        .out(tf_a_tvalid_pipe)
    );
    logic [8:0] tf_a_tdata_pipe;
    delay #(.WIDTH(9), .DELAY(MA_A_DELAY)) (
        .clk_in(clk),
        .in(tf_a_tdata),
        .out(tf_a_tdata_pipe)
    );
    logic ma_c_tvalid_pipe;
    delay #(.WIDTH(1), .DELAY(MA_C_DELAY)) (
        .clk_in(clk),
        .in(ma_c_tvalid),
        .out(ma_c_tvalid_pipe)
    );
    logic [63:0] ma_c_tdata_pipe;
    delay #(.WIDTH(64), .DELAY(MA_C_DELAY)) (
        .clk_in(clk),
        .in(ma_c_tdata),
        .out(ma_c_tdata_pipe)
    );

    logic [8:0] tf_a_tdata;
    logic tf_a_tvalid;
    to_float tf(
        .aclk(clk),
        .s_axis_a_tdata(tf_a_tdata_pipe),
        .s_axis_a_tvalid(tf_a_tvalid_pipe),
        .m_axis_result_tdata(ma_a_tdata),
        .m_axis_result_tvalid(ma_a_tvalid)
    );

    multiply_add_transform ma(
        .aclk(clk),
        .s_axis_a_tdata(ma_a_tdata),
        .s_axis_a_tvalid(ma_a_tvalid),
        .s_axis_b_tdata(m_result_tdata),
        .s_axis_b_tvalid(m_result_tvalid),
        .s_axis_c_tdata(ma_c_tdata_pipe),
        .s_axis_c_tvalid(ma_c_tvalid_pipe),
        .m_axis_result_tdata(ma_result_tdata),
        .m_axis_result_tvalid(ma_result_tvalid)
    );

    logic signed [11:0] r_result_tdata;
    logic r_result_tvalid;
    logic r_result_tuser;
    round_transform round(
        .aclk(clk),
        .s_axis_a_tdata(ma_result_tdata),
        .s_axis_a_tvalid(ma_result_tvalid),
        .m_axis_result_tdata(r_result_tdata),
        .m_axis_result_tvalid(r_result_tvalid),
        .m_axis_result_tuser(r_result_tuser)
    );

    logic [5:0] xu_addr;
    assign xu_addr = { in_x, in_u };
    logic [5:0] yv_addr;
    assign yv_addr = { in_y, in_v };

    logic [6:0] xu_cos_table_addr;
    assign xu_cos_table_addr = { curoot2, xu_addr };
    logic [6:0] yv_cos_table_addr;
    assign yv_cos_table_addr = { cvroot2, yv_addr };

    reg [63:0] cos_table [127:0];
    localparam PI = 3.141592653589793;
    localparam INVROOT2 = 0.7071067811865476;
    generate
    initial
        for(int root2 = 0; root2 < 1; root2 = root2 + 1)
            for(int x = 0; x < 8; x = x + 1)
                for(int u = 0; u < 8; u = u + 1)
                    cos_table[(root2 << 6) + (x << 3) + u] = $realtobits(0.5*(root2 == 0 ? 1.0 : INVROOT2)*$cos(PI*(2.0*real'(x)+ 1.0)*real'(u)/16.0));
    endgenerate

    logic [63:0] transformed_cache [7:0][7:0];

    typedef enum { IDLE, COMPUTE, WAIT_FINISH, WAIT_RESULT, OUTPUT } state_t;
    state_t state;

    assign computing = state != IDLE && state != OUTPUT;

    always_ff @(posedge clk) begin
        if (rst) begin
            in_xy <= 6'b0;
            out_xy <= 6'b0;
            in_uv <= 6'b0;
            out_uv <= 6'b0;
            res_uv <= 6'b0;
            res_xy <= 6'b0;
            tf_a_tdata <= 64'b0;
            ma_c_tdata <= 64'b0;
            m_a_tdata <= 64'b0;
            m_b_tdata <= 64'b0;
            tf_a_tvalid <= 1'b0;
            ma_c_tvalid <= 1'b0;
            m_a_tvalid <= 1'b0;
            m_b_tvalid <= 1'b0;
            output_valid <= 1'b0;
            state <= IDLE;
        end else if (state == IDLE) begin
            if (do_compute) begin
                for(int i = 0; i < 8; i = i + 1) begin
                    for(int j = 0; j < 8; j = j + 1) begin
                        transformed_cache[i][j] <= $realtobits(0.0);
                    end
                end
                state <= COMPUTE;
            end
            in_xy <= 6'b0;
            out_xy <= 6'b0;
            in_uv <= 6'b0;
            out_uv <= 6'b0;
            res_uv <= 6'b0;
            res_xy <= 6'b0;
        end else if (state == OUTPUT) begin
            output_valid <= 1;
            state <= IDLE;
        end else begin
            if(state == COMPUTE) begin // We're currently outputting the results of this x,y block
                m_a_tdata <= cos_table[xu_cos_table_addr];
                m_b_tdata <= cos_table[yv_cos_table_addr];
                tf_a_tdata <= data[in_x][in_y];
                ma_c_tdata <= transformed_cache[in_u][in_v];
                m_a_tvalid <= 1'b1;
                m_b_tvalid <= 1'b1;
                tf_a_tvalid <= 1'b1;
                ma_c_tvalid <= 1'b1;
                in_uv <= in_uv + 1;
                if (in_uv == 6'd63) begin
                    in_xy <= in_xy + 1;
                    if (in_xy == 6'd63) begin
                        state <= WAIT_FINISH;
                    end
                end
            end else begin
                tf_a_tvalid <= 1'b0;
                ma_c_tvalid <= 1'b0;
                m_a_tvalid <= 1'b0;
                m_b_tvalid <= 1'b0;
            end

            if (computing) begin
                // floating point outputs
                if(state != WAIT_RESULT && ma_result_tvalid) begin
                    transformed_cache[out_u][out_v] <= ma_result_tdata;
                    out_uv <= out_uv + 1;
                    if (out_uv == 6'd63) begin
                        out_xy <= out_xy + 1;
                        if (out_xy == 6'd63) begin
                            state <= WAIT_RESULT;
                        end
                    end
                end
                // rounded outputs
                if(r_result_tvalid) begin
                    if (res_xy == 6'd63) // Only update the rounded outputs after everything else
                        data_out[res_u][res_v] <= (
                            (is_intra && res_u == 0 && res_v == 0) ? 
                                (r_result_tdata == $signed(1024) ? 8'hFF : (r_result_tdata >>> 3)) :
                                (r_result_tdata - $signed(7)*(((r_result_tdata >= $signed(0)) <<< 1) - $signed(1))) >>> 4
                        ); // quantize with a fixed quant=8 in H.261
                    res_uv <= res_uv + 1;
                    if (res_uv == 6'd63) begin
                        res_xy <= res_xy + 1;
                        if (res_xy == 6'd63) begin
                            state <= OUTPUT;
                        end
                    end
                end
            end
        end
    end

endmodule