//============================================================================
//
//  Memory testes for MiSTer.
//  Copyright (C) 2017-2019 Sorgelig
//
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
//============================================================================
//============================================================================
//
//  Multicore 2 Top by Victor Trucco
//
//============================================================================

`default_nettype none

module memtest
( 
	// Clocks
	input wire	clock_50_i,

	// Buttons
	input wire [4:1]	btn_n_i,

	// SRAMs (AS7C34096)
	output wire	[18:0]sram_addr_o  = 18'b0000000000000000000,
	inout wire	[7:0]sram_data_io	= 8'bzzzzzzzz,
	output wire	sram_we_n_o		= 1'b1,
	output wire	sram_oe_n_o		= 1'b1,
		
	// SDRAM	(H57V256)
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQMH,
	output        SDRAM_DQML,
	output        SDRAM_CKE,
	output        SDRAM_nCS,
	output        SDRAM_nWE,
	output        SDRAM_nRAS,
	output        SDRAM_nCAS,
	output        SDRAM_CLK,

	// PS2
	inout wire	ps2_clk_io			= 1'bz,
	inout wire	ps2_data_io			= 1'bz,
	inout wire	ps2_mouse_clk_io  = 1'bz,
	inout wire	ps2_mouse_data_io = 1'bz,

	// SD Card
	output wire	sd_cs_n_o			= 1'b1,
	output wire	sd_sclk_o			= 1'b0,
	output wire	sd_mosi_o			= 1'b0,
	input wire	sd_miso_i,

	// Joysticks
	input wire	joy1_up_i,
	input wire	joy1_down_i,
	input wire	joy1_left_i,
	input wire	joy1_right_i,
	input wire	joy1_p6_i,
	input wire	joy1_p9_i,
	input wire	joy2_up_i,
	input wire	joy2_down_i,
	input wire	joy2_left_i,
	input wire	joy2_right_i,
	input wire	joy2_p6_i,
	input wire	joy2_p9_i,
	output wire	joyX_p7_o			= 1'b1,

	// Audio
	output        AUDIO_L,
	output        AUDIO_R,
	input wire	ear_i,
	output wire	mic_o					= 1'b0,

		// VGA
	output  [4:0] VGA_R,
	output  [4:0] VGA_G,
	output  [4:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

		// HDMI
	output wire	[7:0]tmds_o			= 8'b00000000,

		//STM32
	input wire	stm_tx_i,
	output wire	stm_rx_o,
	output wire	stm_rst_o			= 1'bz, // '0' to hold the microcontroller reset line, to free the SD card
		
	inout wire	stm_b8_io, 
	inout wire	stm_b9_io,

	input         SPI_SCK,
	output        SPI_DO,
	input         SPI_DI,
	input         SPI_SS2
);


assign AUDIO_L = 0;
assign AUDIO_R = 0;

assign	sram_we_n_o		= 1'b1;
assign	sram_oe_n_o		= 1'b1;
assign	stm_rst_o		= 1'b0;

wire [31:0] status;
wire  [1:0] buttons;

reg  [1:0] sdram_sz = 2'b11; //0 - no memory board detected   1 - 32 MB  2 - 64 MB  3 - 128 MB

reg direct = 1'b1;



/*
reg  [10:0] ps2_key;
wire  [1:0] sdram_sz;
hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(CLK_50M),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),
	.status(status),
	.buttons(buttons),
	.sdram_sz(sdram_sz),

	.ps2_key(ps2_key),
	.ps2_kbd_led_use(0),
	.ps2_kbd_led_status(0)
);
*/

wire RESET = ~btn_n_i[1];

///////////////////////////////////////////////////////////////////
wire clk_ram, locked;

wire [1:0] pll_locked_in;
wire pll_locked;
wire pll_areset;
wire pll_scanclk;
wire pll_scandata;
wire pll_scanclkena ;
wire pll_configupdate;
wire pll_scandataout;
wire pll_scandone;
wire [7:0]pll_rom_address;
wire pll_write_rom_ena;
wire pll_write_from_rom;
wire pll_reconfig_s;
wire pll_reconfig_busy;
wire pll_reconfig_reset;
reg [1:0]pll_reconfig_state = 2'b00;
integer pll_reconfig_timeout;
wire pll_rom_q;
	

pll pll
(
	
	.inclk0(clock_50_i),
	.areset(pll_areset | RESET),
	.c0(clk_ram),
	.c1(pll_clk),
	.locked(locked),
	
	.scanclk 		( pll_scanclk ),
	.scandata 		( pll_scandata ),
	.scanclkena 	( pll_scanclkena ),
	.configupdate 	( pll_configupdate ),
	.scandataout 	( pll_scandataout ),
	.scandone 		( pll_scandone )
	
);

assign ps2_mouse_clk_io = clk_ram;

	pll_reconfig pll_reconfig
	(
		.busy 					( pll_reconfig_busy ),
		.clock  					( clock_50_i ),
		.counter_param 		( 3'b000 ),
		.counter_type 			( 4'b0000 ),
		.data_in 				( 9'b000000000 ),
		.pll_areset 			( pll_areset ),
		.pll_areset_in  		( 0 ),
		.pll_configupdate 	( pll_configupdate),
		.pll_scanclk 			( pll_scanclk ),
		.pll_scanclkena 		( pll_scanclkena ),
		.pll_scandata 			( pll_scandata ),
		.pll_scandataout 		( pll_scandataout ),
      .pll_scandone		 	( pll_scandone ),
		.read_param			 	( 0 ),
      .reconfig 				( pll_reconfig_s ),
		.reset 					( pll_reconfig_reset ),
		.reset_rom_address 	( 0 ),
		.rom_address_out 		( pll_rom_address ),
		.rom_data_in 			( pll_rom_q ),
		.write_from_rom 		( pll_write_from_rom ),
		.write_param  			( 0 ),
      .write_rom_ena 		( pll_write_rom_ena )
	);
	

	wire q_reconfig_70, q_reconfig_80, q_reconfig_90, q_reconfig_100, q_reconfig_110, q_reconfig_120, q_reconfig_130, q_reconfig_140, q_reconfig_150, q_reconfig_160, q_reconfig_167;
	
	reconfig_70  reconfig_70  ( .address ( pll_rom_address ), .clock ( clock_50_i ), .rden ( pll_write_rom_ena ), .q ( q_reconfig_70 ));
	reconfig_80  reconfig_80  ( .address ( pll_rom_address ), .clock ( clock_50_i ), .rden ( pll_write_rom_ena ), .q ( q_reconfig_80 ));
	reconfig_90  reconfig_90  ( .address ( pll_rom_address ), .clock ( clock_50_i ), .rden ( pll_write_rom_ena ), .q ( q_reconfig_90 ));
	reconfig_100 reconfig_100 ( .address ( pll_rom_address ), .clock ( clock_50_i ), .rden ( pll_write_rom_ena ), .q ( q_reconfig_100 ));
	reconfig_110 reconfig_110 ( .address ( pll_rom_address ), .clock ( clock_50_i ), .rden ( pll_write_rom_ena ), .q ( q_reconfig_110 ));
	reconfig_120 reconfig_120 ( .address ( pll_rom_address ), .clock ( clock_50_i ), .rden ( pll_write_rom_ena ), .q ( q_reconfig_120 ));
	reconfig_130 reconfig_130 ( .address ( pll_rom_address ), .clock ( clock_50_i ), .rden ( pll_write_rom_ena ), .q ( q_reconfig_130 ));
	reconfig_140 reconfig_140 ( .address ( pll_rom_address ), .clock ( clock_50_i ), .rden ( pll_write_rom_ena ), .q ( q_reconfig_140 ));
	reconfig_150 reconfig_150 ( .address ( pll_rom_address ), .clock ( clock_50_i ), .rden ( pll_write_rom_ena ), .q ( q_reconfig_150 ));
	reconfig_160 reconfig_160 ( .address ( pll_rom_address ), .clock ( clock_50_i ), .rden ( pll_write_rom_ena ), .q ( q_reconfig_160 ));
	reconfig_167 reconfig_167 ( .address ( pll_rom_address ), .clock ( clock_50_i ), .rden ( pll_write_rom_ena ), .q ( q_reconfig_167 ));

always @(*) 
begin
	case(pos)
		0: begin pll_rom_q <= q_reconfig_167; end
		1: begin pll_rom_q <= q_reconfig_160; end
		2: begin pll_rom_q <= q_reconfig_150; end
		3: begin pll_rom_q <= q_reconfig_140; end
		4: begin pll_rom_q <= q_reconfig_130; end
		5: begin pll_rom_q <= q_reconfig_120; end
		6: begin pll_rom_q <= q_reconfig_110; end
		7: begin pll_rom_q <= q_reconfig_100; end
		8: begin pll_rom_q <= q_reconfig_90;  end
		9: begin pll_rom_q <= q_reconfig_80;  end
	  10: begin pll_rom_q <= q_reconfig_70;  end
	endcase
end		

	
	
reg recfg = 0;

// Phases here are empirically adjusted based on 167MHz synthesized core 
// so arn't reliable for fixed frequency cores.
wire [31:0] cfg_param[44] =
'{ //      M         K          C
	'h167, 'h00808, 'hB33332DD, 'h20302,
	'h160, 'h00808, 'h00000001, 'h20302,
	'h150, 'h20807, 'h00000001, 'h20302,
	'h140, 'h00707, 'h00000001, 'h20302,
	'h130, 'h00505, 'h66666611, 'h00202,
	'h120, 'h00707, 'h66666611, 'h00303,
	'h110, 'h20706, 'h333332DD, 'h00303,
	'h100, 'h00404, 'h00000001, 'h00202,
	 'h90, 'h00707, 'h66666666, 'h00404,
	 'h80, 'h00707, 'h66666666, 'h20504,
	 'h70, 'h00707, 'h00000001, 'h00505
};

reg   [3:0] pos  = 7;
reg  [15:0] mins = 0;
reg  [15:0] secs = 0;
reg         auto = 0;

reg  [10:0] ps2_key;

reg btn_rst, old_btn_rst;
reg btn_up, old_btn_up;
reg btn_down, old_btn_down;
reg btn_auto, old_btn_auto;



	
	
	

always @(posedge clock_50_i) begin
	reg  [7:0] state = 0;
	integer    min = 0, sec = 0;
	reg        old_stb = 0;

	pll_write_from_rom <= 0;
	pll_reconfig_s <= 0;
	pll_reconfig_reset <= 0;





			case(pll_reconfig_state)
	
				0: begin
						if (recfg)
						begin
							pll_write_from_rom <= 1;
							pll_reconfig_state <= 1;
						end
					end

		
				1: begin
						pll_reconfig_state <= 2;
					end

			
				2: begin
				
						if (pll_reconfig_busy == 0)
						begin	
							pll_reconfig_s <= 1;
							pll_reconfig_state <= 3;
							pll_reconfig_timeout <= 1000;
						end;
						
					end

		
				3: begin
				
						pll_reconfig_timeout <= pll_reconfig_timeout - 1;
						
						if (pll_reconfig_timeout == 1) 
						begin
							pll_reconfig_reset <= 1; // sometimes pll reconfig stuck in busy state
							pll_reconfig_state <= 0;
							recfg <= 0;
						end
						
						if (pll_reconfig_s == 0 && pll_reconfig_busy == 0)
						begin
							pll_reconfig_state <= 0;
							recfg <= 0;
						end
						
					end


			endcase
	


	if(recfg) begin
		{min, mins} <= 0;
		{sec, secs} <= 0;
	end else begin
		min <= min + 1;
		if(min == 2999999999) begin
			min <= 0;
			if(mins[3:0]<9) mins[3:0] <= mins[3:0] + 1'd1;
			else begin
				mins[3:0] <= 0;
				if(mins[7:4]<9) mins[7:4] <= mins[7:4] + 1'd1;
				else begin
					mins[7:4] <= 0;
					if(mins[11:8]<9) mins[11:8] <= mins[11:8] + 1'd1;
					else begin
						mins[11:8] <= 0;
						if(mins[15:12]<9) mins[15:12] <= mins[15:12] + 1'd1;
						else mins[15:12] <= 0;
					end
				end
			end
		end
		sec <= sec + 1;
		if(sec == 4999999) begin
			sec <= 0;
			secs <= secs + 1'd1;
		end
	end
	
	old_btn_rst <= btn_rst;
	old_btn_up <= btn_up;
	old_btn_down <= btn_down;
	old_btn_auto <= btn_auto;
		
		//(pos 0 = 167)
		
	if(old_btn_rst == 0 && btn_rst == 1) 
	begin
	//	direct <= ~direct;
	end
	
		
	if(old_btn_up == 0 && btn_up == 1 && pos > 0) 
	begin
		state <= 0;
		recfg <= 1;
		pos <= pos - 1'd1;
		auto <= 0;
	end
			
	if(old_btn_down == 0 && btn_down == 1 && pos < 10) 
	begin
		state <= 0;
		recfg <= 1;
		pos <= pos + 1'd1;
		auto <= 0;
	end
			
	if(old_btn_auto == 0 && btn_auto == 1 && auto == 1) 
	begin
	state <= 0;
		recfg <= 1;
		auto <= 0;
	end
			
	if(old_btn_auto == 0 && btn_auto == 1 && auto == 0) 
	begin
		state <= 0;
		recfg <= 1;
		pos <= 0;
		auto <= 1;
	end

	if(auto && (failcount && passcount) && !recfg && pos < 10) 
	begin
		recfg <= 1;
		pos <= pos + 1'd1;
	end
	
	if(status[0] ) 
	begin
		recfg <= 1;
		pos <= 0;
		auto <= 1;
	end
end


///////////////////////////////////////////////////////////////////
assign SDRAM_CKE = 1;

reg reset = 0;
always @(posedge clk_ram) begin
	integer timeout;

	if(timeout) timeout <= timeout - 1;
	reset <= |timeout;

	if((recfg || ~locked) && (timeout < 1000000)) timeout <= 1000000;

	if(RESET) timeout <= 100000000;
end

wire module_clk, pll_clk;

wire [31:0] passcount, failcount;
tester my_memtst
(
	.clk(clk_ram),
	.rst_n(~reset),
	.sz(sdram_sz),
	.passcount(passcount),
	.failcount(failcount),
	.DRAM_CLK(SDRAM_CLK),
	.DRAM_DQ(SDRAM_DQ),
	.DRAM_ADDR(SDRAM_A),
	.DRAM_LDQM(SDRAM_DQML),
	.DRAM_UDQM(SDRAM_DQMH),
	.DRAM_WE_N(SDRAM_nWE),
	.DRAM_CS_N(SDRAM_nCS),
	.DRAM_RAS_N(SDRAM_nRAS),
	.DRAM_CAS_N(SDRAM_nCAS),
	.DRAM_BA_0(SDRAM_BA[0]),
	.DRAM_BA_1(SDRAM_BA[1])
);


///////////////////////////////////////////////////////////////////
wire videoclk;

vid_pll vid_pll
(
	.inclk0(clock_50_i),
	.c0(videoclk)
);

//assign CLK_VIDEO = videoclk;
//assign CE_PIXEL  = 1;

wire hs, vs;
wire [1:0] b, r, g;
vgaout showrez
(
	.clk(videoclk),
	.rez1({(direct)?4'd13:4'd1, passcount[27:0]}),
	.rez2(failcount),
	.bg(6'b000001),
	.freq(16'hF000 | cfg_param[{pos, 2'd0}][11:0]),
	.elapsed(mins),
	.mark(8'h80 >> {~auto, secs[2:0]}),
	.hs(hs),
	.vs(vs),
	//.de(VGA_DE),
	.b(b),
	.r(r),
	.g(g)
);

assign VGA_HS = ~hs;
assign VGA_VS = ~vs;

assign VGA_B  = {4{b}};
assign VGA_R  = {4{r}};
assign VGA_G  = {4{g}};

debounce # ( .counter_size (10)) debounce1 ( .clk_i   (clock_50_i),   .button_i (~btn_n_i[1]), .result_o  (btn_rst)); 
debounce # ( .counter_size (10)) debounce2 ( .clk_i   (clock_50_i),   .button_i (~btn_n_i[2]), .result_o  (btn_up)); 
debounce # ( .counter_size (10)) debounce3 ( .clk_i   (clock_50_i),   .button_i (~btn_n_i[4]), .result_o  (btn_down)); 
debounce # ( .counter_size (10)) debounce4 ( .clk_i   (clock_50_i),   .button_i (~btn_n_i[3]), .result_o  (btn_auto)); 


endmodule
