//============================================================================
//============================================================================
//  Xain'd Sleena (Bootleg) for MiSTer FPGA
//
//  Copyright (C) 2022 Francisco Javier Fuentes Moreno @RndMnkIII
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================
`default_nettype none

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
//assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
//assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_F1 = 0;
assign VGA_SCALER  = status[5];

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[2:1];
wire [1:0] scandoubler_fx = status[4:3];
wire orientation = ~status[10];
wire pause_in_osd = status[8];
wire system_pause;

//assign VGA_SL = scandoubler_fx; USED BY arcade_video
assign HDMI_FREEZE = 0; //system_pause;
wire NATIVE_VFREQ = status[9] == 1'd0;


// If video timing changes, force mode update
reg  video_status;
reg new_vmode = 0;
always @(posedge MS_CLK) begin
    if (video_status != status[9]) begin
        video_status <= status[9];
        new_vmode <= ~new_vmode;
    end
end

`include "build_id.v" 
localparam CONF_STR = {
	"XSleenaCore;;",
	"-;",
    "P1,Video Settings;",
    "P1O[2:1],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"P1O[4:3],Scandoubler Fx,None,CRT 25%,CRT 50%,CRT 75%;",
	"P1O[5],VGA Scaler,Off,On;",
	"P1O[6],Flip,Off,On;",
	"P1O[7],Rotate CCW,Off,On;",
    "P1-;",
    "P1O[9],Video Timing,57.44Hz(Native),60Hz(Standard);",
    "P1O[10],Orientation,Horz,Vert;",
    "-;",
    "O[8],OSD Pause,Off,On;",
    "-;",
    "DIP;",
    "-;",
	"T[0],Reset;",
	"R[0],Reset and close OSD;",
	"J1,Shot,Jump,Start P1,Coin,Start P2,Pause;",
	"jn,A,B,Start,R,Select,L;",
	"DEFMRA,/_Arcade/XSleenaBA.mra;",
	"V,v",`BUILD_DATE 
};

wire forced_scandoubler;
wire   [1:0] buttons;
wire [127:0] status;
wire  [10:0] ps2_key;
wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_upload_req = 0;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din = 0;
wire        ioctl_wait;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(MS_CLK),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),
    .gamma_bus(gamma_bus),
    .direct_video(direct_video),

    .forced_scandoubler(forced_scandoubler),
    .new_vmode(new_vmode),
    .video_rotated(video_rotated),

    .buttons(buttons),
    .status(status),
    // .status_menumask({crop_240p, allow_crop_240p, direct_video}),

    .ioctl_download(ioctl_download),
    .ioctl_upload(ioctl_upload),
    .ioctl_upload_req(ioctl_upload_req),
    .ioctl_wr(ioctl_wr),
    .ioctl_addr(ioctl_addr),
    .ioctl_dout(ioctl_dout),
    .ioctl_din(ioctl_din),
    .ioctl_index(ioctl_index),
    .ioctl_wait(ioctl_wait),

    .joystick_0(joystick_0),
    .joystick_1(joystick_1),
    .ps2_key(ps2_key)
);

///////////////////////   CLOCKS   ///////////////////////////////
//wire clk_56p45M;
//wire clk_112p90M;
//wire clk_112p90M_PS;
wire pll_locked;
wire clk_60M;
wire clk_120M;


//10x pixel clock
//n=1, m=5, freq=12.54504 for 62.7252 master clock, 125.4504 SDRAM clock
//n=524, m=2739 w=12, for 60.0 master clock 120MHz SDRAM clock

//9x pixel clock
//56.45268, 112.90536


//native   57.4Hz using 60MHz master clock for 12MHz
//standard 60.0Hz using fractional clock enables for 12.545040MHz
pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(MS_CLK),
	.outclk_1(SDR_CLK),
	.locked(pll_locked)
);

wire reset = RESET | status[0] | buttons[1] | ioctl_download;

wire MS_CLK, SDR_CLK, SDR_PS_CLK;

//////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////
// SDRAM
///////////////////////////////////////////////////////////////////////

//CH1 -> SPRITES
//CH2 -> BG1
//CH3 -> BG2/ROM LOADING INTERFACE
wire [15:0] sdr_obj_dout;
wire [24:0] sdr_obj_addr;
wire sdr_obj_req, sdr_obj_rdy;

wire [15:0] sdr_bg1_dout;
wire [24:0] sdr_bg1_addr;
wire sdr_bg1_req, sdr_bg1_rdy;

// wire [15:0] sdr_cpu_dout, sdr_cpu_din;
wire [15:0] sdr_bg2_dout;
wire [24:0] sdr_bg2_addr;
wire sdr_bg2_req;
//wire [1:0] sdr_cpu_wr_sel;

reg [24:0] sdr_rom_addr;
reg [15:0] sdr_rom_data;
reg [1:0] sdr_rom_be;
reg sdr_rom_req;

wire sdr_rom_write = ioctl_download && (ioctl_index == 0);
// wire [24:0] sdr_ch3_addr = sdr_rom_write ? sdr_rom_addr : sdr_bg2_addr;
wire [24:0] sdr_ch3_addr = sdr_rom_write ? sdr_rom_addr : sdr_bg2_addr;
// wire [15:0] sdr_ch3_din = sdr_rom_write ? sdr_rom_data : sdr_cpu_din;
wire [15:0] sdr_ch3_din = sdr_rom_data;
// wire [1:0] sdr_ch3_be = sdr_rom_write ? sdr_rom_be : sdr_cpu_wr_sel;
wire [1:0] sdr_ch3_be = sdr_rom_be;
// wire sdr_ch3_rnw = sdr_rom_write ? 1'b0 : ~{|sdr_cpu_wr_sel};
wire sdr_ch3_rnw = sdr_rom_write ? 1'b0 : 1'b1; //or ROM downloading or SDRAM ROM read
wire sdr_ch3_req = sdr_rom_write ? sdr_rom_req : sdr_bg2_req;
wire sdr_ch3_rdy;
wire sdr_bg2_rdy = sdr_ch3_rdy;
wire sdr_rom_rdy = sdr_ch3_rdy;

wire [19:0] bram_addr;
wire [7:0] bram_data;
wire [5:0] bram_cs;
wire bram_wr;

//board_cfg_t board_cfg;

sdram sdram
(
    .*,
    .doRefresh(0),
    .init(~pll_locked),
    .clk(SDR_CLK),

    .ch1_addr(sdr_obj_addr[24:1]),
    .ch1_dout(sdr_obj_dout),
    .ch1_req(sdr_obj_req),
    .ch1_ready(sdr_obj_rdy),

    .ch2_addr(sdr_bg1_addr[24:1]),
    .ch2_dout(sdr_bg1_dout),
    .ch2_req(sdr_bg1_req),
    .ch2_ready(sdr_bg1_rdy),

    // multiplexed with rom download and cpu read/writes
    .ch3_addr(sdr_ch3_addr[24:1]),
    .ch3_din(sdr_ch3_din),
    .ch3_dout(sdr_bg2_dout),
    .ch3_be(sdr_ch3_be),
    .ch3_rnw(sdr_ch3_rnw),
    .ch3_req(sdr_ch3_req),
    .ch3_ready(sdr_ch3_rdy)
);

rom_loader rom_loader(
    .sys_clk(MS_CLK),
    .ram_clk(SDR_CLK),

    .ioctl_wr(ioctl_wr && !ioctl_index),
    .ioctl_data(ioctl_dout[7:0]),

    .ioctl_wait(ioctl_wait),

    .sdr_addr(sdr_rom_addr),
    .sdr_data(sdr_rom_data),
    .sdr_be(sdr_rom_be),
    .sdr_req(sdr_rom_req),
    .sdr_rdy(sdr_rom_rdy),

    .bram_addr(bram_addr),
    .bram_data(bram_data),
    .bram_cs(bram_cs),
    .bram_wr(bram_wr),

    .board_cfg()
);

//////////////////////////     CORE     //////////////////////////
logic [3:0] VIDEO_4R;
logic [3:0] VIDEO_4G;
logic [3:0] VIDEO_4B;
logic HBLANK_CORE, VBLANK_CORE;
logic HSYNC_CORE, VSYNC_CORE;
logic  HBlank, VBlank, HSync, VSync;
logic HSYNC, VSYNC;
logic CSYNC;
logic ce_pix;

XSleenaCore xlc (
	.CLK(MS_CLK),
	.SDR_CLK(SDR_CLK),
	.RSTn(~reset),
	.NATIVE_VFREQ(NATIVE_VFREQ),

	//Inputs
	.DSW1(DSW1), // 80 Flip Screen On, 40 Cabinet Cocktail, 20 Allow continue Yes, 10 Demo Sounds On, 0C CoinB 1C/1C, 03 CoinA 1C/1C
	.DSW2(DSW2), //
	.PLAYER1(PLAYER1),
	.PLAYER2(PLAYER2),
	.SERVICE(SERVICE),
	.JAMMA_24(1'b1),
	.JAMMA_b(1'b1),
	//Video output
	.VIDEO_R(VIDEO_4R),
	.VIDEO_G(VIDEO_4G),
	.VIDEO_B(VIDEO_4B),
	.CE_PIXEL(ce_pix),
	.HBLANK(HBLANK_CORE), //NEGATIVE HBLANK
	.VBLANK(VBLANK_CORE), //NEGATIVE VBLANK
	.VSYNC(VSYNC_CORE), //NEGATIVE VSYNC
	.HSYNC(HSYNC_CORE), //NEGATIVE HSYNC
	.CSYNC(CSYNC),
	
	//Memory interface
	//SDRAM
    .sdr_obj_addr(sdr_obj_addr),
    .sdr_obj_dout(sdr_obj_dout),
    .sdr_obj_req(sdr_obj_req),
    .sdr_obj_rdy(sdr_obj_rdy),

    .sdr_bg1_addr(sdr_bg1_addr),
    .sdr_bg1_dout(sdr_bg1_dout),
    .sdr_bg1_req(sdr_bg1_req),
    .sdr_bg1_rdy(sdr_bg1_rdy),

    .sdr_bg2_dout(sdr_bg2_dout),
    .sdr_bg2_addr(sdr_bg2_addr),
    .sdr_bg2_req(sdr_bg2_req),
    .sdr_bg2_rdy(sdr_bg2_rdy),

	//BRAM
    .bram_addr(bram_addr),
    .bram_data(bram_data),
    .bram_cs(bram_cs),
    .bram_wr(bram_wr),

	//sound output
	  .snd1(snd1),
	  .snd2(snd2),
	  .sample(sample),

	//coin counters
	//.CUNT1(CUNT1),
	//.CUNT2(CUNT2),
	 .pause_rq(system_pause)
);

//Audio
logic [15:0] snd1, snd2;
logic sample;
assign AUDIO_S = 1'b1; //Signed audio samples
assign AUDIO_MIX = 2'b11; //0 No Mix, 1 25%, 2 50%, 3 100% mono

//synchronize audio
reg [15:0] snd1_r, snd2_r;
always @(posedge CLK_AUDIO) begin
	snd1_r <= snd1;
	snd2_r <= snd2;
	AUDIO_L <= snd1_r;
	AUDIO_R <= snd2_r;
end

//Reverse polarity of blank/sync signals for MiSTer
assign HBlank=  ~HBLANK_CORE;
assign VBlank=  ~VBLANK_CORE;
assign VSync =  ~VSYNC_CORE;
assign HSync =   HSYNC_CORE;

assign CLK_VIDEO = MS_CLK;

logic [7:0] R, G, B;
XSleenaCore_RGB4bitLUT R_LUT( .COL_4BIT(VIDEO_4R), .COL_8BIT(R));
XSleenaCore_RGB4bitLUT G_LUT( .COL_4BIT(VIDEO_4G), .COL_8BIT(G));
XSleenaCore_RGB4bitLUT B_LUT( .COL_4BIT(VIDEO_4B), .COL_8BIT(B));

// H/V offset
wire [3:0]	hoffset = status[20:17];
wire [3:0]	voffset = status[24:21];

//jtframe_resync jtframe_resync
//(
//	.clk(CLK_VIDEO),
//	.pxl_cen(ce_pix),
//	.hs_in(HSYNC),
//	.vs_in(VSYNC),
//	.LVBL(VBlank),
//	.LHBL(HBlank),
//	.hoffset(hoffset),
//	.voffset(voffset),
//	.hs_out(HSync),
//	.vs_out(VSync)
//);

// wire gamma_hsync, gamma_vsync, gamma_hblank, gamma_vblank;
// wire [7:0] gamma_r, gamma_g, gamma_b;
// gamma_fast video_gamma
// (
//     .clk_vid(CLK_VIDEO),
//     .ce_pix(ce_pix),
//     .gamma_bus(gamma_bus),
//     .HSync(HSync),
//     .VSync(VSync),
//     .HBlank(HBlank),
//     .VBlank(VBlank),
//     .DE(),
//     .RGB_in({R, G, B}),
//     .HSync_out(gamma_hsync),
//     .VSync_out(gamma_vsync),
//     .HBlank_out(gamma_hblank),
//     .VBlank_out(gamma_vblank),
//     .DE_out(),
//     .RGB_out({gamma_r, gamma_g, gamma_b})
// );


assign VIDEO_ARX = (!ar) ? ( no_rotate ? 12'd4 : 12'd3 ) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ( no_rotate ? 12'd3 : 12'd4 ) : 12'd0;
/////////////////////// ARCADE VIDEO /////////////////////////////
wire [21:0] gamma_bus;
wire        direct_video;

// Video rotation 
wire no_rotate = ~status[10];
wire rotate_ccw = status[7];
wire video_rotated;
wire flip = status[6];

arcade_video #(256,24) arcade_video
(
        .*,
		.fx(scandoubler_fx),
		.gamma_bus(),
		.forced_scandoubler(forced_scandoubler),
        .clk_video(MS_CLK),
        .ce_pix(ce_pix),
	    .CE_PIXEL(CE_PIXEL),
	    .RGB_in({R,G,B}),
        .HBlank(HBlank),
        .VBlank(VBlank),
        .HSync(HSync),
        .VSync(VSync)
);

screen_rotate screen_rotate(.*);
/////////////////////////////////////////////////////////////////

// wire VGA_DE_MIXER;
// video_mixer #(256, 0, 0) video_mixer(
//     .CLK_VIDEO(CLK_VIDEO),
//     .CE_PIXEL(CE_PIXEL),
//     .ce_pix(ce_pix),

//     .scandoubler(forced_scandoubler || scandoubler_fx != 2'b00),
//     .hq2x(0),

//     .gamma_bus(),

//     .R(gamma_r),
//     .G(gamma_g),
//     .B(gamma_b),

//     .HBlank(gamma_hblank),
//     .VBlank(gamma_vblank),
//     .HSync(gamma_hsync),
//     .VSync(gamma_vsync),

//     .VGA_R(VGA_R),
//     .VGA_G(VGA_G),
//     .VGA_B(VGA_B),
//     .VGA_VS(VGA_VS),
//     .VGA_HS(VGA_HS),
//     .VGA_DE(VGA_DE_MIXER),

//     .HDMI_FREEZE(HDMI_FREEZE)
// );


// video_freak video_freak(
//     .CLK_VIDEO(CLK_VIDEO),
//     .CE_PIXEL(CE_PIXEL),
//     .VGA_VS(VGA_VS),
//     .HDMI_WIDTH(HDMI_WIDTH),
//     .HDMI_HEIGHT(HDMI_HEIGHT),
//     .VGA_DE(VGA_DE),
//     .VIDEO_ARX(VIDEO_ARX),
//     .VIDEO_ARY(VIDEO_ARY),

//     .VGA_DE_IN(VGA_DE_MIXER),
//     .ARX((!ar) ? ( no_rotate ? 12'd4 : 12'd3 ) : (ar - 1'd1)),
//     .ARY((!ar) ? ( no_rotate ? 12'd3 : 12'd4 ) : 12'd0),
//     .CROP_SIZE(crop_240p ? 240 : 0),
//     .CROP_OFF(crop_offset),
//     .SCALE(scale)
// );

// assign VGA_R = R8B;
// assign VGA_G = G8B;
// assign VGA_B = B8B;
//  assign VGA_HS = HSYNC;
//  assign VGA_VS = VSYNC;
//  assign VGA_DE =  ~(VBLANK | HBLANK); //active low
//  assign CE_PIXEL = ce_pix;



//////////////////////////////////////////////////////////////////


//////////////////////////////////////////////////////////////////


///////////////////         Keyboard           //////////////////

reg btn_up       = 0;
reg btn_down     = 0;
reg btn_left     = 0;
reg btn_right    = 0;
reg btn_1        = 0;
reg btn_2        = 0;
reg btn_coin1    = 0;
reg btn_coin2    = 0;
reg btn_1p_start = 0;
reg btn_2p_start = 0;
reg btn_pause    = 0;
reg btn_service  = 0;

wire pressed = ps2_key[9];
wire [7:0] code = ps2_key[7:0];
always @(posedge MS_CLK) begin
	reg old_state;
	old_state <= ps2_key[10];
	if(old_state != ps2_key[10]) begin
		case(code)
			'h16: btn_1p_start <= pressed; // 1
			'h1E: btn_2p_start <= pressed; // 2
			'h2E: btn_coin1    <= pressed; // 5
			'h36: btn_coin2    <= pressed; // 6
			'h46: btn_service  <= pressed; // 9
			'h4D: btn_pause    <= pressed; // P

			'h75: btn_up      <= pressed; // up
			'h72: btn_down    <= pressed; // down
			'h6B: btn_left    <= pressed; // left
			'h74: btn_right   <= pressed; // right
			'h14: btn_1       <= pressed; // ctrl
			'h11: btn_2       <= pressed; // alt
		endcase
	end
end

//////////////////////// GAME INPUTS ////////////////////////////
//////// Game inputs, the same controls are used for two player alternate gameplay ////////
//Dip Switches
// 8 dip switches of 8 bits
reg [7:0] sw[8];
always @(posedge MS_CLK) begin
    if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) begin
        sw[ioctl_addr[2:0]] <= ioctl_dout;
    end
end

//Added support for multigame core.
reg [7:0] game;
always @(posedge MS_CLK) begin
	if((ioctl_index == 1) && (ioctl_addr == 0)) begin
		game <= ioctl_dout;
	end
end

logic [7:0] DSW1, DSW2;
assign DSW1 = sw[0];
assign DSW2 = sw[1];


//Joysticks
//Player 1
wire m_up1;
wire m_down1;
wire m_left1;
wire m_right1;
wire m_SW1_1;
wire m_SW2_1;
wire m_start1;

//Player 2
wire m_up2;
wire m_down2;
wire m_left2;
wire m_right2;
wire m_SW1_2;
wire m_SW2_2;
wire m_start2;

wire m_coin1, m_coin2;
wire m_pause; //active high

//Xain'd Sleena uses only one set of game controls and 2 start buttons that are needed for play a continue
//wire [15:0] joy = joystick_0 | joystick_1;

assign m_up1       = ~btn_up    & ~joystick_0[3];
assign m_down1     = ~btn_down  & ~joystick_0[2];
assign m_left1     = ~btn_left  & ~joystick_0[1];
assign m_right1    = ~btn_right & ~joystick_0[0];
assign m_SW1_1     = ~btn_1     & ~joystick_0[4];  
assign m_SW2_1     = ~btn_2     & ~joystick_0[5]; 

assign m_up2       = ~btn_up    & ~joystick_1[3];
assign m_down2     = ~btn_down  & ~joystick_1[2];
assign m_left2     = ~btn_left  & ~joystick_1[1];
assign m_right2    = ~btn_right & ~joystick_1[0];
assign m_SW1_2     = ~btn_1     & ~joystick_1[4];  
assign m_SW2_2     = ~btn_2     & ~joystick_1[5]; 

// 4     5      6      7       8     9
//Shot,Jump,Start P1,Coin,Start P2,Pause
assign m_start1    = ~btn_1p_start & ~joy[6]; 
assign m_start2    = ~btn_2p_start & ~joy[8];
assign m_coin1     = ~btn_coin1    & ~joystick_0[7];  
assign m_coin2     = ~btn_coin2    & ~joystick_1[7];  
assign m_pause     =  btn_pause    |  joy[9]; //active high

logic [7:0] PLAYER1, PLAYER2;
logic SERVICE;
//All inputs are active low except SERVICE
//               {2P,1P,1PSW2,1PSW1,1PD,1PU,1PL,1PR}              
assign PLAYER1 = {m_start2,m_start1,m_SW2_1,m_SW1_1,m_down1,m_up1,m_left1,m_right1};
//               {COIN2,COIN1,2PSW2,2PSW1,2PD,2PU,2PL,2PR}             
assign PLAYER2 = {m_coin2 ,m_coin1 ,m_SW2_2,m_SW1_2,m_down2,m_up2,m_left2,m_right2};
assign SERVICE = 1'b1; //Not used in game

//PAUSE
pause #(8,8,8,60) pause ( //R=G=B=8, 60MHz timing
 .clk_sys(MS_CLK),
 .reset(reset),
 .user_button((m_pause)),
 .pause_cpu(system_pause),
 .pause_request(0),
 .options({1'b0, pause_in_osd}),
 .OSD_STATUS(OSD_STATUS)
);
endmodule
