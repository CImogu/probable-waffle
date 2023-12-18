`timescale 1ns / 1ps
`default_nettype none

module top_level(
  input wire clk_100mhz, //
  input wire [15:0] sw, //all 16 input slide switches
  input wire [3:0] btn, //all four momentary button switches
  output logic [15:0] led, //16 green output LEDs (located right above switches)
  output logic [2:0] rgb0, //rgb led
  output logic [2:0] rgb1, //rgb led
  output logic [2:0] hdmi_tx_p, //hdmi output signals (blue, green, red)
  output logic [2:0] hdmi_tx_n, //hdmi output signals (negatives)
  output logic hdmi_clk_p, hdmi_clk_n, //differential hdmi clock

  output logic [6:0] ss0_c,
  output logic [6:0] ss1_c,
  output logic [3:0] ss0_an,
  output logic [3:0] ss1_an,

  input wire [7:0] pmoda,
  input wire [2:0] pmodb,
  output logic pmodbclk,
  output logic pmodblock
  );

  assign led = sw;
  //shut up those rgb LEDs (active high):
  assign rgb1= 0;
  assign rgb0 = 0;
  /* have btnd control system reset */
  logic sys_rst;
  assign sys_rst = btn[0];

  //Clocking Variables:
  logic clk_pixel, clk_5x; //clock lines
  logic locked; //locked signal (we'll leave unused but still hook it up)

  //clock manager...creates 74.25 Hz and 5 times 74.25 MHz for pixel and TMDS
  hdmi_clk_wiz_720p mhdmicw (.clk_pixel(clk_pixel),.clk_tmds(clk_5x),
          .reset(0), .locked(locked), .clk_ref(clk_100mhz));

  //signals related to driving the video pipeline
  logic [10:0] hcount;
  logic [9:0] vcount;
  logic vert_sync;
  logic hor_sync;
  logic active_draw;
  logic new_frame;
  logic [5:0] frame_count;

  //from week 04! (make sure you include in your hdl)
  video_sig_gen mvg(
      .clk_pixel_in(clk_pixel),
      .rst_in(sys_rst),
      .hcount_out(hcount),
      .vcount_out(vcount),
      .vs_out(vert_sync),
      .hs_out(hor_sync),
      .ad_out(active_draw),
      .nf_out(new_frame),
      .fc_out(frame_count));

  //random number generator using lsfr_16 module
  logic [15:0] q;
  lfsr_16 random_num (
    .clk_in(clk_pixel),
    .rst_in(sys_rst),
    .seed_in(16'b1),
    .q_out(q)
  );

  logic [7:0] img_red, img_green, img_blue;

  //x_com and y_com are the image sprite locations
  logic [10:0] x_com;
  logic [9:0] y_com;
  logic pop;
  //update center of mass x_com, y_com based on new_com signal
  always_ff @(posedge clk_pixel)begin
    if (sys_rst)begin
      x_com <= 0;
      y_com <= 0;
    end else if(btn[1])begin
      //do some random stuff here to popocat
      x_com <= (q[15:9] << 3);
      y_com <= (q[8:3] << 3);
      pop <= q[2];
    end
  end

localparam max_count = 50000;
logic [13:0] clk_count;

always_ff @(posedge clk_100mhz) begin
    if (sys_rst) begin
        clk_count <= 0;
    end else begin
        if (clk_count == (max_count - 1)) begin
            clk_count <= 0;
            data_valid_in <= 1;
        end else begin
            clk_count <= clk_count + 1;
            data_valid_in <= 0;
        end
    end
end

logic [20:0] obj_location [5:0];
always_comb begin
    obj_location[0] = {11'd5, 10'd4};
    obj_location[1] = {11'd5, 10'd4};
    obj_location[2] = {11'd7, 10'd4};
    obj_location[3] = {11'd7, 10'd4};
    obj_location[4] = {11'd14, 10'd6};
    obj_location[5] = {11'd14, 10'd6};
end

displaying com_screen(
    .clk_in(clk_100mhz),
    .rst_in(sys_rst),
    .valid_in(data_valid_in),
    .game_obj_loc(obj_location),
    .pixel_clk_in(clk_pixel),
    .hcount_in(hcount),
    .vcount_in(vcount),
    .red_out(img_red),
    .green_out(img_green),
    .blue_out(img_blue)
);

  logic [7:0] red, green, blue;

  assign red = img_red;
  assign green = img_green;
  assign blue = img_blue;

  logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder!
  logic tmds_signal [2:0]; //output of each TMDS serializer!

  //three tmds_encoders (blue, green, red)
  //blue should have {vert_sync and hor_sync for control signals)
  //red and green have nothing
  tmds_encoder tmds_red(
    .clk_in(clk_pixel),
    .rst_in(sys_rst),
    .data_in(red),
    .control_in(2'b0),
    .ve_in(active_draw),
    .tmds_out(tmds_10b[2]));

  tmds_encoder tmds_green(
    .clk_in(clk_pixel),
    .rst_in(sys_rst),
    .data_in(green),
    .control_in(2'b0),
    .ve_in(active_draw),
    .tmds_out(tmds_10b[1]));

  tmds_encoder tmds_blue(
    .clk_in(clk_pixel),
    .rst_in(sys_rst),
    .data_in(blue),
    .control_in({vert_sync,hor_sync}),
    .ve_in(active_draw),
    .tmds_out(tmds_10b[0]));

  //four tmds_serializers (blue, green, red, and clock)
  tmds_serializer red_ser(
    .clk_pixel_in(clk_pixel),
    .clk_5x_in(clk_5x),
    .rst_in(sys_rst),
    .tmds_in(tmds_10b[2]),
    .tmds_out(tmds_signal[2]));

  tmds_serializer green_ser(
    .clk_pixel_in(clk_pixel),
    .clk_5x_in(clk_5x),
    .rst_in(sys_rst),
    .tmds_in(tmds_10b[1]),
    .tmds_out(tmds_signal[1]));

  tmds_serializer blue_ser(
    .clk_pixel_in(clk_pixel),
    .clk_5x_in(clk_5x),
    .rst_in(sys_rst),
    .tmds_in(tmds_10b[0]),
    .tmds_out(tmds_signal[0]));

  //output buffers generating differential signal:
  OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
  OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
  OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
  OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));

  assign ss0_c = 0; //ss_c; //control upper four digit's cathodes!
  assign ss1_c = 0; //ss_c; //same as above but for lower four digits!

endmodule // top_level


`default_nettype wire
