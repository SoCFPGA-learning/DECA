`timescale 1ns / 1ps
`default_nettype none

//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:   01:24:02 08/15/2016 
// Design Name: 
// Module Name:   tld_test_prod_v4 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments:      
//
// https://github.com/neptuno-fpga/board_test
//
//////////////////////////////////////////////////////////////////////////////////

module tld_test_placa_deca_neptuno (
  input wire clk50mhz,
  //---------------------------
  input wire clkps2,
  input wire dataps2,
  //---------------------------
  inout wire mousedata,
  inout wire mouseclk,
  //---------------------------
  output wire testled1,
  //output wire testled2,
  //---------------------------
  //output wire ser_tx,
  //output wire ser_rx,
  //---------------------------
  // MicroSD Card 
  input         sd_miso,
  output        sd_mosi,
  output        sd_clk,
  output        sd_cs_n,
  output	SD_SEL,
  output	SD_CMD_DIR,
  output	SD_D0_DIR,
  output	SD_D123_DIR,
  //---------------------------
  
  /*
  output wire [20:0] sram_addr,
  inout  wire [15:0] sram_data,
  output wire sram_we_n,
  output wire sram_ub_n,
  output wire sram_lb_n,
  output wire sram_oe_n,
  */
  
  /*   usa desplazadores
  output wire JOY_CLK,
  output wire JOY_LOAD,
  input  wire JOY_DATA,
  output wire joyP7_o, 
  */

  //---------------------------
  output wire sdram_clk,       // señales validas en flanco de suida de CK
  output wire sdram_cke,
  output wire sdram_dqmh_n,    // mascara para byte alto o bajo
  output wire sdram_dqml_n,    // durante operaciones de escritura
  output wire [12:0] sdram_addr, // pag.14. row=[12:0], col=[8:0]. A10=1 significa precharge all.
  output wire [1:0] sdram_ba,   // banco al que se accede
  output wire sdram_cs_n,
  output wire sdram_we_n,
  output wire sdram_ras_n,
  output wire sdram_cas_n,
  inout tri [15:0] sdram_dq,
  //---------------------------
  output wire [2:0] r,
  output wire [2:0] g,
  output wire [2:0] b,
  output wire hsync,
  output wire vsync,
  output wire audio_out_left,
  output wire audio_out_right,
  //--------------------------
  output wire stm_rst_o = 1'b0
  );

/*
  wire [15:0] sram_data_int;
  assign sram_data = sram_we_n ? (sram_oe_n ? {4'hZ, lrclk, sdin, sclk, mclk, 8'hZZ} : 16'hZZZZ) : sram_oe_n ? 16'hZZZZ : sram_data_int[15:0];
  assign sram_data_int = sram_we_n ? sram_data[15:0] : 16'hZZZZ ;
  assign sram_ub_n = 1'b0;
  assign sram_lb_n = 1'b0;
  assign sram_addr[20] = 1'b0;
  assign sram_oe_n = ~memtest_progress;
*/

  // MicroSD Card 
  assign SD_SEL = 1'b0;   //0 = 3.3V at sdcard		
  assign SD_CMD_DIR = 1'b1;  // MOSI FPGA output	
  assign SD_D0_DIR = 1'b0;   // MISO FPGA input	
  assign SD_D123_DIR = 1'b1; // CS FPGA output	
  // 

  wire [5:0] r_out;
  wire [5:0] g_out;
  wire [5:0] b_out;

  wire mclk;
  wire sclk;
  wire lrclk;
  wire sdin;

  wire clk100, clk100n, clk14, clk7;
  wire clocks_ready;
  
  wire mode, vga;

  wire [5:0] r_to_vga, g_to_vga, b_to_vga;
  wire hsync_to_vga, vsync_to_vga, csync_to_vga;

  wire memtest_init_fast, memtest_init_slow, memtest_progress, memtest_result;
  wire sdtest_init, sdtest_progress, sdtest_result;
  wire flashtest_init, flashtest_progress, flashtest_result;
  wire sdramtest_init, sdramtest_progress, sdramtest_result;
  wire hidetextwindow;

  wire [2:0] mousebutton;  // M R L
  wire mousetest_init;

  wire [15:0] flash_vendor_id;

