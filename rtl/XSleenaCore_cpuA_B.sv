//XSleenaCore_cpuA.sv
//Author: @RndMnkIII
//Date: 11/10/2022
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

`default_nettype none
`timescale 1ns/10ps

module XSleenaCore_cpuA_B (
	input wire clk, //48MHz
	input wire clk12M_cen,
  	input wire RSTn,
	input wire VBLK,
	input wire W3A09n,
	input wire W3A0Bn,
	input wire IMS,
	input wire W3A0An,
	input wire W3A0Cn, //cpuB
	input wire M2H, //clock
	input wire M2Hn,//clock
	input wire M1H, //clock
	input wire M1Hn, //clock
	input wire HCLK, //clock
	input wire BSL, //ROM BANK Switch in 0x4000-0x7fff CPU address space
	//outputs
	output logic [14:0] AB, //maincpu address bus, range: 0x000-0x7fff
	output logic RW, //maincpu RW
	input wire [7:0] DB_in,
	output logic [7:0] DB_out,
	output logic MAPSELn,
	output logic BACK1SELn,
	output logic BACK2SELn,
	output logic OBJSELn,
	output logic IOn,
	output logic PLSELn,
	output logic WDn,
	//ROM interface
    input bram_wr,
    input [7:0] bram_data,
    input [19:0] bram_addr,
    input [1:0] bram_cs,
	input wire pause_rq
);
//  -----------------------------------------------------------------------------------------------------------------------------------------------
// |                              Diagram of interconnection of the Main and Secondary CPUs with the Shared SRAM                                   |
// |-----------------------------------------------------------------------------------------------------------------------------------------------|
// |                                                                                                                EN, 1CLK PERIOD DLY            |
// |                                                                                                                |/                             |
// |                                   EN, 1CLK PERIOD DLY                                                          | <-- 8'hFF (replaces hi-Z)    |
// |     ---------                     |                                                                            | <-- MAP_DOUT                 |
// |    |         | ---> MAINCPU_DOUT -+-> MAINCPU_DOUT_EXT --> ... to another subsystems   /                       | <-- BACK1_DOUT               |
// |    | MAINCPU |                                              |                         | <-- IC65_ROM_DOUT      | <-- BACK2_DOUT               |
// |    |         | <--- MAINCPU_DIN ------------<--------------------------<-------------<  <-- IC66_ROM_DOUT      | <-- OBJ_DOUT                 |
// |     ---------                                               |                         | <-- MAINCPU_DIN_EXT--+<  <-- IO_P1_DOUT               |
// |                                                             V    EN, 1CLK PERIOD DLY   \                       | <-- IO_P2_DOUT               |
// |                                                             |    |                                             | <-- IO_DIP1_DOUT             |
// |                                                             |----+-> SHARED_SRAM_DIN_EXT-----------            | <-- IO_DIP2_DOUT             |
// |                                                                                                    |           | <-- IO_STATUS_DOUT           |
// |                                                                                                    |           | <-- SHARED_SRAM_DOUT_EXT _   |
// |                                                                                                    V            \                          |  |
// |                                                                                                    |   ___________________>________________|  |
// |                                                                                                    |  |                                       |
// |                           ___>________________________________>____________________________________|__|____                                   |
// |                          |           EN, 1CLK PERIOD DLY            _____________>_________________|__|    |                                  |
// |     --------             |           |                             |                               |       |                                  |
// |    | SHARED | ---> SHARED_SRAM_DOUT -+-> SHARED_SRAM_DOUT_EXT _____|     /                         |       |                                  |
// |    |  SRAM  |                                                           | <-- SHARED_SRAM_DIN_EXT--        |                                  |
// |    |        | <--- SHARED_SRAM_DIN -----------------<------------------<  <-- SUBCPU_DOUT_EXT _______      |                                  |
// |     --------                                                            | <-- 8'hFF (replaces hi-Z)  |     |                                  |
// |         -------------------------                                        \                           ^     |                                  | 
// |        | SUB ROM BANK SWITCH REG |                           ____________________>___________________|     V                                  |
// |         ------------^------------                           |                                              |                                  |
// |                     |           EN, 1CLK PERIOD DLY         ^                                              |                                  |
// |    --------         |           |                           |                                              |                                  |
// |   |        | ---> SUBCPU_DOUT2 -+-> SUBCPU_DOUT_EXT ____>___|   /                                          |                                  |
// |   | SUBCPU |                                                   | <-- IC29_ROM_DOUT    EN, 1CLK PERIOD DLY  |                                  |
// |   |        | <--- SUBCPU_DIN --------------<------------------<  <-- IC15_ROM_DOUT    |                    |                                  |
// |    --------                                                    | <-- SUBCPU_DIN_EXT <-+- SHARED_SRAM_DOUT _|                                  |
// |                                                                | <-- 8'hFF (replaces hi-Z)                                                    |
// |                                                                 \                                                                             |
//  -----------------------------------------------------------------------------------------------------------------------------------------------
	
	logic [7:0] MAINCPU_EXT_Din, MAINCPU_EXT_Dout;
	logic [7:0] SHARED_SRAM_EXT_Din, SHARED_SRAM_EXT_Dout;
	logic [7:0] SUBCPU_EXT_Din, SUBCPU_EXT_Dout;
	logic [7:0] SHARED_SRAM_Dout, SHARED_SRAM_Din;

