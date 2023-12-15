module smi_device(
    input wire clk_100mhz,
    input logic rst,
    inout wire mdio,
    output logic mdc,
    input logic [4:0] phy_addr,
    input logic [4:0] reg_addr,
    input logic [15:0] in_data,
    input logic do_read,
    input logic do_write,
    output logic [15:0] out_data,
    output logic out_data_valid
    );

    typedef enum { IDLE, PREAMBLE, OP, PHY_ADDR, REG_ADDR, TA, DATA } state_t;

    // Used to generate 1.5625 MHz MDC
    logic [4:0] mdc_counter;

    state_t state;

    localparam [0:33] pre = 35'b1111_1111_1111_1111_1111_1111_1111_1111_01;
    logic [5:0] bit_idx;

    logic [4:0] phy_addr_store;
    logic [4:0] reg_addr_store;
    logic [15:0] in_data_store;
    logic [15:0] out_data_store;

    logic is_read;

    logic mdio_out;
    logic is_mdio_out;
    assign mdio = is_mdio_out ? mdio_out : 1'bz;

    always_ff @(posedge clk_100mhz) begin
        if (rst) begin
            state <= IDLE;
            phy_addr_store <= 0;
            reg_addr_store <= 0;
            in_data_store <= 0;
            bit_idx <= 0;
            is_mdio_out <= 0;
            mdio_out <= 0;
            is_read <= 1;
            mdc <= 0;
            mdc_counter <= 0;
        end else begin
            mdc_counter <= mdc_counter + 1;
            if (mdc_counter == 5'd31) begin
                mdc <= ~mdc;
                if (mdc) begin // change data on falling edge, so it will be ready on rising edge
                    case (state)
                    IDLE: begin
                        if (do_read) begin
                            phy_addr_store <= phy_addr;
                            reg_addr_store <= reg_addr;
                            in_data_store <= in_data;
                            bit_idx <= 0;
                            is_read <= 1;
                            mdio_out = 0;
                            is_mdio_out <= 1;
                            state <= PREAMBLE;
                        end else if(do_write) begin
                            bit_idx <= 0;
                            is_read <= 0;
                            mdio_out <= 0;
                            is_mdio_out <= 1;
                            state <= PREAMBLE;
                        end else begin
                            is_mdio_out <= 0; // keep mdio at high impedance when idle
                        end
                    end PREAMBLE: begin
                        mdio_out <= pre[bit_idx];
                        if (bit_idx == 6'd33) begin
                            bit_idx <= 0;
                            state <= OP;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end OP: begin
                        mdio_out <= (is_read && bit_idx == 6'b0) || (!is_read && bit_idx == 6'b1);
                        if (bit_idx == 6'b1) begin
                            bit_idx <= 0;
                            state <= PHY_ADDR;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end PHY_ADDR: begin
                        mdio_out <= phy_addr_store[6'd4 - bit_idx];
                        if (bit_idx == 6'd4) begin
                            bit_idx <= 0;
                            state <= REG_ADDR;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end REG_ADDR: begin
                        mdio_out <= reg_addr_store[6'd4 - bit_idx];
                        if (bit_idx == 6'd4) begin
                            bit_idx <= 0;
                            state <= TA;
                        end else begin
                            bit_idx <= bit_idx + 1;
                        end
                    end TA: begin
                        if (bit_idx == 6'b1) begin
                            bit_idx <= 0;
                            state <= DATA;
                        end else begin
                            is_mdio_out <= !is_read;
                            bit_idx <= bit_idx + 1;
                        end
                    end DATA: begin
                        if (bit_idx == 6'd15) begin
                            if (is_read) begin
                                out_data <= out_data_store;
                                out_data_valid <= 1;
                            end
                            state <= IDLE;
                        end else begin 
                            if (!is_read) begin
                                mdio_out <= in_data_store[6'd15 - bit_idx];
                            end else begin
                                out_data_store[6'd15 - bit_idx] <= mdio;
                            end
                            bit_idx <= bit_idx + 1;
                        end
                    end
                    endcase
                end
            end
        end
    end
endmodule