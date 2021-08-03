//---------------------------------------------------------------------------------
// DECA Top level for fpganes by Somhic (16/07/21) adapted 
// from DE10_lite port by Dar (https://sourceforge.net/projects/darfpga/files/Software%20VHDL/nes/)
// v1 VGA
// v2 added HDMI output, not working yet. 
// v3 some errors on qsf corrected. Hq2x disabled to minimize timing errors
// v4.2 no hq2x, sdram mister module adapted, memtest sdram parameters
// v4.3 added hq2x again.   Better video output, but foggy
// v4.4  SDRAM_CLK from pll c1 gets the same fog as using alttdio from sdram.v.
//		 HDMI output direct without OSD, same foggy effect --> back to OSD
//		 pll phase test: -2.04 ns, still foggy: -2.91 ns, -45º, -90º, -135º ,-180º, no image at all: -225º, -270º 			
// v4.5	 Back to using alttdio, so pll c1 is now useless
//       Finally found that with --> RASCAS_DELAY   = 3'd2; --> foggy is over
// v4.6  adding I2S audio  
//		 HDMI at 42.857 MHz with resol. 1026x480 works on Benq & LG   
//		 No HDMI output at bootup. Just after firts load of a core though VGA interface
// v4.7  Clock_vga at 26.75 MHz outputs hdmi 640x480 but with flickering. It does not start OSD anyway
//		 Activaded dipswitches[2] but then no video output in both vga & hdmi
//		 Code cleanup
// v4.8  shifted sample >>2 to reduce volume
//		 added SIGNALTAP to check signals
//		 reset_nes = 1 until first loaded rom because of !loader_done, changed reset of HDMI initialization to key0
//		 HDMI output now works after bootup
// v4.9  SignalTap disabled in qsf file
// 	     SDRAM clkref syncronization signal enabled in sdram.v (haven't seen any benefit of it yet)
//			
//
// ---------------------------------------------------------------------------
// fpganes DE10-Lite port by Dar (darfpga@aol.fr) (http://darfpga.blogspot.fr)
// From ZxUno/Multicore and MiSTer sources realeased on 09-02-2019
//
// ---------------------------------------------------------------------------
// all based on fpganes Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.
// 
// ---------------------------------------------------------------------------
// DE10-Lite port updates
//
// 10-02-2019 - rev 0.0 
// - Video_mixer, scandoubler and hq2x kept from previous MiSTer release
// - No game backup
//
// - Mofify zpu_ctrlmodule to add palette/scanline/hq2x control from osd
//
// 05-12-2018 - no release 
// - Speed up loader : increase sd card spi clock, improve fifo read/write
//  (also lower fifo size)
// 
// - Use SDRAM instead of SRAM
//
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// OSD and SD card managed thru zpu_ctrlmodule
// - Reset NES
// - Scanlines (OSD)    : managed at OSD level
// - Hq2x filter
// - Forced scandoubler : N.U. VGA mode only atm
// - Hide overscan
// - Auto-swap/Eject FDS disk
// - Auto side +1/2/3
// - Scanlines off/25%/50%/75%
// - Palette                 : chose among 8 
// - Load NES ROM or FDS with header
// - Load FDS (Loopy's) Bios : use POWERPAK FDSBIOS.BIN
// - Load FDS ROM
// - Exit
//
// ---------------------------------------------------------------------------
// Keyboard control 
// - F1    : start
// - F2    : select
// - space : A
// - ctrl  : B
// - arrow up, down, left, right : move
//
// ---------------------------------------------------------------------------
// FDS ROM
// - first load Loopy's FDS bios (FDSBIOS.BIN from POWERPAK134).
// - then load FDS ROM.
//
// - Disk side change is automatic for most ROM. If change is not automatic
//   then on OSD check Auto-swap/Eject disk to keep disk ejected
//   then on OSD cycle Auto side +1 / +2 / +3 as needed
//   then on OSD uncheck Auto-swap/Eject disk to return to auto inserted/ejected disk
//
// - Some FDS ROM seems to prevent starting another ROM, in such case power cycle on/off 
//   the board or load a non FDS ROM before new FDS ROM.
//
// ---------------------------------------------------------------------------

