// Next186 SoC NeptUNO port by DistWave -- https://github.com/neptuno-fpga/Next186_SoC
// DECA port by Somhic & Shaeon

module Next186_SoC(

	input 	CLOCK_50,
	output	[12:0]DRAM_ADDR,
	output	[1:0]DRAM_BA,
	output	DRAM_CAS_N,
	output	DRAM_CKE,
	output	DRAM_CLK,
	output	DRAM_CS_N,
	inout	[15:0]DRAM_DQ,
	output	[1:0]DRAM_DQM,
	output	DRAM_RAS_N,
	output	DRAM_WE_N,
//	output [19:0] SRAM_ADDR,
//	inout [15:0] SRAM_DQ,
//	output SRAM_OE_N,
//	output SRAM_WE_N,
//	output SRAM_UB_N,
//	output SRAM_LB_N,
	output [2:0]VGA_R,
	output [2:0]VGA_G,
	output [2:0]VGA_B,
	output VGA_VSYNC,
	output VGA_HSYNC,
	output SDLED,
	input BTN_SOUTH,
	input BTN_WEST,
	inout PS2_CLKA,
	inout PS2_DATA,
	inout PS2_CLKB,
	inout PS2_DATB,
	output AUDIO_L,
	output AUDIO_R,
	output SD_nCS,
	input SD_DO,
	output SD_CK,
	output SD_DI,
	//
	output	SD_SEL,
	output	SD_CMD_DIR,
	output	SD_D0_DIR,
	output	SD_D123_DIR,
	//
	input RX_EXT,
	output TX_EXT,
	output MIDI_OUT,
	input CLKBD,
	input WSBD,
	input DABD,
	output LRCLK,
	output SDIN,
	output SCLK,
	// Audio DAC DECA
	output wire i2sMck,	//AUDIO_MCLK
	inout wire 	AUDIO_GPIO_MFP5,
	input wire 	AUDIO_MISO_MFP4,
	inout wire 	AUDIO_RESET_n,
	output wire AUDIO_SCLK_MFP3,
	output wire AUDIO_SCL_SS_n,
	inout wire 	AUDIO_SDA_MOSI,
	output wire AUDIO_SPI_SELECT
	//
//	output STM_RST
);

	// VGA 666 to 333 
	wire [5:0] VGA_R_out;
	wire [5:0] VGA_G_out;
	wire [5:0] VGA_B_out;
	assign VGA_R = VGA_R_out[5:3];
	assign VGA_G = VGA_G_out[5:3];
	assign VGA_B = VGA_B_out[5:3];
	//

	// MicroSD Card 
	assign SD_SEL = 1'b0;   //0 = 3.3V at sdcard		
	assign SD_CMD_DIR = 1'b1;  // MOSI FPGA output	
	assign SD_D0_DIR = 1'b0;   // MISO FPGA input	
	assign SD_D123_DIR = 1'b1; // CS FPGA output	
	// 

	wire SDR_CLK;
	wire [7:0]LEDS;
	assign DRAM_CKE = 1'b1;
/*	
	assign SRAM_ADDR = 20'h00000;
	assign SRAM_DQ[15:0] = 16'hZZZZ;
	assign SRAM_OE_N = 1'b1;
	assign SRAM_WE_N = 1'b1;
	assign SRAM_UB_N = 1'b1;
	assign SRAM_LB_N = 1'b1;
*/
//	assign STM_RST = 1'b0;
	assign SDLED = ~LEDS[1];

	//--RESET DELAY ---  
   reg RESET_DELAY_n;
   reg   [31:0]  DELAY_CNT;   

	always @(negedge BTN_SOUTH ) begin 
	if ( BTN_SOUTH )  begin 
			RESET_DELAY_n <= 0;
			DELAY_CNT   <= 0;
		end 
	else  begin 
			if ( DELAY_CNT < 32'hfffff  )  
				DELAY_CNT <= DELAY_CNT+1; 
			else 
				RESET_DELAY_n <= 1;
		end
	end

	// Audio DAC DECA Output assignments
    assign AUDIO_GPIO_MFP5  = 1;  // GPIO
    assign AUDIO_SPI_SELECT = 1;  // SPI mode
    assign AUDIO_RESET_n    = RESET_DELAY_n;    

    // AUDIO CODEC SPI CONFIG
    // I2S mode; fs = 48khz; MCLK = 24.567MhZ x 2
    AUDIO_SPI_CTL_RD u1 (
        .iRESET_n(RESET_DELAY_n), 
        .iCLK_50(CLOCK_50),		//50Mhz clock
        .oCS_n(AUDIO_SCL_SS_n),   //SPI interface mode chip-select signal
        .oSCLK(AUDIO_SCLK_MFP3),  //SPI serial clock
        .oDIN(AUDIO_SDA_MOSI),    //SPI Serial data output
        .iDOUT(AUDIO_MISO_MFP4)   //SPI serial data input
    );

	dd_buf sdrclk_buf
	(
		.datain_h(1'b1),
		.datain_l(1'b0),
		.outclock(SDR_CLK),
		.dataout(DRAM_CLK)
	);

	system sys_inst
	(
		.CLK_50MHZ(CLOCK_50),
		.VGA_R(VGA_R_out),
		.VGA_G(VGA_G_out),
		.VGA_B(VGA_B_out),
		.frame_on(),
		.VGA_HSYNC(VGA_HSYNC),
		.VGA_VSYNC(VGA_VSYNC),
		.sdr_CLK_out(SDR_CLK),
		.sdr_n_CS_WE_RAS_CAS({DRAM_CS_N, DRAM_WE_N, DRAM_RAS_N, DRAM_CAS_N}),
		.sdr_BA(DRAM_BA),
		.sdr_ADDR(DRAM_ADDR),
		.sdr_DATA(DRAM_DQ),
		.sdr_DQM({DRAM_DQM}),
		.LED(LEDS),
		.BTN_RESET(~BTN_SOUTH),
		.BTN_NMI(~BTN_WEST),
		.RS232_DCE_RXD(RX_EXT),
		.RS232_DCE_TXD(TX_EXT),
		.RS232_EXT_RXD(),
		.RS232_EXT_TXD(),
		.SD_n_CS(SD_nCS),
		.SD_DI(SD_DI),
		.SD_CK(SD_CK),
		.SD_DO(SD_DO),
		.AUD_L(AUDIO_L),
		.AUD_R(AUDIO_R),
	 	.PS2_CLK1(PS2_CLKA),
		.PS2_CLK2(PS2_CLKB),
		.PS2_DATA1(PS2_DATA),
		.PS2_DATA2(PS2_DATB),
		.RS232_HOST_RXD(),
		.RS232_HOST_TXD(),
		.RS232_HOST_RST(),
		.GPIO(),
		.I2C_SCL(),
		.I2C_SDA(),
		.I2S_LRCLK(LRCLK),
		.I2S_SDIN(SDIN),
		.I2S_SCLK(SCLK),
		.I2S_MCLK(),
		.MIDI_OUT(MIDI_OUT),
		.CLKBD(CLKBD),
		.WSBD(WSBD),
		.DABD(DABD)
	);

	
endmodule