//**************************************
// *** Main CPU (Schematics page 1B) ***
//**************************************
	logic IRQ2n;
	logic COMRn;
	logic Q2;

	logic ic100A_Qn;
	// ttl_7474 #(.BLOCKS(1), .DELAY_RISE(10), .DELAY_FALL(10)) ic100A
	// (.Clear_bar(W3A09n), .Preset_bar(1'b1), .D(1'b1), .Clk(VBLK), .Q(), .Q_bar(ic100A_Qn)); //maincpu NMIn
	DFF_pseudoAsyncClrPre #(.W(1)) ic100A ( //maincpu NMIn
		.clk(clk),
		.din(1'b1),
		.q(),
		.qn(ic100A_Qn),
		.set(1'b0),    // active high
		.clr(~W3A09n),    // active high
		.cen(VBLK) // signal whose edge will trigger the FF
  	);

	logic ic100B_Qn;
	// ttl_7474 #(.BLOCKS(1), .DELAY_RISE(10), .DELAY_FALL(10)) ic100B
	// (.Clear_bar(W3A0Bn), .Preset_bar(1'b1), .D(1'b1), .Clk(IRQ2n), .Q(), .Q_bar(ic100B_Qn)); //maincpu IRQn
	DFF_pseudoAsyncClrPre #(.W(1)) ic100B ( //maincpu IRQn
		.clk(clk),
		.din(1'b1),
		.q(),
		.qn(ic100B_Qn),
		.set(1'b0),    // active high
		.clr(~W3A0Bn),    // active high
		.cen(IRQ2n) // signal whose edge will trigger the FF
  	);

	logic ic87A_Qn;
	// ttl_7474 #(.BLOCKS(1), .DELAY_RISE(10), .DELAY_FALL(10)) ic87A
	// (.Clear_bar(W3A0An), .Preset_bar(1'b1), .D(1'b1), .Clk(IMS), .Q(), .Q_bar(ic87A_Qn)); //maincpu FIRQn
	DFF_pseudoAsyncClrPre #(.W(1)) ic87A ( //maincpu FIRQn
		.clk(clk),
		.din(1'b1),
		.q(),
		.qn(ic87A_Qn),
		.set(1'b0),    // active high
		.clr(~W3A0An),    // active high
		.cen(IMS) // signal whose edge will trigger the FF
  	);

	logic ic87B_Q;
	// ttl_7474 #(.BLOCKS(1), .DELAY_RISE(10), .DELAY_FALL(10)) ic87B
	// (.Clear_bar(1'b1), .Preset_bar(1'b1), .D(M2H), .Clk(M1H), .Q(ic87B_Q), .Q_bar(Q2)); //Q -> maincpu Q clock, Qn -> IRQ2n
	DFF_pseudoAsyncClrPre #(.W(1)) ic87B ( //Q -> maincpu Q clock, Qn -> IRQ2n
		.clk(clk),
		.din(M2H),
		.q(ic87B_Q),
		.qn(Q2),
		.set(1'b0),    // active high
		.clr(1'b0),    // active high
		.cen(M1H) // signal whose edge will trigger the FF
  	);

	logic ic76d; //NOT gate
	assign ic76d = ~M2H; //maincpu E clock

	//CPU OVERCLOCK HACK
	// DFF_pseudoAsyncClrPre #(.W(1)) ic87B ( //Q -> maincpu Q clock, Qn -> IRQ2n
	// 	.clk(clk),
	// 	.din(M1H),
	// 	.q(ic87B_Q),
	// 	.qn(Q2),
	// 	.set(1'b0),    // active high
	// 	.clr(1'b0),    // active high
	// 	.cen(HCLK) // signal whose edge will trigger the FF
  	// );

	// logic ic76d; //NOT gate
	// assign ic76d = ~M1H; //maincpu E clock
	//////////////////////

	//For simulation used the asynchronous version by Greg Miller, for synthesis the Sorgelig synchronous one.
	logic maincpu_RW;
	logic [15:0] maincpu_A;
	logic [7:0] maincpu_Din, maincpu_Dout;

	//$info("*** MAIN 68B09 SYNCHRONOUS CPU using falling edge CEN signals of E, Q clocks ***");
	logic clkE_prev = 1'b0;
	logic clkQ_prev = 1'b0;
	//logic clkEf_cen = 1'b0;
	//logic clkQf_cen = 1'b0;
	logic clkEf_cen;
	logic clkQf_cen;

	always @(posedge clk) begin
		clkE_prev <= ic76d;
		clkQ_prev <= ic87B_Q;

	// 	if(clkE_prev && !ic76d) clkEf_cen <= 1'b1;
	// 	else clkEf_cen <= 1'b0;
		
	// 	if(clkQ_prev && !ic87B_Q) clkQf_cen <= 1'b1;
	// 	else clkQf_cen <= 1'b0;
	end 
	always_comb begin
		clkEf_cen = clkE_prev && !ic76d;
		clkQf_cen = clkQ_prev && !ic87B_Q;
	end
	
	mc6809is ic89(
		.CLK(clk),
        .fallE_en(clkEf_cen),
     	.fallQ_en(clkQf_cen),
		.D(maincpu_Din),
		.DOut(maincpu_Dout),
		.ADDR(maincpu_A),
		.RnW(maincpu_RW),
		.BS(),
		.BA(),
		.nIRQ(ic100B_Qn),
		.nFIRQ(ic87A_Qn),
		.nNMI(ic100A_Qn),
		.AVMA(),
		.BUSY(),
		.LIC(),
		.nHALT(~pause_rq),
		.nRESET(RSTn),
		.nDMABREQ(1'b1),
		.RegData()
    );

	//Replaces TTL LS244 ic78, ic77
	//Check if is needed to add a clock period delay here!
	always_ff @(posedge clk) begin
		AB[14:0] <= maincpu_A[14:0];
		RW       <= maincpu_RW;
	end

	logic ic75d; //OR gate
	assign ic75d = (|maincpu_A[15:14]);

	logic ic76a; //NOT gate
	assign ic76a = ~maincpu_A[15];

	logic ic76b; //NOT gate
	assign ic76b = ~RW;


	logic ic86c; //NAND gate
	assign ic86c = ~(ic76a & AB[14]);

	//--- Intel P27256 32Kx8 CPUA ROMS 250ns ---
	logic [7:0] ic66_ROM_Dout;
	// ROM_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(15), .DATA_HEX_FILE("xs87b-10.7d_vmem.txt")) ic66 (
	// 	ROM_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(15), .DATA_HEX_FILE("1.rom_vmem.txt")) ic66 (
	// 	.clk(clk),
	// 	.Cen(1'b1), //the CEn and OEn logic is applied in the CPU data bus multiplexer, active high
	// 	.ADDR(maincpu_A[14:0]), 
	// 	.DATA(ic66_ROM_Dout)
	// );
	//PORT0: ROM load interface
	//PORT1: normal ROM access interface
	SRAM_dual_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(15)) ic66(
		.clk0(clk),
		.clk1(clk),
		.ADDR0(bram_addr[14:0]),
		.ADDR1(maincpu_A[14:0]),
		.DATA0(bram_data),
		.DATA1(8'h00),
		.cen0(bram_cs[0] & ~bram_addr[15]), //lower 32Kb
		.cen1(1'b1),
		.we0(bram_wr),
		.we1(1'b0),
		.Q0(),
		.Q1(ic66_ROM_Dout)
	);

	logic [7:0] ic65_ROM_Dout;
	// ROM_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(15), .DATA_HEX_FILE("xs87b-11.7c_vmem.txt")) ic65 (
	// 	ROM_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(15), .DATA_HEX_FILE("pa-0.ic65_vmem.txt")) ic65 (
	// 	.clk(clk),
	// 	.Cen(1'b1), //the CEn and OEn logic is applied in the CPU data bus multiplexer, active high
	// 	.ADDR({BSL,maincpu_A[13:0]}), 
	// 	.DATA(ic65_ROM_Dout)
	// );
	SRAM_dual_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(15)) ic65(
		.clk0(clk),
		.clk1(clk),
		.ADDR0(bram_addr[14:0]),
		.ADDR1({BSL,maincpu_A[13:0]}),
		.DATA0(bram_data),
		.DATA1(8'h00),
		.cen0(bram_cs[0] & bram_addr[15]), //upper 32Kb
		.cen1(1'b1),
		.we0(bram_wr),
		.we1(1'b0),
		.Q0(),
		.Q1(ic65_ROM_Dout)
	);

//--- FPGA Synthesizable unidirectinal data bus MUX, replaces ic88 tri-state logic ---
	//main CPU data input
    always_ff @(posedge clk) begin
        if(!ic86c && !ic76b)              maincpu_Din <= ic65_ROM_Dout;
        else if(!ic76a && !ic76b)         maincpu_Din <= ic66_ROM_Dout; 
		else if(!ic75d)                   maincpu_Din <= MAINCPU_EXT_Din;
		else                              maincpu_Din <= 8'hFF;             
    end

	//add one main clock period delay because the LS245 replace
	always_ff @(posedge clk) begin
		if(RW && !COMRn)                    MAINCPU_EXT_Din <= SHARED_SRAM_EXT_Dout;
		else if (RW)                        MAINCPU_EXT_Din <= DB_in;
		else                                MAINCPU_EXT_Din <= 8'hFF; //default replaces Hi-Z bus value by 8'hFF
	end

	//main CPU data out
	//add one main clock period delay because the LS245 that replaces
	always_ff @(posedge clk) begin
		if (!RW && !ic75d) MAINCPU_EXT_Dout <= maincpu_Dout;
		else               MAINCPU_EXT_Dout <= 8'hFF;
	end

	assign DB_out = MAINCPU_EXT_Dout;
//-------------------------------------------------------------------------------

	logic [7:0] ic67_Y; //3-8 Decoder

	ttl_74138 #(.WIDTH_OUT(8), .DELAY_RISE(0), .DELAY_FALL(0)) ic67
	(
		.Enable1_bar(AB[14]), //4 G2An
		.Enable2_bar(M2H), //5 G2Bn
		.Enable3(ic76a), //6 G1
		.A(AB[13:11]), //3,2,1 C,B,A
		.Y(ic67_Y) //7,9,10,11,12,13,14,15 Y[7:0]
	);

	logic ic68; //4-input NAND gate LS20
	assign  ic68 = ~(&ic67_Y[3:0]);

	logic ic69; //NOT gate
	assign ic69 = ~ic68;
	assign COMRn = ic69;
	assign {BACK2SELn,BACK1SELn,MAPSELn} = ic67_Y[6:4];

	logic [3:0] ic63_Y; //2-4 Decoder
	ttl_74139 ic63(.Enable_bar(ic67_Y[7]), .A_2D(AB[10:9]), .Y_2D(ic63_Y));

	logic ic64; //AND gate
	assign ic64 = ic63_Y[3] & ic63_Y[2];
	assign PLSELn = ic64;
	assign {IOn,OBJSELn} = ic63_Y[1:0];

//************************************
//*** Sub Cpu (Schematics page 2B) ***
//************************************
//Interrupt vectors:
//RESET (FFFE-FFFF) 0x8000 USED, FIRED by main RESET
//NMI   (FFFC-FFFD) 0x8017
//SWI   (FFFA-FFFB) 0x8019
//IRQ   (FFF8-FFF9) 0x801A USED, FIRED when maincpu writes to 
//FIRQ  (FFF6-FFF7) 0x8018
//SWI2  (FFF4-FFF5) 0x8019
//SWI3  (FFF2-FFF3) 0x8019

	logic ic57b; //NOT gate
	assign ic57b = ~M2Hn;

	//CPU OVERCLOCK HACK
	// assign ic57b = ~M1Hn;

	//For simulation used the asynchronous version by Greg Miller
	logic subcpu_RW;
	logic [15:0] subcpu_A;
	logic [7:0] subcpu_Din, subcpu_Dout;
	logic ic17a_Qn;

	//$info("*** SUB 68B09 SYNCHRONOUS CPU using falling edge CEN signals of E, Q clocks ***");
	logic clkE_prev2 = 1'b0;
	logic clkQ_prev2 = 1'b0;
	logic clkEf_cen2;
	logic clkQf_cen2;

	always @(posedge clk) begin
		clkE_prev2 <= ic57b;
		clkQ_prev2 <= Q2;
	end 
	always_comb begin
		clkEf_cen2 = clkE_prev2 && !ic57b;
		clkQf_cen2 = clkQ_prev2 && !Q2;
	end
	
	mc6809is ic30(
		.CLK(clk),
        .fallE_en(clkEf_cen2),
     	.fallQ_en(clkQf_cen2),
		.D(subcpu_Din),
		.DOut(subcpu_Dout),
		.ADDR(subcpu_A),
		.RnW(subcpu_RW),
		.BS(),
		.BA(),
		.nIRQ(ic17a_Qn),
		.nFIRQ(1'b1),
		.nNMI(1'b1),
		.AVMA(),
		.BUSY(),
		.LIC(),
		.nHALT(~pause_rq),
		.nRESET(RSTn),
		.nDMABREQ(1'b1),
		.RegData()
    );

	logic [3:0] ic18_Y; //2-4 Decoder

	DFF_pseudoAsyncClrPre #(.W(1)) ic17a ( //maincpu IRQn
		.clk(clk),
		.din(1'b1),
		.q(),
		.qn(ic17a_Qn),
		.set(1'b0),    // active high
		.clr(~ic18_Y[1]),    // active high
		.cen(W3A0Cn) // signal whose edge will trigger the FF
  	);

	logic ic17b_Q, ic17b_Qn;
	DFF_pseudoAsyncClrPre #(.W(1)) ic17b ( //shared RAM RnW
		.clk(clk),
		.din(M1H),
		.q(ic17b_Q),
		.qn(ic17b_Qn),
		.set(1'b0),    // active high
		.clr(1'b0),    // active high
		.cen(HCLK) // signal whose edge will trigger the FF
  	);

	logic ic6b; //3-input NAND gate
	assign ic6b = ~(ic17b_Qn & M2Hn & ic76b);

	//CPU OVERCLOCK HACK
	// DFF_pseudoAsyncClrPre #(.W(1)) ic17b ( //shared RAM RnW
	// 	.clk(clk),
	// 	.din(HCLK),
	// 	.q(ic17b_Q),
	// 	.qn(ic17b_Qn),
	// 	.set(1'b0),    // active high
	// 	.clr(1'b0),    // active high
	// 	.cen(clk12M_cen) // signal whose edge will trigger the FF
  	// );

	// logic ic6b; //3-input NAND gate
	//assign ic6b = ~(ic17b_Qn & M1Hn & ic76b);
	////////////////////
	assign WDn = ic6b;

	logic ic57c; //NOT gate
	assign ic57c = ~subcpu_A[15];

	logic ic36d; //NAND gate
	assign ic36d = ~(ic57c & subcpu_A[14]);

	logic ic56a_Q; //sub CPU ROM bank switch
	//--- Intel P27256 32Kx8 CPUA ROMS 250ns ---
    // ROM_async #(.ADDR_WIDTH(0), .DELAY(80), .DATA_HEX_FILE("p1-0.ic29_vmem.txt")) ic29 (.ADDR(subcpu_A[14:0]), .CEn(ic57c), .OEn(1'b0), .DATA(subcpu_D)); //this replaces Solar Warrior IC29
	logic [7:0] ic29_ROM_Dout;
	// ROM_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(15), .DATA_HEX_FILE("p1-0.ic29_vmem.txt")) ic29 (
	// 	.clk(clk),
	// 	.Cen(1'b1), //the CEn and OEn logic is applied in the CPU data bus multiplexer selector, active high
	// 	.ADDR(subcpu_A[14:0]), 
	// 	.DATA(ic29_ROM_Dout)
	// );
	//PORT0: ROM load interface
	//PORT1: normal ROM access interface
	SRAM_dual_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(15)) ic29(
		.clk0(clk),
		.clk1(clk),
		.ADDR0(bram_addr[14:0]),
		.ADDR1(subcpu_A[14:0]),
		.DATA0(bram_data),
		.DATA1(8'h00),
		.cen0(bram_cs[1] & ~bram_addr[15]), //lower 32Kb
		.cen1(1'b1),
		.we0(bram_wr),
		.we1(1'b0),
		.Q0(),
		.Q1(ic29_ROM_Dout)
	);

    // ROM_async #(.ADDR_WIDTH(0), .DELAY(80), .DATA_HEX_FILE("p0-0.ic15_vmem.txt")) ic15 (.ADDR({ic56a_Q,subcpu_A[13:0]}), .CEn(ic36d), .OEn(1'b0), .DATA(subcpu_D)); //this replaces Solar Warrior IC15
	logic [7:0] ic15_ROM_Dout;
	// ROM_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(15), .DATA_HEX_FILE("p0-0.ic15_vmem.txt")) ic15 (
	// 	.clk(clk),
	// 	.Cen(1'b1), //the CEn and OEn logic is applied in the CPU data bus multiplexer selector, active high
	// 	.ADDR({ic56a_Q,subcpu_A[13:0]}), 
	// 	.DATA(ic15_ROM_Dout)
	// );
	SRAM_dual_sync #(.DATA_WIDTH(8), .ADDR_WIDTH(15)) ic15(
		.clk0(clk),
		.clk1(clk),
		.ADDR0(bram_addr[14:0]),
		.ADDR1({ic56a_Q,subcpu_A[13:0]}),
		.DATA0(bram_data),
		.DATA1(8'h00),
		.cen0(bram_cs[1] & bram_addr[15]), //upper 32Kb
		.cen1(1'b1),
		.we0(bram_wr),
		.we1(1'b0),
		.Q0(),
		.Q1(ic15_ROM_Dout)
	);

	logic [7:0] ic58_Y; //3-8 Decoder
	ttl_74138 #(.WIDTH_OUT(8), .DELAY_RISE(0), .DELAY_FALL(0)) ic58
	(
		.Enable1_bar(M2Hn), //4 G2An
		.Enable2_bar(subcpu_A[15]), //Only enabled for addresses < 0x8000.
		.Enable3(1'b1), //6 G1
		.A({subcpu_RW,subcpu_A[14:13]}), //3,2,1 C,B,A
		.Y(ic58_Y) //7,9,10,11,12,13,14,15 Y[7:0]
	);

	logic ic64a; //AND gate
	assign ic64a = (ic58_Y[0] & ic58_Y[4]);

	//Hack: generate delay for subcpu_Dout.
	logic [7:0] subcpu_Dout2;

//--- FPGA Synthesizable unidirectinal data bus MUX, replaces ic88 tri-state logic ---
	//sub CPU data input
    always_ff @(posedge clk) begin
        if     (!ic36d)              subcpu_Din <= ic15_ROM_Dout;
        else if(!ic57c)              subcpu_Din <= ic29_ROM_Dout; 
		else                         subcpu_Din <= SUBCPU_EXT_Din;           
    end

	always_ff @(posedge clk) begin
		if(subcpu_RW && !ic64a) SUBCPU_EXT_Din <= SHARED_SRAM_Dout;
		else                    SUBCPU_EXT_Din <= 8'hFF; //replaces hi-Z bus state
	end

	//Sub CPU data output
	always_ff @(posedge clk) begin
		if(!subcpu_RW && !ic64a) SUBCPU_EXT_Dout <= subcpu_Dout2;
		else                    SUBCPU_EXT_Dout <= 8'hFF; //replaces hi-Z bus state
	end
//-------------------------------------------------------------------------------

	ttl_74139 #(.DELAY(0)) ic18(.Enable_bar(ic58_Y[1]), .A_2D(subcpu_A[12:11]), .Y_2D(ic18_Y));

	assign IRQ2n = ic18_Y[0];

	logic ic75b; //OR gate
	assign ic75b = ic58_Y[0] | ic17b_Q;

	//maincpu or subcpu address selection based on M2Hn clocking signal, this means that the 
	//both buses are alternated in a periodic way with each cpu address held 1/2 cycle of M2Hn
	//when addresses are in the range 0x0-1FFF. If not always main cpu addresses are selected.

	logic [3:0] ic4_Y;
	//ttl_74157 A_2D({B3,A3,B2,A2,B1,A1,B0,A0})
    ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) ic4 (.Enable_bar(1'b0), .Select(ic64a),
                .A_2D({AB[3],subcpu_A[3],AB[2],subcpu_A[2],AB[1],subcpu_A[1],AB[0],subcpu_A[0]}), .Y(ic4_Y));
	
	logic [3:0] ic3_Y;
	ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) ic3 (.Enable_bar(1'b0), .Select(ic64a),
                .A_2D({AB[7],subcpu_A[7],AB[6],subcpu_A[6],AB[5],subcpu_A[5],AB[4],subcpu_A[4]}), .Y(ic3_Y));

	logic [3:0] ic2_Y;
	ttl_74157 #(.DELAY_RISE(0), .DELAY_FALL(0)) ic2 (.Enable_bar(1'b0), .Select(ic64a),
                .A_2D({AB[11],subcpu_A[11],AB[10],subcpu_A[10],AB[9],subcpu_A[9],AB[8],subcpu_A[8]}), .Y(ic2_Y));


	logic ic75c; //OR gate
	assign  ic75c = (COMRn | ic6b);

	logic [1:0] ic16_Y;
	ttl_74157 #(.BLOCKS(2), .DELAY_RISE(0), .DELAY_FALL(0)) ic16 (.Enable_bar(1'b0), .Select(ic64a),
                .A_2D({ic75c, ic75b,AB[12],subcpu_A[12]}), .Y(ic16_Y));


//****************************************
//*** Shared SRAM (Schematics page 2B) ***
//****************************************
    //--- HM6264PL-15 8Kx8 150ns SRAM ---
	// tri1 [7:0] ic1_D;
    // SRAM_async3 #(.ADDR_WIDTH(13), .DELAY(50), .DATA_HEX_FILE("rnd8K.bin_vmem.txt")) ic1 (.ADDR({ic16_Y[0],ic2_Y[3:0],ic3_Y[3:0],ic4_Y[3:0]}), .CE1n(1'b0), .CE2(1'b1), .OEn(1'b0), .WEn(ic16_Y[1]), .DATA(ic1_D));
	
	SRAM_sync_init #(.DATA_WIDTH(8), .ADDR_WIDTH(13), .DATA_HEX_FILE("rnd8K.bin_vmem.txt")) ic1(
		.clk(clk),
		.ADDR({ic16_Y[0],ic2_Y[3:0],ic3_Y[3:0],ic4_Y[3:0]}),
		.DATA(SHARED_SRAM_Din),
		.cen(1'b1), //active high
		.we(~ic16_Y[1]), //active high
		.Q(SHARED_SRAM_Dout)
    );

//--- FPGA Synthesizable unidirectinal data bus MUX, replaces ic88 tri-state logic ---
	//SHARED SRAM data output
	always_ff @(posedge clk) begin
		if (RW && !COMRn) SHARED_SRAM_EXT_Dout <= SHARED_SRAM_Dout;
		else        SHARED_SRAM_EXT_Dout <= 8'hFF; //replaces hi-Z bus state
	end

	//SHARED SRAM data input
	always_ff @(posedge clk) begin
		if(!RW && !COMRn) SHARED_SRAM_EXT_Din <= MAINCPU_EXT_Dout;
		else              SHARED_SRAM_EXT_Din <= 8'hFF; //replaces hi-Z bus state
	end
	always_ff @(posedge clk) begin
		if(!RW && !COMRn)             SHARED_SRAM_Din <= SHARED_SRAM_EXT_Din;
		else if(!subcpu_RW && !ic64a) SHARED_SRAM_Din <= SUBCPU_EXT_Dout;
		else                          SHARED_SRAM_Din <= 8'hFF; //replaces hi-Z bus state

	end
//-------------------------------------------------------------------------------

	//Hack: generate delay for subcpu_Dout.
	always_ff @(posedge clk) begin
		subcpu_Dout2 <= subcpu_Dout;
	end

	//This register does ROM bankswitch with subcpu ROM ic15 (divided into two banks of 16Kb)
	// ttl_7474 #(.BLOCKS(1), .DELAY_RISE(10), .DELAY_FALL(10)) ic56a
	// (.Clear_bar(1'b1), .Preset_bar(1'b1), .D(subcpu_D0), .Clk(ic18_Y[2]), .Q(ic56a_Q), .Q_bar()); //ROM bank switch
	DFF_pseudoAsyncClrPre #(.W(1)) ic56a ( //ROM bank switch
		.clk(clk),
		.din(subcpu_Dout2[0]),
		.q(ic56a_Q),
		.qn(),
		.set(1'b0),    // active high
		.clr(1'b0),    // active high
		.cen(ic18_Y[2]) // signal whose edge will trigger the FF
  	);
endmodule 