`timescale 1ns / 1ps

module nes_deca
(
	// Clocks
	input wire	max10_clk1_50,

	// Buttons
	input wire key0,

	// Debug Leds
	output wire [7:0] led,

	// SDRAM
	output wire	[12:0] SDRAM_A,
	inout wire	[15:0] SDRAM_DQ,
	output wire	[1:0]  SDRAM_BA,
	output wire	SDRAM_DQML,
 	output wire	SDRAM_DQMH,
	output wire	SDRAM_nRAS,
	output wire	SDRAM_nCAS,
	output wire	SDRAM_CKE,
	output wire	SDRAM_CLK,
	output wire	SDRAM_nCS,
	output wire	SDRAM_nWE,

	// PS2 (via GPIO)
	input wire	ps2_clk_io,
	input wire	ps2_data_io,

	// SD Card
	output wire	sd_cs_n_o = 1'b1,
	output wire	sd_sclk_o = 1'b0,
	output wire	sd_mosi_o = 1'b0,
	input wire	sd_miso_i,
	output wire	SD_SEL,
	output wire	SD_CMD_DIR,
	output wire	SD_D0_DIR,
	output wire	SD_D123_DIR,

	// Audio (via GPIO)
	output wire	dac_l_o	= 1'b0,
	output wire	dac_r_o	= 1'b0,

	// Audio DAC DECA
	output wire i2sMck,			//AUDIO_MCLK
	output wire i2sSck,			//AUDIO_BCLK
	output wire i2sLr,			//AUDIO_WCLK
	output wire i2sD,			//AUDIO_DIN_MFP1
	inout  wire	AUDIO_GPIO_MFP5,
	input  wire	AUDIO_MISO_MFP4,
	inout  wire	AUDIO_RESET_n,
	output wire AUDIO_SCLK_MFP3,
	output wire AUDIO_SCL_SS_n,
	inout  wire	AUDIO_SDA_MOSI,
	output wire AUDIO_SPI_SELECT,

	// VGA
	output wire	[2:0] vga_r_o,
	output wire	[2:0] vga_g_o,
	output wire	[2:0] vga_b_o,
	output wire	vga_hsync_n_o,
	output wire	vga_vsync_n_o, 

	// HDMI-TX  DECA 
	inout 		  	HDMI_I2C_SCL,
	inout 		  	HDMI_I2C_SDA,
	inout 	[3:0]	HDMI_I2S,
	inout 		 	HDMI_LRCLK,
	inout 		 	HDMI_MCLK,
	inout 		  	HDMI_SCLK,
	output		  	HDMI_TX_CLK,
	output	[23:0]	HDMI_TX_D,
	output		    HDMI_TX_DE,    
	output		    HDMI_TX_HS,
	input 		    HDMI_TX_INT,
	output		    HDMI_TX_VS
  );


// MicroSD Card 
assign SD_SEL = 1'b0;   	// 0 = 3.3V at sdcard		
assign SD_CMD_DIR = 1'b1;  	// MOSI FPGA output	
assign SD_D0_DIR = 1'b0;   	// MISO FPGA input	
assign SD_D123_DIR = 1'b1; 	// CS FPGA output	
// 

wire clk85;
wire clk_ctrl;
wire clk;
wire clock_locked;
wire clock_vga;			//added for HDMI video output

assign clk_ctrl = clk85;

max10_pll pll
(
	.areset(0),		
	.inclk0(max10_clk1_50), // 50 MHz
	.c0(clk85),             // 85.714 MHz
	//.c1(SDRAM_CLK),       // 85.714 MHz -2ns    // used altddio_out from sdram.v instead
	.c2(clk),               // 21.449 MHz
	.c3(clock_vga),			// 42.857 MHz
	.locked(clock_locked)
);

  
// get scancode from keyboard
wire kbd_intr;
wire [7:0] kbd_scancode;
  
io_ps2_keyboard keyboard(
	.clk(clk), // use same clock as main core
	.kbd_clk(ps2_clk_io),
	.kbd_dat(ps2_data_io),
	.interrupt(kbd_intr),
	.scancode(kbd_scancode)
);

// translate scancode to joystick
wire [9:0] joyHBCPPFRLDU;
wire [2:0] keys_HUA;
wire kbd_intr_e = kbd_intr & !host_divert_keyboard;
	
kbd_joystick joystick (
	.clk(clk),  // use same clock as main core
	.kbdint(kbd_intr_e),
	.kbdscancode(kbd_scancode), 
	.joyHBCPPFRLDU(joyHBCPPFRLDU),
	.keys_HUA(keys_HUA)
);
  
wire	joy1_up_i    = ~joyHBCPPFRLDU[0]; // arrow up
wire	joy1_down_i  = ~joyHBCPPFRLDU[1]; // arrow down
wire	joy1_left_i  = ~joyHBCPPFRLDU[2]; // arrow left
wire	joy1_right_i = ~joyHBCPPFRLDU[3]; // arrow right
wire	joy1_p6_i    = ~joyHBCPPFRLDU[4]; // space
wire	joy1_p9_i    = ~joyHBCPPFRLDU[8]; // ctrl
wire	joy2_up_i    = 1'b1;
wire	joy2_down_i  = 1'b1;
wire	joy2_left_i  = 1'b1;
wire	joy2_right_i = 1'b1;
wire	joy2_p6_i    = 1'b1;
wire	joy2_p9_i    = 1'b1;
    
// 1 : start  player 1  //  3 : start  player 2
// 2 : select player 1  //  4 : select player 2
wire [4:1]btn_n_i = {2'b11,~joyHBCPPFRLDU[6],~joyHBCPPFRLDU[5]}; // F2, F1
	
//wire joypad_data;
//wire p_sel = !host_select;
//wire p_start = !host_start;

wire joypad_strobe;
wire [1:0] joypad_clock;
reg [7:0] joypad_bits, joypad_bits2;
reg [1:0] last_joypad_clock;
 
wire [7:0] joystick1, joystick2;

  
// 1 if the button was pressed, 0 otherwise.
assign joystick1 = {~joy1_right_i, ~joy1_left_i, ~joy1_down_i, ~joy1_up_i, ~btn_n_i[1], ~btn_n_i[2], ~joy1_p9_i, ~joy1_p6_i};
assign joystick2 = {~joy2_right_i, ~joy2_left_i, ~joy2_down_i, ~joy2_up_i, ~btn_n_i[3], ~btn_n_i[4], ~joy2_p9_i, ~joy2_p6_i};
  
	
always @(posedge clk) begin
	if (joypad_strobe) begin
		joypad_bits  <= joystick1; 
		joypad_bits2 <= joystick2;
	end
		 
	if (!joypad_clock[0] && last_joypad_clock[0])
		joypad_bits <= {1'b0, joypad_bits[7:1]};

	if (!joypad_clock[1] && last_joypad_clock[1])
		joypad_bits2 <= {1'b0, joypad_bits2[7:1]};
			
	last_joypad_clock <= joypad_clock;
end


reg [1:0] nes_ce;
wire reset_nes = (!host_reset_n || !loader_done || !key0);     // Note that loader_done is 0 until first rom is loaded, so reset_nes = 1 at the same time
//wire run_mem = (nes_ce == 0) && !reset_nes;
wire run_nes = (nes_ce == 3) && !reset_nes;


// NES is clocked at every 4th cycle.
always @(posedge clk)
   nes_ce <= nes_ce + 2'b01;

wire [8:0] cycle;
wire [8:0] scanline;
wire [15:0] sample;
wire [5:0] color;
wire [21:0] memory_addr;
wire memory_read_cpu, memory_read_ppu;
wire memory_write;
wire [7:0] memory_din_cpu, memory_din_ppu;
wire [7:0] memory_dout;

wire [14:0] bram_addr;
wire [7:0] bram_din;
wire [7:0] bram_dout;
wire bram_write;
wire bram_override;

NES nes(clk, reset_nes, run_nes,
	mapper_flags,
	sample, color,
	joypad_strobe, joypad_clock, {2'b00, joypad_bits2[0], joypad_bits[0]},
	fds_swap, 
	5'b11111,
	memory_addr,
	memory_read_cpu, memory_din_cpu,
	memory_read_ppu, memory_din_ppu,
	memory_write, memory_dout,
    bram_addr, bram_din, bram_dout,
	bram_write, bram_override,
	cycle, scanline,
	int_audio,
	ext_audio,
	diskside_manual
   );

//wire [7:0] xor_data = 8'b0;            // MiSTer patch original fds bios when loading
//dpram #("fdspatch.mif", 13) biospatch  // instead of loading POWERPAK alredy modified bios
//(
//	.clock_a(clk),
//	.clock_b(clk),
//	.address_a(ioctl_addr[12:0]),
//	.q_a(xor_data)
//);

// loader_write -> clock when data available
reg loader_write_r;
reg loader_write_mem;
reg [7:0] loader_write_data_mem;
reg [21:0] loader_addr_mem;

reg loader_write_triggered;

always @(posedge clk) begin
	loader_write_r <= loader_write;
	if(loader_write && ! loader_write_r) begin
		loader_write_triggered <= 1'b1;
		loader_addr_mem <= loader_addr;
//		loader_write_data_mem <= (filetype == 2) ? loader_write_data ^ xor_data : loader_write_data;
		loader_write_data_mem <= loader_write_data;
	end

	if(nes_ce == 3) begin
		loader_write_mem <= loader_write_triggered;
		loader_write_triggered <= 1'b0;
	end
end


assign SDRAM_CKE  = 1'b1;

sdram sdram      //Adapted from NES Mister port
(
	// interface to the SDRAM chip
	.SDRAM_DQ     	( SDRAM_DQ   ),
	.SDRAM_A     	( SDRAM_A    ),
	.SDRAM_DQML		( SDRAM_DQML ),
	.SDRAM_DQMH		( SDRAM_DQMH ),
	.SDRAM_BA       ( SDRAM_BA   ),
	.SDRAM_nCS      ( SDRAM_nCS  ),
	.SDRAM_nWE      ( SDRAM_nWE  ),
	.SDRAM_nRAS     ( SDRAM_nRAS ),
	.SDRAM_nCAS     ( SDRAM_nCAS ),
	.SDRAM_CLK		( SDRAM_CLK  ),

	// system interface
	.clk      		( clk85         	),
	.init         	( !clock_locked     ),
	.clkref      	( nes_ce[1]         ),     //from sdram.v de10_lite port, but is not used inside sdram module

	// cpu/chipset interface
	.ch0_addr  		( downloading ? {3'b000, loader_addr_mem} : {3'b000, memory_addr} ),
	.ch0_wr    		( memory_write || loader_write_mem	),
	.ch0_din   		( downloading ? loader_write_data_mem : memory_dout ),
	.ch0_rd        	( memory_read_cpu  ),
	.ch0_dout      	( memory_din_cpu   ),

	.ch1_addr  		( downloading ? {3'b000, loader_addr_mem} : {3'b000, memory_addr} ),
	.ch1_wr    		( memory_write || loader_write_mem	),
	.ch1_din   		( downloading ? loader_write_data_mem : memory_dout ),
	.ch1_rd        	( memory_read_ppu ),
	.ch1_dout      	( memory_din_ppu  )
);



wire VGA_HS;
wire VGA_VS;
wire VGA_DE;
wire [7:0] VGA_R;
wire [7:0] VGA_G;
wire [7:0] VGA_B;
wire CE_PIXEL;


video video
(
	.*,
	.clk(clk85),

	.count_v(scanline),            // input [8:0]
	.count_h(cycle),               // input [8:0]
	.forced_scandoubler(forced_scandoubler), // input
	.scale(scale),                 // input [1:0]
	.hq2x(hq_enable),              // input
	.hide_overscan(hide_overscan), // input
	.palette(palette2_osd),        // input [2:0]

	.ce_pix (CE_PIXEL),             // output
	.VGA_HS (VGA_HS),
	.VGA_VS (VGA_VS),
	.VGA_DE (VGA_DE),
	.VGA_R  (VGA_R),
	.VGA_G  (VGA_G),
	.VGA_B  (VGA_B)
);


wire vga_hsync       = !VGA_HS;
wire vga_vsync       = !VGA_VS;
assign vga_hsync_n_o = !VGA_HS;
assign vga_vsync_n_o = !VGA_VS;

// audio
assign dac_l_o = audio;
assign dac_r_o = audio;
wire audio;
	
sigma_delta_dac sigma_delta_dac (
	.DACout         (audio),
	.DACin          (sample[15:8]),
	.CLK            (clk),
	.RESET          (reset_nes)
);


// from external controler (ZPU)
wire osd_window;
wire osd_pixel;
wire [15:0] dipswitches;
wire ext_audio      = 1'b1;
wire int_audio      = 1'b1;
wire mirroring_osd  = 1'b0;

wire [7:0] filetype; // 0 = normal NES rom or FDS rom with NES header, 2 = FDS POWERPAK bios, 3 FDS ROM 

wire scanlines            = dipswitches[0];     // applied at osd overlay level
wire hq_enable            = dipswitches[1];     // used in previous release
wire forced_scandoubler   = 1'b1;  		//dipswitches[2];     // Only VGA atm.
wire [1:0]scale           = dipswitches[4:3];   // scanlines intensity
wire hide_overscan        = dipswitches[5];     // 1'b1;   //dipswitches[5];
wire [2:0]palette2_osd    = dipswitches[8:6];   // 3'b011; dipswitches[8:6];
wire fds_swap             = dipswitches[9];     // select auto_swap or eject disk
wire [1:0]diskside_manual = dipswitches[11:10]; // diskside value added to auto_swap value
  
wire host_reset_n;
wire host_reset_loader;
wire host_divert_sdcard;
wire host_divert_keyboard;
wire host_select;
wire host_start;
   
wire [31:0] bootdata;
wire bootdata_req;
reg  bootdata_ack = 1'b0;
wire [31:0] rom_size;

CtrlModule control (
	.clk(clk_ctrl), 
	.reset_n(1'b1), 			
	.vga_hsync(vga_hsync), 
	.vga_vsync(vga_vsync), 
	.osd_window(osd_window), 
	.osd_pixel(osd_pixel), 
	.ps2k_clk_in( ps2_clk_io ), 
	.ps2k_dat_in( ps2_data_io ),
	.spi_miso( sd_miso_i ), 
	.spi_mosi( sd_mosi_o ), 
	.spi_clk( sd_sclk_o ), 
	.spi_cs( sd_cs_n_o ),
	
	.dipswitches(dipswitches), 
	.filetype(filetype),
	.size(rom_size), 
	.joy_pins({~(btn_n_i[4] || btn_n_i[3]), ~joy1_up_i, ~joy1_down_i, ~joy1_left_i, ~joy1_right_i, ~joy1_p6_i}), 
	.host_divert_sdcard(host_divert_sdcard), 
	.host_divert_keyboard(host_divert_keyboard), 
	.host_reset_n(host_reset_n), 
	.host_select(host_select), 
	.host_start(host_start),
	.host_reset_loader(host_reset_loader),
	.host_bootdata(bootdata), 
	.host_bootdata_req(bootdata_req), 
	.host_bootdata_ack(bootdata_ack)
);

wire [7:0] vga_osd_r;
wire [7:0] vga_osd_g;
wire [7:0] vga_osd_b;
	
OSD_Overlay osd (
	.clk(clk_ctrl),
	.red_in(   VGA_R), 
	.green_in( VGA_G), 
	.blue_in(  VGA_B), 
	.window_in(1'b1),
	.hsync_in(vga_hsync),
	.osd_window_in(osd_window),
	.osd_pixel_in(osd_pixel),
	.red_out(  vga_osd_r),
	.green_out(vga_osd_g),
	.blue_out( vga_osd_b),
	.window_out(),
	.scanline_ena(scanlines)
);

assign vga_r_o = vga_osd_r[7:5]; 
assign vga_g_o = vga_osd_g[7:5]; 
assign vga_b_o = vga_osd_b[7:5]; 
	

/////////////////////////////////
//// DECA HDMI & AUDIO CODEC ////
/////////////////////////////////

// PLL FOR DECA AUDIO CODEC & HDMI 

/*
// pll used only for testings
wire clock_vga2;
wire clock_locked2;
pll pll2 (
    .inclk0(max10_clk1_50),
	.c0(clock_vga2),	
	//.c1(I2S_SCLK),			//1.536 MHz
	//.c2(I2S_LRCLK),			//48 kHz
	.locked(clock_locked2)
	);
*/

//  HDMI I2C CONFIG
I2C_HDMI_Config u_I2C_HDMI_Config (
	.iCLK		(max10_clk1_50),
	.iRST_N		(key0         ),			//~reset_nes does not initilize HDMI until after first loaded rom
	.I2C_SCLK	(HDMI_I2C_SCL ),
	.I2C_SDAT	(HDMI_I2C_SDA ),
	.HDMI_TX_INT(HDMI_TX_INT  )
	);


//  HDMI VIDEO
assign HDMI_TX_CLK = clock_vga;    
//OK LG: clk=21.43, CE_PIXEL=21.43   //OK BENQ: clk85    //OK BOTH: clock_vga at 42.857 MHz
//NO OK BENQ:   clk=21.43 -45, -90º, -180º, -270
//At 26.75 MHz outputs HDMI 640x480 but with flickering. It does not start OSD anyway
assign HDMI_TX_DE = VGA_DE;
assign HDMI_TX_HS = !VGA_HS;   
assign HDMI_TX_VS = !VGA_VS;   
assign HDMI_TX_D  = {vga_osd_r,vga_osd_g,vga_osd_b};  	// output with OSD     // without OSD {VGA_R,VGA_G,VGA_B};     		 

//  HDMI AUDIO
assign HDMI_MCLK   = i2sMck;
assign HDMI_SCLK   = i2sSck;
assign HDMI_LRCLK  = i2sLr;
assign HDMI_I2S[0] = i2sD;

// AUDIO CODEC
wire   RESET_DELAY_n;
assign RESET_DELAY_n = ~reset_nes;

// Audio DAC DECA Output assignments
assign AUDIO_GPIO_MFP5  = 1'b1;  // GPIO
assign AUDIO_SPI_SELECT = 1'b1;  // SPI mode
assign AUDIO_RESET_n    = RESET_DELAY_n;    

// AUDIO CODEC SPI CONFIG
// I2S mode; fs = 48khz; MCLK = 24.567Mhz x 2
AUDIO_SPI_CTL_RD u1 (
	.iRESET_n	(RESET_DELAY_n  ), 	
	.iCLK_50	(max10_clk1_50  ), 	//50Mhz clock
	.oCS_n		(AUDIO_SCL_SS_n ),  //SPI interface mode chip-select signal
	.oSCLK		(AUDIO_SCLK_MFP3),  //SPI serial clock
	.oDIN		(AUDIO_SDA_MOSI ),  //SPI Serial data output
	.iDOUT		(AUDIO_MISO_MFP4)   //SPI serial data input
);
    
// I2S interface audio
i2s_transmitter 
#(
	//.mclk_rate( 21428571 ),
	.sample_rate( 48000 )	
)
i2s_transmitter_dut (
	.clock_i 	 (max10_clk1_50 ),
	.reset_i 	 (reset_nes ),
	.pcm_l_i 	 (sample >> 2 ),		// each right displacement reduces volume to half
	.pcm_r_i 	 (sample >> 2 ),
	.i2s_mclk_o  (i2sMck ),
	.i2s_lrclk_o (i2sLr ),
	.i2s_bclk_o  (i2sSck ),
	.i2s_d_o     (i2sD )
);

///////////////////////////////// End of Deca HDMI & Audio


reg write_fifo;
wire full_fifo;
wire [7:0] dout_fifo;
wire clk_rd_fifo;

reg boot_state = 1'b0;

fifo_loader loaderbuffer (
	.wrclk(clk_ctrl),
	.rdclk(clk_rd_fifo), 
	.data({bootdata[7:0],bootdata[15:8],bootdata[23:16],bootdata[31:24]}),
	.wrreq(write_fifo), 
	.rdreq(read_fifo), 
	.q(dout_fifo),
	.wrfull(full_fifo), 
	.rdempty(empty_fifo)
);
 
// manage fifo write 
always@( posedge clk_ctrl )
begin
	if (host_reset_loader == 1'b1) begin
		bootdata_ack <= 1'b0;
		boot_state <= 1'b0;
		write_fifo <= 1'b0;
	end else begin
		case (boot_state)
		
			1'b0:
				if (bootdata_req == 1'b1) 
				begin
				
					if (full_fifo == 1'b0) 
					begin
						write_fifo <= 1'b1;
						boot_state <= 1'b1;
						bootdata_ack <= 1'b1;
					end 
					
				end else begin
					bootdata_ack <= 1'b0;
				end
					
			1'b1: 
 				begin
					write_fifo <= 1'b0;
					boot_state <= 1'b0;
					bootdata_ack <= 1'b0;
				end
		endcase;
	end
end

// manage fifo read
reg  clk_loader;
wire clk_gameloader;
reg [7:0] loader_input;

reg [3:0] counter_fifo;
assign clk_rd_fifo = counter_fifo[3];
assign clk_gameloader = counter_fifo[2];
wire empty_fifo;
reg read_fifo;

always@( posedge clk )
begin
	counter_fifo <= counter_fifo + 1'b1;

	if (counter_fifo == 4'b1110 ) begin
		read_fifo <= !empty_fifo;
	end
	
	clk_loader <= !clk_rd_fifo && read_fifo && !loader_done;
end

// manage downloading flag
wire downloading;
wire end_download;

always@( posedge clk_ctrl )
begin
	if (host_reset_loader == 1'b1) begin
		downloading <= 1'b1;
		end_download <= 1'b0;
	end
	else begin
	
		if (host_reset_n == 1'b1) begin
			end_download <= 1'b1;
		end
	
		if ((end_download == 1'b1 ) && (empty_fifo == 1'b1)) begin
			downloading <= 1'b0;
		end
	end
end

always@( posedge clk_loader)
begin
	loader_input <= dout_fifo;
end

wire [21:0] loader_addr;
wire [7:0]  loader_write_data;
wire loader_reset = host_reset_loader;
wire loader_write;
wire loader_done, loader_fail;
  
wire [31:0] loader_flags;
reg  [31:0] mapper_flags;

GameLoader loader
(
	clk_gameloader, loader_reset, downloading, filetype,
	loader_input, clk_loader, mirroring_osd,
	loader_addr, loader_write_data, loader_write,
	loader_flags, loader_done, loader_fail
);

always @(posedge clk) begin
	if (loader_done) mapper_flags <= loader_flags;
end


/////// Debugging code (SAFE TO BE COMMENTED/REMOVED)

assign led[0] = 1'b0 | reset_nes;	//will not switch on until first rom is loaded due to reset_nes being 1
assign led[7:1] = 7'b1111111;

/*
assign led[1] = ~loader_done ;
assign led[2] = ~loader_fail ;
assign led[3] = ~led4;
assign led[4] = host_reset_n;
assign led[5] = 1'b0;
assign led[6] = ~bootup;			// switch on after aprox 30 s
assign led[7] = count[25];


// signal bootup to do things during bootup
reg bootup = 1'b0; 
reg [29:0] countx = 30'b0;
always @(posedge clk) begin
	begin
		countx <= countx + 1'b1;
		if ((countx[29] == 1))
			begin
				bootup <= 1'b1;     // after aprox 30 s
			end
	end
end
//

reg led4 = 1'b0;
reg [25:0] countled = 26'b0;
reg [25:0] count = 26'b0;

always @(posedge clk)
begin
	if (downloading == 1'b1) 
		begin
			led4 <= 1'b1;
			countled <= 26'b0;
		end
	else
		if (led4 == 1'b1 )
			begin
				countled <= countled + 1'b1;
				if (countled[25] == 1 )
					begin
						led4 <= 1'b0;
						countled <= 26'b0;
					end
			end
	count <= count + 1'b1;

end
*/
/////// End Debugging code


endmodule





/////////////////////////////////////////////////////////////////////////
// Module reads bytes and writes to proper address in ram.
// Done is asserted when the whole game is loaded.
// This parses iNES headers too.
module GameLoader
(
	input         clk,
	input         reset,
	input         downloading,
	input   [7:0] filetype,
	input   [7:0] indata,
	input         indata_clk,
	input         invert_mirroring,
	output reg [21:0] mem_addr,
	output [7:0]  mem_data,
	output        mem_write,
	output [31:0] mapper_flags,
	output reg    done,
	output reg    error
);

reg [2:0] state;
reg [7:0] prgsize;
reg [3:0] ctr;
reg [7:0] ines[0:15]; // 16 bytes of iNES header
reg [21:0] bytes_left;
  
wire [7:0] prgrom = ines[4];	// Number of 16384 byte program ROM pages
wire [7:0] chrrom = ines[5];	// Number of 8192 byte character ROM pages (0 indicates CHR RAM)
wire has_chr_ram = (chrrom == 0);
assign mem_data = indata;
assign mem_write = ((bytes_left != 0) && (state == 1 || state == 2) || (downloading && (state == 0 || state == 4))) && indata_clk;
  
wire [2:0] prg_size = prgrom <= 1  ? 3'd0 :			// 16KB
                      prgrom <= 2  ? 3'd1 : 		// 32KB
                      prgrom <= 4  ? 3'd2 : 		// 64KB
                      prgrom <= 8  ? 3'd3 : 		// 128KB
                      prgrom <= 16 ? 3'd4 : 		// 256KB
                      prgrom <= 32 ? 3'd5 : 		// 512KB
                      prgrom <= 64 ? 3'd6 : 3'd7;// 1MB/2MB
                        
wire [2:0] chr_size = chrrom <= 1  ? 3'd0 : 		// 8KB
                      chrrom <= 2  ? 3'd1 : 		// 16KB
                      chrrom <= 4  ? 3'd2 : 		// 32KB
                      chrrom <= 8  ? 3'd3 : 		// 64KB
                      chrrom <= 16 ? 3'd4 : 		// 128KB
                      chrrom <= 32 ? 3'd5 : 		// 256KB
                      chrrom <= 64 ? 3'd6 : 3'd7;// 512KB/1MB
  
// detect iNES2.0 compliant header
wire is_nes20 = (ines[7][3:2] == 2'b10);
// differentiate dirty iNES1.0 headers from proper iNES2.0 ones
wire is_dirty = !is_nes20 && ((ines[9][7:1] != 0)
								  || (ines[10] != 0)
								  || (ines[11] != 0)
								  || (ines[12] != 0)
								  || (ines[13] != 0)
								  || (ines[14] != 0)
								  || (ines[15] != 0));

// Read the mapper number
wire [7:0] mapper = {is_dirty ? 4'b0000 : ines[7][7:4], ines[6][7:4]};
wire [7:0] ines2mapper = {is_nes20 ? ines[8] : 8'h00};
  
// ines[6][0] is mirroring
// ines[6][3] is 4 screen mode
assign mapper_flags = {7'b0, ines2mapper, ines[6][3], has_chr_ram, ines[6][0] ^ invert_mirroring, chr_size, prg_size, mapper};

always @(posedge clk) begin
	if (reset) begin
		state <= 0;
		done <= 0;
		ctr <= 0;
		mem_addr <= filetype == 8'h03 ? 22'b00_0100_0000_0000_0001_0000 : 22'b00_0000_0000_0000_0000_0000;  // Address for FDS : BIOS/PRG
	end else begin
		case(state)
		// Read 16 bytes of ines header
		0: if (indata_clk) begin
			  error <= 0;
			  ctr <= ctr + 1'd1;
			  mem_addr <= mem_addr + 1'd1;
			  ines[ctr] <= indata;
			  bytes_left <= {prgrom, 14'b0};
			  if (ctr == 4'b1111) begin
				 // Check the 'NES' header. Also, we don't support trainers.
				 if ((ines[0] == 8'h4E) && (ines[1] == 8'h45) && (ines[2] == 8'h53) && (ines[3] == 8'h1A) && !ines[6][2]) begin
					mem_addr <= 0;  // Address for PRG
					state <= 1;
				 //FDS
				 end else if ((ines[0] == 8'h46) && (ines[1] == 8'h44) && (ines[2] == 8'h53) && (ines[3] == 8'h1A)) begin
					mem_addr <= 22'b00_0100_0000_0000_0001_0000;  // Address for FDS skip Header
					state <= 4;
					bytes_left <= 21'b1;
				 end else if (filetype[7:0]==8'h02) begin // Bios
					state <= 4;
					mem_addr <= 22'b00_0000_0000_0000_0001_0000;  // Address for BIOS skip Header
					bytes_left <= 21'b1;
				 end else if (filetype[7:0]==8'h03) begin // FDS
					state <= 4;
					mem_addr <= 22'b00_0100_0000_0000_0010_0000;  // Address for FDS no Header
					bytes_left <= 21'b1;
				 end else begin
					state <= 3;
				 end
			  end
			end
		1, 2: begin // Read the next |bytes_left| bytes into |mem_addr|
			 if (bytes_left != 0) begin
				if (indata_clk) begin
				  bytes_left <= bytes_left - 1'd1;
				  mem_addr <= mem_addr + 1'd1;
				end
			 end else if (state == 1) begin
				state <= 2;
				mem_addr <= 22'b10_0000_0000_0000_0000_0000; // Address for CHR
				bytes_left <= {1'b0, chrrom, 13'b0};
			 end else if (state == 2) begin
				done <= 1;
			 end
			end
		3: begin
				done <= 1;
				error <= 1;
			end
		4: begin // Read the next |bytes_left| bytes into |mem_addr|
			 if (downloading) begin
				if (indata_clk) begin
				  mem_addr <= mem_addr + 1'd1;
				end
			 end else begin
				done <= 1;
				bytes_left <= 21'b0;
				ines[4] <= 8'hFF;//no masking
				ines[5] <= 8'h00;//0x2000
				ines[6] <= 8'h40;
				ines[7] <= 8'h10;
				ines[8] <= 8'h00;
				ines[9] <= 8'h00;
				ines[10] <= 8'h00;
				ines[11] <= 8'h00;
				ines[12] <= 8'h00;
				ines[13] <= 8'h00;
				ines[14] <= 8'h00;
				ines[15] <= 8'h00;
			 end
			end
		endcase
	end
end
endmodule