/*
   wire joy1up;
   wire joy1down;
   wire joy1left;
   wire joy1right;
   wire joy1fire1;
   wire joy1fire2;
   wire joy1start;
   wire joy2up;
   wire joy2down;
   wire joy2left;
   wire joy2right;
   wire joy2fire1;
   wire joy2fire2;
   wire joy2start;
*/

	//assign joyP7_o = 1'b1;
	
/*
	wire [11:0] joy1_o;
	wire [11:0] joy2_o;
	wire clk_joy;
*/


  relojes los_relojes (
   .inclk0(clk50mhz),
   .c0(clk100),
   .c1(clk100n),
   .c2(clk14),
   .c3(clk7),
   .locked(clocks_ready)
   );

/*
// Llamamos a la instancia de los Joysticks
	joydecoder los_joysticks (
      .clk(clk50mhz),
      .joy_data(JOY_DATA),
      .joy_clk(JOY_CLK),
      .joy_load_n(JOY_LOAD),
      .joy1up(joy1up),
      .joy1down(joy1down),
      .joy1left(joy1left),
      .joy1right(joy1right),
      .joy1fire1(joy1fire1),
      .joy1fire2(joy1fire2),
      .joy2up(joy2up),
      .joy2down(joy2down),
      .joy2left(joy2left),
      .joy2right(joy2right),
      .joy2fire1(joy2fire1),
      .joy2fire2(joy2fire2),
		.hsync(hsync)
   );
	// assign joyP7_o = 1'bz;
*/

