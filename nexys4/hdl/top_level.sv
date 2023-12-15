`default_nettype none

module top_level(
    input wire clk_100mhz,
    input wire [15:0] sw,
    input wire btnc,
    input wire eth_crsdv,
    input wire eth_rxd[1:0],
    output logic [15:0] led,
    output logic eth_refclk,
    output logic eth_rstn,
    output logic [1:0] ja,
    output logic eth_txen,
    output logic [1:0] eth_txd,
    inout wire eth_mdio,
    output logic eth_mdc
    );

    logic rst;
    assign rst = sw[0];
    assign eth_rstn = ~rst;

    always_ff @(posedge clk_100mhz) begin
        eth_refclk <= ~eth_refclk;
    end

    // Logic for reading/writing from the registers of the Ethernet PHY
    /*logic [4:0] phy_addr = 5'b00001;
    logic [4:0] mdio_reg_addr;
    logic mdio_read, mdio_write;
    logic [15:0] mdio_in_data;
    logic [15:0] mdio_out_data;
    logic mdio_out_data_valid;
    
    logic restart_auto_neg = btnc;

    always_ff @(posedge clk_100mhz) begin
        if(rst) begin
            led <= 16'b0;
            mdio_read <= 0;
            mdio_write <= 0;
            mdio_in_data <= 0;
            mdio_reg_addr <= 0;
        end else begin
            if(mdio_out_data_valid)
                led <= mdio_out_data;
            if(restart_auto_neg) begin
                mdio_write <= 1;
                mdio_read <= 0;
                mdio_in_data <= 16'b00010010_00000000;
                mdio_reg_addr <= 5'b00000;
            end else begin
                mdio_write <= 0;
                mdio_read <= 1;
                mdio_reg_addr <= sw[5:1];
            end
        end
    end

    smi_device eth_smi(
        .clk_100mhz(clk_100mhz),
        .rst(rst),
        .mdio(eth_mdio),
        .mdc(eth_mdc),
        .phy_addr(phy_addr),
        .reg_addr(mdio_reg_addr),
        .do_read(mdio_read),
        .do_write(mdio_write),
        .in_data(mdio_in_data),
        .out_data(mdio_out_data),
        .out_data_valid(mdio_out_data_valid)
    );*/

   /* logic waiting_rtp;
    logic rtp_sending;
    logic rtp_in_valid;
    logic [15:0] rtp_send_count;
    always_ff @(posedge clk_100mhz) begin
        if (rst || sw[15]) begin
            rtp_in_valid <= 0;
            rtp_prepare_for_data <= 0;
            waiting_rtp <= 0;
            rtp_sending <= 0;
            rtp_send_count <= 0;
        end else begin
            if (rtp_sending) begin
                rtp_in_valid <= 1;
                rtp_send_count <= rtp_send_count + 1;
                if (rtp_send_count == rtp_payload_size - 1) begin
                    rtp_send_count <= 0;
                    rtp_sending <= 0;
                end
           end else begin
            rtp_in_valid <= 0;
            if (waiting_rtp) begin
                if (rtp_ready_for_data) begin
                    rtp_sending <= 1;
                    waiting_rtp <= 0;
                end
                rtp_prepare_for_data <= 0;
            end else if (~eth_busy) begin
                rtp_prepare_for_data <= 1;
                waiting_rtp <= 1;
            end
          end
        end
    end*/

    logic [31:0] packet_timestamp;

    logic stream;
    logic stream_valid;
    packetizer packetizer_m(
        .rst(rst || sw[15]),
        .clk_100mhz(clk_100mhz),
        .stream_out(stream),
        .stream_out_valid(stream_valid),
        .ready_out(rtp_ready_for_data),
        .prepare_out(rtp_prepare_for_data),
        .packet_nbits(rtp_payload_size),
        .packet_timestamp(packet_timestamp),
        .eth_busy(eth_busy)
    );

    logic [15:0] rtp_payload_size;// = 64*8;
    logic rtp_ready_for_data;
    logic rtp_prepare_for_data;
    BitwiseRTPModule rtp_sender (
        .clk_in(clk_100mhz),
        .rst_in(rst),
        .data_in(stream),
        .data_valid_in(stream_valid),
        .prepare_for_data(rtp_prepare_for_data),
        .payload_size(rtp_payload_size),
        .rtp_timestamp(packet_timestamp),
        .rtp_marker_in(1'b0),
        .data_out(eth_data),
        .valid_out(eth_data_valid),
        .ready_for_data(rtp_ready_for_data),
        .send_out(eth_send_data)
    );

    logic [7:0] eth_data;
    logic eth_data_valid;
    logic eth_send_data;
    logic eth_busy;

    localparam MAC_DEST = 48'hff_ff_ff_ff_ff_ff;
    logic [3:0] eth_debug_state;
    
    mac_transmit mac_transmitter (
        .rst(rst),
        .clk_100mhz(clk_100mhz),
        .eth_refclk(eth_refclk),
        .eth_txen(eth_txen),
        .eth_txd(eth_txd),
        .send_data(eth_send_data), // when asserted, sends the data
        .data_in(eth_data),
        .data_valid_in(eth_data_valid),
        .mac_dest(MAC_DEST),
        .busy(eth_busy),
        .debug_state(eth_debug_state)
    );

endmodule

`default_nettype wire