/*
// PARA 6 BOTONES
// Llamamos a la maquina de estados para leer los 6 botones del mando de Megadrive
// Formato joy1_o [11:0] =  MXYZ SACB RLDU		
  sega_joystick joy (
	 .joy1_up_i		(joy1up),
    .joy1_down_i	(joy1down),
	 .joy1_left_i	(joy1left),
	 .joy1_right_i	(joy1right),
	 .joy1_p6_i		(joy1fire1),
	 .joy1_p9_i		(joy1fire2),
	 .joy2_up_i		(joy2up),
    .joy2_down_i	(joy2down),
	 .joy2_left_i	(joy2left),
	 .joy2_right_i	(joy2right),
	 .joy2_p6_i		(joy2fire1),
	 .joy2_p9_i		(joy2fire2),
	 .vga_hsync_n_s(hsync),
	 .joyX_p7_o		(joyP7_o),
	 .joy1_o			(joy1_o),
	 .joy2_o			(joy2_o)
 );
*/

  switch_mode teclas (
    .clk(clk7),
    .clkps2(clkps2),
    .dataps2(dataps2),
    .mode(mode),
    .vga(vga),
    .sdtest(sdtest_init),    
    //.flashtest(flashtest_init),
    .mousetest(mousetest_init),
    .sdramtest(sdramtest_init),
    .memtestf(memtest_init_fast),
    .memtests(memtest_init_slow),
    //.serialtest(),
    .hidetextwindow(hidetextwindow)
  );

  /*
  ramtest test_de_ram (
    .clk(clk100),
    .hold(~clocks_ready),
    .rstf(memtest_init_fast),
    .rsts(memtest_init_slow),
    .sram_a(sram_addr[19:0]),
    .sram_d(sram_data_int),
    .sram_we_n(sram_we_n),
    .test_in_progress(memtest_progress),
    .test_result(memtest_result)
  );
  */

  
  sdtest test_slot_sd (
    .clk(clk7),
    .rst(sdtest_init),
    .spi_clk(sd_clk),
    .spi_di(sd_mosi),
    .spi_do(sd_miso),
    .spi_cs(sd_cs_n),
    .test_in_progress(sdtest_progress),
    .test_result(sdtest_result)
  );


  mousetest test_raton (
    .clk(clk7),
    .rst(mousetest_init),
    .ps2clk(mouseclk),
    .ps2data(mousedata),
    .botones(mousebutton)
  );

  sdramtest #(.FREQCLKSDRAM(100), .CL(3)) test_sdram (
    .clk(clk100),
    .clksdram(clk100n),
    .rst(sdramtest_init),
    .pll_locked(clocks_ready),
    .test_in_progress(sdramtest_progress),
    .test_result(sdramtest_result),
    .sdram_clk(sdram_clk),       // señales validas en flanco de suida de CK
    .sdram_cke(sdram_cke),
    .sdram_dqmh_n(sdram_dqmh_n),    // mascara para byte alto o bajo
    .sdram_dqml_n(sdram_dqml_n),    // durante operaciones de escritura
    .sdram_addr(sdram_addr), // pag.14. row=[12:0], col=[8:0]. A10=1 significa precharge all.
    .sdram_ba(sdram_ba),   // banco al que se accede
    .sdram_cs_n(sdram_cs_n),
    .sdram_we_n(sdram_we_n),
    .sdram_ras_n(sdram_ras_n),
    .sdram_cas_n(sdram_cas_n),
    .sdram_dq(sdram_dq)   
  );

  updater mensajes (     // video_processor.v
    .clk(clk7),
    .mode(mode),
    .vga(vga),

/*
    // PARA 6 BOTONES
    // joystick1 format -- MXYZ SA UDLR BC       joy1_o [11:0] -- MXYZ SACB RLDU	 
    .joystick1(~{joy1_o[11], joy1_o[10],joy1_o[9],joy1_o[8],joy1_o[7],joy1_o[6],joy1_o[3],joy1_o[2],joy1_o[1],joy1_o[0],joy1_o[4],joy1_o[5]}),
    // joystick2 format -- MXYZ SA UDLR BC       joy2_o [11:0] -- MXYZ SACB RLDU 
    .joystick2(~{joy2_o[11], joy2_o[10],joy2_o[9],joy2_o[8],joy2_o[7],joy2_o[6],joy2_o[3],joy2_o[2],joy2_o[1],joy2_o[0],joy2_o[4],joy2_o[5]}),  
    //.joystick1({joy1up,joy1down,joy1left,joy1right,joy1fire1,joy1fire2}),
    //.joystick2({joy2up,joy2down,joy2left,joy2right,joy2fire1,joy2fire2}),
*/
    .memtest_progress(memtest_progress),
    .memtest_result(memtest_result),
    .sdtest_progress(sdtest_progress),
    .sdtest_result(sdtest_result),
    .flashtest_progress(flashtest_progress),
    .flashtest_result(flashtest_result),
    .flash_vendor_id(flash_vendor_id),
    .sdramtest_progress(sdramtest_progress),
    .sdramtest_result(sdramtest_result),
    .mousebutton(mousebutton),     
    .hidetextwindow(hidetextwindow),
    
    .r(r_to_vga),
    .g(g_to_vga),
    .b(b_to_vga),
    .hsync(hsync_to_vga),
    .vsync(vsync_to_vga),
    .csync(csync_to_vga)
    );

  vga_scandoubler #(.CLKVIDEO(7000)) modo_vga (
    .clkvideo(clk7),
    .clkvga(clk14),
    .enable_scandoubling(vga),
    .disable_scaneffect(1'b1),
    .ri(r_to_vga),
    .gi(g_to_vga),
    .bi(b_to_vga),
    .hsync_ext_n(hsync_to_vga),
    .vsync_ext_n(vsync_to_vga),
    .csync_ext_n(csync_to_vga),
    .ro(r_out),
    .go(g_out),
    .bo(b_out),
    .hsync(hsync),
    .vsync(vsync)
  );

  audio_test audio (
    .clk(clk14),
    .clk50mhz(clk50mhz),
    .left(audio_out_left),
    .right(audio_out_right),
    .led1(testled1),
    .MCLK(mclk),
    .SCLK(sclk),
    .LRCLK(lrclk),
    .SDIN(sdin)
  );
  
  
  assign r = r_out[5:3];
  assign g = g_out[5:3];
  assign b = b_out[5:3];

endmodule
