// Copyright (c) 2012-2013 Ludvig Strigeus
// This program is GPL Licensed. See COPYING for the full license.

// No mapper chip
module MMC0(input clk, input ce,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                      // Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
  assign prg_aout = {7'b00_0000_0, prg_ain[14:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
  assign chr_aout = {9'b10_0000_000, chr_ain[12:0]};
  assign vram_ce = chr_ain[13];
  assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];
endmodule

// MMC1 mapper chip. Maps prg or chr addresses into a linear address.
// If vram_ce is set, {vram_a10, chr_aout[9:0]} are used to access the NES internal VRAM instead.
module MMC1(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                      // Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
  reg [4:0] shift;
  
// CPPMM
// |||||
// |||++- Mirroring (0: one-screen, lower bank; 1: one-screen, upper bank;
// |||               2: vertical; 3: horizontal)
// |++--- PRG ROM bank mode (0, 1: switch 32 KB at $8000, ignoring low bit of bank number;
// |                         2: fix first bank at $8000 and switch 16 KB bank at $C000;
// |                         3: fix last bank at $C000 and switch 16 KB bank at $8000)
// +----- CHR ROM bank mode (0: switch 8 KB at a time; 1: switch two separate 4 KB banks)
  reg [4:0] control;

// CCCCC
// |||||
// +++++- Select 4 KB or 8 KB CHR bank at PPU $0000 (low bit ignored in 8 KB mode)
  reg [4:0] chr_bank_0;

// CCCCC
// |||||
// +++++- Select 4 KB CHR bank at PPU $1000 (ignored in 8 KB mode)
  reg [4:0] chr_bank_1;
  
// RPPPP
// |||||
// |++++- Select 16 KB PRG ROM bank (low bit ignored in 32 KB mode)
// +----- PRG RAM chip enable (0: enabled; 1: disabled; ignored on MMC1A)
  reg [4:0] prg_bank;

  reg delay_ctrl;	// used to prevent fast-write to the control register

  wire [2:0] prg_size = flags[10:8];
   
  // Update shift register
  always @(posedge clk) if (reset) begin
		shift <= 5'b10000;
		control <= 5'b0_11_00;
		chr_bank_0 <= 0;
		chr_bank_1 <= 0;
		prg_bank <= 5'b00000;
		delay_ctrl <= 0;
  end else if (ce) begin
    if (!prg_write)
		delay_ctrl <= 1'b0;
    if (prg_write && prg_ain[15] && !delay_ctrl) begin
	   delay_ctrl <= 1'b1;
      if (prg_din[7]) begin
        shift <= 5'b10000;
        control <= control | 5'b0_11_00;
//        $write("MMC1 RESET!\n");
      end else begin
        if (shift[0]) begin
//          $write("MMC1 WRITE %X to %X!\n", {prg_din[0], shift[4:1]}, prg_ain);
          casez(prg_ain[14:13])
          0: control    <= {prg_din[0], shift[4:1]};
          1: chr_bank_0 <= {prg_din[0], shift[4:1]};
          2: chr_bank_1 <= {prg_din[0], shift[4:1]};
          3: prg_bank   <= {prg_din[0], shift[4:1]};
          endcase
          shift <= 5'b10000;
        end else begin
          shift <= {prg_din[0], shift[4:1]};
        end
      end
    end
  end
  
  // The PRG bank to load. Each increment here is 16kb. So valid values are 0..15.
  // prg_ain[14] selects bank0 ($8000) or bank1 ($C000)
  reg [3:0] prgsel;  
  always @* begin
    casez({control[3:2], prg_ain[14]})
    3'b0?_?: prgsel = {prg_bank[3:1], prg_ain[14]};	// Swap 32Kb
    3'b10_0: prgsel = 4'b0000;								// Swap 16Kb at $C000 with access at $8000, so select page 0 (hardcoded)
    3'b10_1: prgsel = prg_bank[3:0];						// Swap 16Kb at $C000 with $C000 access, so select page based on prg_bank (register 3)
    3'b11_0: prgsel = prg_bank[3:0];						// Swap 16Kb at $8000 with $8000 access, so select page based on prg_bank (register 3)
    3'b11_1: prgsel = 4'b1111;								// Swap 16Kb at $8000 with $C000 access, so select last page (hardcoded)
    endcase
  end
  
  // The CHR bank to load. Each increment here is 4 kb. So valid values are 0..31.
  reg [4:0] chrsel;
  always @* begin
    casez({control[4], chr_ain[12]})
    2'b0_?: chrsel = {chr_bank_0[4:1], chr_ain[12]};
    2'b1_0: chrsel = chr_bank_0;
    2'b1_1: chrsel = chr_bank_1;
    endcase
  end
  assign chr_aout = {5'b100_00, chrsel, chr_ain[11:0]};
  wire [21:0] prg_aout_tmp = prg_size == 5 ? {3'b000, chrsel[4], prgsel, prg_ain[13:0]}	// for large PRG ROM, CHR A16 selects the 256KB PRG bank
														 : {4'b00_00, prgsel, prg_ain[13:0]};
  
  // The a10 VRAM address line. (Used for mirroring)
  reg vram_a10_t;
  always @* begin
    casez(control[1:0])
    2'b00: vram_a10_t = 0;             // One screen, lower bank
    2'b01: vram_a10_t = 1;             // One screen, upper bank
    2'b10: vram_a10_t = chr_ain[10];   // One screen, vertical
    2'b11: vram_a10_t = chr_ain[11];   // One screen, horizontal
    endcase
  end
  assign vram_a10 = vram_a10_t;
  assign vram_ce = chr_ain[13];
  
  wire prg_is_ram = prg_ain >= 'h6000 && prg_ain < 'h8000;
  assign prg_allow = prg_ain[15] && !prg_write || prg_is_ram;
  wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
  
  assign prg_aout = prg_is_ram ? prg_ram : prg_aout_tmp;
  assign chr_allow = flags[15];
endmodule

// MMC2 mapper chip. PRG ROM: 128kB. Bank Size: 8kB. CHR ROM: 128kB
module MMC2(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input chr_read, input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                      // Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.

// PRG ROM bank select ($A000-$AFFF)
// 7  bit  0
// ---- ----
// xxxx PPPP
//      ||||
//      ++++- Select 8 KB PRG ROM bank for CPU $8000-$9FFF
  reg [3:0] prg_bank;

// CHR ROM $FD/0000 bank select ($B000-$BFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $0000-$0FFF
//            used when latch 0 = $FD
  reg   [4:0] chr_bank_0a;

// CHR ROM $FE/0000 bank select ($C000-$CFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $0000-$0FFF
//            used when latch 0 = $FE
   reg [4:0] chr_bank_0b;
   
// CHR ROM $FD/1000 bank select ($D000-$DFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $1000-$1FFF
//            used when latch 1 = $FD
  reg [4:0] chr_bank_1a;
   
// CHR ROM $FE/1000 bank select ($E000-$EFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $1000-$1FFF
//            used when latch 1 = $FE
  reg [4:0] chr_bank_1b; 
  
// Mirroring ($F000-$FFFF)
// 7  bit  0
// ---- ----
// xxxx xxxM
//         |
//         +- Select nametable mirroring (0: vertical; 1: horizontal)  
  reg mirroring;
  
  reg latch_0, latch_1;
	
  // Update registers
  always @(posedge clk) if (ce) begin
    if (prg_write && prg_ain[15]) begin
      case(prg_ain[14:12])
      2: prg_bank <= prg_din[3:0];     // $A000
      3: chr_bank_0a <= prg_din[4:0];  // $B000
      4: chr_bank_0b <= prg_din[4:0];  // $C000
      5: chr_bank_1a <= prg_din[4:0];  // $D000
      6: chr_bank_1b <= prg_din[4:0];  // $E000
      7: mirroring <=  prg_din[0];     // $F000
      endcase
    end
  end
  
// PPU reads $0FD8: latch 0 is set to $FD for subsequent reads
// PPU reads $0FE8: latch 0 is set to $FE for subsequent reads
// PPU reads $1FD8 through $1FDF: latch 1 is set to $FD for subsequent reads
// PPU reads $1FE8 through $1FEF: latch 1 is set to $FE for subsequent reads
  always @(posedge clk) if (ce && chr_read) begin
    latch_0 <= (chr_ain & 14'h3fff) == 14'h0fd8 ? 1'd0 : (chr_ain & 14'h3fff) == 14'h0fe8 ? 1'd1 : latch_0;
    latch_1 <= (chr_ain & 14'h3ff8) == 14'h1fd8 ? 1'd0 : (chr_ain & 14'h3ff8) == 14'h1fe8 ? 1'd1 : latch_1;
  end
  
  // The PRG bank to load. Each increment here is 8kb. So valid values are 0..15.
  reg [3:0] prgsel;
  always @* begin
    casez(prg_ain[14:13])
    2'b00:   prgsel = prg_bank;
    default: prgsel = {2'b11, prg_ain[14:13]};
    endcase
  end
  assign prg_aout = {5'b00_000, prgsel, prg_ain[12:0]};

  // The CHR bank to load. Each increment here is 4kb. So valid values are 0..31.
  reg [4:0] chrsel;
  always @* begin
    casez({chr_ain[12], latch_0, latch_1})
    3'b00?: chrsel = chr_bank_0a;
    3'b01?: chrsel = chr_bank_0b;
    3'b1?0: chrsel = chr_bank_1a;
    3'b1?1: chrsel = chr_bank_1b;
    endcase
  end
  assign chr_aout = {5'b100_00, chrsel, chr_ain[11:0]};
  
  // The a10 VRAM address line. (Used for mirroring)
  assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];
  assign vram_ce = chr_ain[13];
  
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
endmodule

// This mapper also handles mapper 33,47,48,74,76,80,82,88,95,118,119,154,191,192,194,195,206 and 207.
module MMC3(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                            // Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce,                              // True if the address should be routed to the internal 2kB VRAM.
            output irq);
  reg [2:0] bank_select;             // Register to write to next
  reg prg_rom_bank_mode;             // Mode for PRG banking
  reg chr_a12_invert;                // Mode for CHR banking
  reg mirroring;                     // 0 = vertical, 1 = horizontal
  reg irq_enable, irq_reload;        // IRQ enabled, and IRQ reload requested
  reg [7:0] irq_latch, counter;      // IRQ latch value and current counter
  reg [3:0] ram_enable, ram_protect;       // RAM protection bits
  reg [7:0] chr_bank_0, chr_bank_1;  // Selected CHR banks
  reg [7:0] chr_bank_2, chr_bank_3, chr_bank_4, chr_bank_5;
  reg [5:0] prg_bank_0, prg_bank_1, prg_bank_2;  // Selected PRG banks
  wire prg_is_ram;
  reg [4:0] irq_reg;
  assign irq = mapper48 ? irq_reg[4] : irq_reg[0];
    
  // The alternative behavior has slightly different IRQ counter semantics.
  wire mmc3_alt_behavior = 0;
  
  wire TQROM =     (flags[7:0] == 119); 	// TQROM maps 8kB CHR RAM
  wire TxSROM =    (flags[7:0] == 118); 	// Connects CHR A17 to CIRAM A10
  wire mapper47 =  (flags[7:0] == 47);		// Mapper 47 is a multicart that has 128k for each game. It has no RAM.
  wire mapper37 =  (flags[7:0] == 37);    // European Triple Cart (Super Mario, Tetris, Nintendo World Cup)
  wire DxROM =     (flags[7:0] == 206);
  wire mapper112 = (flags[7:0] == 112);   // Ntdec
  wire mapper48 =  (flags[7:0] == 48);    // Taito's TC0690
  wire mapper33 =  (flags[7:0] == 33);    // Taito's TC0190 (TC0690-like. No IRQ. Different Mirroring bit)
  wire mapper95 =  (flags[7:0] == 95);    // NAMCOT-3425
  wire mapper88 =  (flags[7:0] == 88);    // NAMCOT-3433
  wire mapper154 = (flags[7:0] == 154);   // NAMCOT-3453
  wire mapper76 =  (flags[7:0] == 76);    // NAMCOT-3446
  wire mapper80 =  (flags[7:0] == 80);    // Taito's X1-005
  wire mapper82 =  (flags[7:0] == 82);    // Taito's X1-017
  wire mapper207 = (flags[7:0] == 207);   // Taito's X1-017
  wire mapper74 =  (flags[7:0] == 74);    // Has 2KB CHR RAM
  wire mapper191 = (flags[7:0] == 191);   // Has 2KB CHR RAM
  wire mapper192 = (flags[7:0] == 192);   // Has 4KB CHR RAM
  wire mapper194 = (flags[7:0] == 194);   // Has 2KB CHR RAM
  wire mapper195 = (flags[7:0] == 195);   // Has 4KB CHR RAM
  
  wire four_screen_mirroring = flags[16] | DxROM;
  reg mapper47_multicart;
  reg [2:0] mapper37_multicart;
  wire [7:0] new_counter = (counter == 0 || irq_reload) ? irq_latch : counter - 1'd1;
  reg [3:0] a12_ctr; 
  wire irq_support = !DxROM && !mapper33 && !mapper95 && !mapper88 && !mapper154 && !mapper76
                     && !mapper80 && !mapper82 && !mapper207 && !mapper112; //82,207 not needed
  wire prg_invert_support = (irq_support && !mapper48);
  wire chr_invert_support = (irq_support && !mapper48) || mapper82;
  wire regs_7e = mapper80 || mapper82 || mapper207;
  wire internal_128 = mapper80 || mapper207;
   
  always @(posedge clk) if (reset) begin
    irq_reg <= 5'b00000;
    bank_select <= 0;
    prg_rom_bank_mode <= 0;
    chr_a12_invert <= 0;
    mirroring <= flags[14];
    {irq_enable, irq_reload} <= 0;
    {irq_latch, counter} <= 0;
    ram_enable <= {4{mapper112}};
	 ram_protect <= 0;
    {chr_bank_0, chr_bank_1} <= 0;
    {chr_bank_2, chr_bank_3, chr_bank_4, chr_bank_5} <= 0;
    {prg_bank_0, prg_bank_1} <= 0;
	 prg_bank_2 <= 6'b111110;
    a12_ctr <= 0;
	 mapper37_multicart <= 3'b000;
  end else if (ce) begin
    irq_reg[4:1] <= irq_reg[3:0];  // 4 cycle delay
    if (!regs_7e && prg_write && prg_ain[15]) begin
	  if (!mapper33 && !mapper48 && !mapper112) begin
      casez({prg_ain[14:13], prg_ain[1:0]})
      4'b00_?0: {chr_a12_invert, prg_rom_bank_mode, bank_select} <= {prg_din[7], prg_din[6], prg_din[2:0]}; // Bank select ($8000-$9FFE, even)
      4'b00_?1: begin // Bank data ($8001-$9FFF, odd)
        case (bank_select) 
        0: chr_bank_0 <= {1'b0,prg_din[7:1]};  // Select 2 KB CHR bank at PPU $0000-$07FF (or $1000-$17FF);
        1: chr_bank_1 <= {1'b0,prg_din[7:1]};  // Select 2 KB CHR bank at PPU $0800-$0FFF (or $1800-$1FFF);
        2: chr_bank_2 <= prg_din;       // Select 1 KB CHR bank at PPU $1000-$13FF (or $0000-$03FF);
        3: chr_bank_3 <= prg_din;       // Select 1 KB CHR bank at PPU $1400-$17FF (or $0400-$07FF);
        4: chr_bank_4 <= prg_din;       // Select 1 KB CHR bank at PPU $1800-$1BFF (or $0800-$0BFF);
        5: chr_bank_5 <= prg_din;       // Select 1 KB CHR bank at PPU $1C00-$1FFF (or $0C00-$0FFF);
        6: prg_bank_0 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $8000-$9FFF (or $C000-$DFFF);
        7: prg_bank_1 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $A000-$BFFF
        endcase
      end
      4'b01_?0: mirroring <= !prg_din[0];                   // Mirroring ($A000-$BFFE, even)
      4'b01_?1: {ram_enable, ram_protect} <= {{4{prg_din[7]}},{4{prg_din[6]}}}; // PRG RAM protect ($A001-$BFFF, odd)
      4'b10_?0: irq_latch <= prg_din;                      // IRQ latch ($C000-$DFFE, even)
      4'b10_?1: irq_reload <= 1;                           // IRQ reload ($C001-$DFFF, odd)
      4'b11_?0: begin irq_enable <= 0; irq_reg[0] <= 0; end// IRQ disable ($E000-$FFFE, even)
      4'b11_?1: irq_enable <= 1;                           // IRQ enable ($E001-$FFFF, odd)
		endcase
	  end else if (!mapper112) begin
      casez({prg_ain[14:13], prg_ain[1:0], mapper48})
      5'b00_00_0: begin prg_bank_0 <= prg_din[5:0]; mirroring <= prg_din[6]; end // Select 8 KB PRG ROM bank at $8000-$9FFF
      5'b00_00_1: prg_bank_0 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $8000-$9FFF
      5'b00_01_?: prg_bank_1 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $A000-$BFFF
      5'b00_10_?: chr_bank_0 <= prg_din;  // Select 2 KB CHR bank at PPU $0000-$07FF
      5'b00_11_?: chr_bank_1 <= prg_din;  // Select 2 KB CHR bank at PPU $0800-$0FFF
      5'b01_00_?: chr_bank_2 <= prg_din;  // Select 1 KB CHR bank at PPU $1000-$13FF
      5'b01_01_?: chr_bank_3 <= prg_din;  // Select 1 KB CHR bank at PPU $1800-$1BFF
      5'b01_10_?: chr_bank_4 <= prg_din;  // Select 1 KB CHR bank at PPU $1800-$1BFF
      5'b01_11_?: chr_bank_5 <= prg_din;  // Select 1 KB CHR bank at PPU $1C00-$1FFF

      5'b10_00_1: irq_latch <= prg_din ^ 8'hFF;              // IRQ latch ($C000-$DFFC)
      5'b10_01_1: irq_reload <= 1;                           // IRQ reload ($C001-$DFFD)
      5'b10_10_1: begin irq_enable <= 0; irq_reg[0] <= 0; end// IRQ disable ($C002-$DFFE)
      5'b10_11_1: irq_enable <= 1;                           // IRQ enable ($C003-$DFFF)

      5'b11_00_1: mirroring <= !prg_din[6];  // Mirroring
      endcase
	  end else begin
      casez({prg_ain[14:13], prg_ain[0]})
      3'b00_0: {bank_select} <= {prg_din[2:0]}; // Bank select ($8000-$9FFE)
      3'b01_0: begin // Bank data ($A000-$BFFF)
        case (bank_select) 
        0: prg_bank_0 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $8000-$9FFF (or $C000-$DFFF);
        1: prg_bank_1 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $A000-$BFFF
        2: chr_bank_0 <= {1'b0,prg_din[7:1]};  // Select 2 KB CHR bank at PPU $0000-$07FF (or $1000-$17FF);
        3: chr_bank_1 <= {1'b0,prg_din[7:1]};  // Select 2 KB CHR bank at PPU $0800-$0FFF (or $1800-$1FFF);
        4: chr_bank_2 <= prg_din;       // Select 1 KB CHR bank at PPU $1000-$13FF (or $0000-$03FF);
        5: chr_bank_3 <= prg_din;       // Select 1 KB CHR bank at PPU $1400-$17FF (or $0400-$07FF);
        6: chr_bank_4 <= prg_din;       // Select 1 KB CHR bank at PPU $1800-$1BFF (or $0800-$0BFF);
        7: chr_bank_5 <= prg_din;       // Select 1 KB CHR bank at PPU $1C00-$1FFF (or $0C00-$0FFF);
        endcase
      end
      3'b11_0: mirroring <= !prg_din[0];                   // Mirroring ($E000-$FFFE)
		endcase
	  end
      if (mapper154) begin
        mirroring <= !prg_din[6];
		end
    end
    else if (regs_7e && prg_write && prg_ain[15:4]==12'h7EF) begin
      casez({prg_ain[3:0], mapper82})
      5'b0000_?: chr_bank_0 <= {1'b0,prg_din[7:1]};  // Select 2 KB CHR bank at PPU $0000-$07FF
      5'b0001_?: chr_bank_1 <= {1'b0,prg_din[7:1]};  // Select 2 KB CHR bank at PPU $0800-$0FFF
      5'b0010_?: chr_bank_2 <= prg_din;  // Select 1 KB CHR bank at PPU $1000-$13FF
      5'b0011_?: chr_bank_3 <= prg_din;  // Select 1 KB CHR bank at PPU $1800-$1BFF
      5'b0100_?: chr_bank_4 <= prg_din;  // Select 1 KB CHR bank at PPU $1800-$1BFF
      5'b0101_?: chr_bank_5 <= prg_din;  // Select 1 KB CHR bank at PPU $1C00-$1FFF
      5'b011?_0: {mirroring} <= prg_din[0]; // Select Mirroing
      5'b100?_0: {ram_enable[3], ram_protect[3]} <= {(prg_din==8'hA3),!(prg_din==8'hA3)};  // Enable RAM at $7F00-$7FFF
      5'b0110_1: {chr_a12_invert,mirroring} <= prg_din[1:0]; // Select Mirroing
      5'b0111_1: {ram_enable[0], ram_protect[0]} <= {(prg_din==8'hCA),!(prg_din==8'hCA)};  // Enable RAM at $6000-$67FF
      5'b1000_1: {ram_enable[1], ram_protect[1]} <= {(prg_din==8'h69),!(prg_din==8'h69)};  // Enable RAM at $6F00-$6FFF
      5'b1001_1: {ram_enable[2], ram_protect[2]} <= {(prg_din==8'h84),!(prg_din==8'h84)};  // Enable RAM at $7000-$73FF  //Using 6K; Require 5K instead?
      5'b101?_0: prg_bank_0 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $8000-$9FFF
      5'b110?_0: prg_bank_1 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $A000-$BFFF
      5'b111?_0: prg_bank_2 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $C000-$DFFF
      5'b1010_1: prg_bank_0 <= prg_din[7:2];  // Select 8 KB PRG ROM bank at $8000-$9FFF
      5'b1011_1: prg_bank_1 <= prg_din[7:2];  // Select 8 KB PRG ROM bank at $A000-$BFFF
      5'b1100_1: prg_bank_2 <= prg_din[7:2];  // Select 8 KB PRG ROM bank at $C000-$DFFF
      endcase
	 end
    
    // For Mapper 47
    // $6000-7FFF:  [.... ...B]  Block select
    if (prg_write && prg_is_ram)
      mapper47_multicart <= prg_din[0];
        
    // For Mapper 37
    // $6000-7FFF:  [.... .QBB]  Block select
    if (prg_write && prg_is_ram)
      mapper37_multicart <= prg_din[2:0];
        
    // Trigger IRQ counter on rising edge of chr_ain[12]
    // All MMC3A's and non-Sharp MMC3B's will generate only a single IRQ when $C000 is $00.
    // This is because this version of the MMC3 generates IRQs when the scanline counter is decremented to 0.
    // In addition, writing to $C001 with $C000 still at $00 will result in another single IRQ being generated.
    // In the community, this is known as the "alternate" or "old" behavior.
    // All MMC3C's and Sharp MMC3B's will generate an IRQ on each scanline while $C000 is $00.
    // This is because this version of the MMC3 generates IRQs when the scanline counter is equal to 0.
    // In the community, this is known as the "normal" or "new" behavior.
    if (chr_ain[12] && a12_ctr == 0) begin
      counter <= new_counter;
      if ( (!mmc3_alt_behavior  || counter != 0 || irq_reload) && new_counter == 0 && irq_enable && irq_support) begin
//        $write("MMC3 SCANLINE IRQ!\n");
        irq_reg[0] <= 1;
      end
      irq_reload <= 0;      
    end
    a12_ctr <= chr_ain[12] ? 4'b1111 : (a12_ctr != 0) ? a12_ctr - 4'b0001 : a12_ctr;
  end

  // The PRG bank to load. Each increment here is 8kb. So valid values are 0..63.
  reg [5:0] prgsel;
  always @* begin
    casez({prg_ain[14:13], prg_rom_bank_mode && prg_invert_support})
    3'b00_0: prgsel = prg_bank_0;  // $8000 mode 0
    3'b00_1: prgsel = prg_bank_2;  // $8000 fixed to second last bank
    3'b01_?: prgsel = prg_bank_1;  // $A000 mode 0,1
    3'b10_0: prgsel = prg_bank_2;  // $C000 fixed to second last bank
    3'b10_1: prgsel = prg_bank_0;  // $C000 mode 1
    3'b11_?: prgsel = 6'b111111;   // $E000 fixed to last bank
    endcase
    // mapper47 is limited to 128k PRG, the top bits are controlled by mapper47_multicart instead.
    if (mapper47) prgsel[5:4] = {1'b0, mapper47_multicart};
    if (mapper37) begin
      prgsel[5:4] = {1'b0, mapper37_multicart[2]};
		if (mapper37_multicart[1:0] == 3'd3)
        prgsel[3] = 1'b1;
		else if (mapper37_multicart[2] == 1'b0)
        prgsel[3] = 1'b0;
    end
  end

  // The CHR bank to load. Each increment here is 1kb. So valid values are 0..255.
  reg [8:0] chrsel;
  always @* begin
   if (!mapper76) begin
    casez({chr_ain[12] ^ (chr_a12_invert && chr_invert_support), chr_ain[11], chr_ain[10]})
    3'b00?: chrsel = {chr_bank_0, chr_ain[10]};
    3'b01?: chrsel = {chr_bank_1, chr_ain[10]};
    3'b100: chrsel = {1'b0, chr_bank_2};
    3'b101: chrsel = {1'b0, chr_bank_3};
    3'b110: chrsel = {1'b0, chr_bank_4};
    3'b111: chrsel = {1'b0, chr_bank_5};
    endcase
    // mapper47 is limited to 128k CHR, the top bit is controlled by mapper47_multicart instead.
    if (mapper47) chrsel[7] = mapper47_multicart;
    if (mapper37) chrsel[7] = mapper37_multicart[2];
    if ((mapper88) || (mapper154)) chrsel[6] = chr_ain[12];
	end else begin
    case(chr_ain[12:11])
    2'b00: chrsel = {chr_bank_2, chr_ain[10]};
    2'b01: chrsel = {chr_bank_3, chr_ain[10]};
    2'b10: chrsel = {chr_bank_4, chr_ain[10]};
    2'b11: chrsel = {chr_bank_5, chr_ain[10]};
    endcase
	end
  end

  wire [21:0] prg_aout_tmp = {3'b00_0,  prgsel, prg_ain[12:0]};
  wire ram_enable_a = (ram_enable[0] && prg_ain[12:11] == 2'b00)
                      || (ram_enable[1] && prg_ain[12:11] == 2'b01)
                      || (ram_enable[2] && prg_ain[12:11] == 2'b10)
                      || (ram_enable[3] && prg_ain[12:11] == 2'b11);
  wire ram_protect_a = (ram_protect[0] && prg_ain[12:11] == 2'b00)
                      || (ram_protect[1] && prg_ain[12:11] == 2'b01)
                      || (ram_protect[2] && prg_ain[12:11] == 2'b10)
                      || (ram_protect[3] && prg_ain[12:11] == 2'b11);

  assign {chr_allow, chr_aout} = 
      (TQROM && chrsel[6])                    ? {1'b1, 9'b11_1111_111,    chrsel[2:0], chr_ain[9:0]} :   // TQROM 8kb CHR-RAM
      (mapper74 && chrsel[7:1]==7'b0000100)   ? {1'b1, 11'b11_1111_1111_1,chrsel[0],   chr_ain[9:0]} :   // 2kb CHR-RAM
      (mapper191 && chrsel[7])                ? {1'b1, 11'b11_1111_1111_1,chrsel[0],   chr_ain[9:0]} :   // 2kb CHR-RAM
      (mapper192 && chrsel[7:2]==6'b000010)   ? {1'b1, 10'b11_1111_1111,  chrsel[1:0], chr_ain[9:0]} :   // 4kb CHR-RAM
      (mapper194 && chrsel[7:1]==7'b0000000)  ? {1'b1, 11'b11_1111_1111_1,chrsel[0],   chr_ain[9:0]} :   // 2kb CHR-RAM
      (mapper195 && chrsel[7:2]==6'b000000)   ? {1'b1, 10'b11_1111_1111,  chrsel[1:0], chr_ain[9:0]} :   // 4kb CHR-RAM
      (four_screen_mirroring && chr_ain[13])  ? {1'b1, 9'b11_1111_111,   chr_ain[13], chr_ain[11:0]} :   // DxROM 8kb CHR-RAM
                             {flags[15], 3'b10_0, chrsel, chr_ain[9:0]};               // Standard MMC3

  assign prg_is_ram = (prg_ain[15:13] == 3'b011) && ((prg_ain[12:8] == 5'b1_1111) | ~internal_128) //(>= 'h6000 && < 'h8000) && (==7Fxx or external_ram)
                      && ram_enable_a && !(ram_protect_a && prg_write);
  assign prg_allow = prg_ain[15] && !prg_write || prg_is_ram && !mapper47;
  wire [21:0] prg_ram = {9'b11_1100_000, internal_128 ? 6'b000000 : prg_ain[12:7], prg_ain[6:0]};
  assign prg_aout = prg_is_ram  && !mapper47 && !DxROM && !mapper95 && !mapper88 ? prg_ram : prg_aout_tmp;
  assign vram_a10 = TxSROM ? chrsel[7] :            // TxSROM do not support mirroring
                    mapper95 ? chrsel[5] :          // mapper95 does not support mirroring
                    mapper154 ? mirroring :         // mapper154 does not support mirroring
                    mapper207 ? chrsel[7] :         // mapper207 does not support mirroring
                    (mirroring ? chr_ain[10] : chr_ain[11]);
  assign vram_ce = chr_ain[13] && !four_screen_mirroring;
endmodule

// MMC4 mapper chip. PRG ROM: 256kB. Bank Size: 16kB. CHR ROM: 128kB
module MMC4(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input chr_read, input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                      		// Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.

// PRG ROM bank select ($A000-$AFFF)
// 7  bit  0
// ---- ----
// xxxx PPPP
//      ||||
//      ++++- Select 16 KB PRG ROM bank for CPU $8000-$BFFF
  reg [3:0] prg_bank;

// CHR ROM $FD/0000 bank select ($B000-$BFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $0000-$0FFF
//            used when latch 0 = $FD
  reg   [4:0] chr_bank_0a;

// CHR ROM $FE/0000 bank select ($C000-$CFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $0000-$0FFF
//            used when latch 0 = $FE
   reg [4:0] chr_bank_0b;
   
// CHR ROM $FD/1000 bank select ($D000-$DFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $1000-$1FFF
//            used when latch 1 = $FD
  reg [4:0] chr_bank_1a;
   
// CHR ROM $FE/1000 bank select ($E000-$EFFF)
// 7  bit  0
// ---- ----
// xxxC CCCC
//    | ||||
//    +-++++- Select 4 KB CHR ROM bank for PPU $1000-$1FFF
//            used when latch 1 = $FE
  reg [4:0] chr_bank_1b; 
  
// Mirroring ($F000-$FFFF)
// 7  bit  0
// ---- ----
// xxxx xxxM
//         |
//         +- Select nametable mirroring (0: vertical; 1: horizontal)  
  reg mirroring;
  
  reg latch_0, latch_1;
  
  // Update registers
  always @(posedge clk) if (ce) begin
    if (reset)
	   prg_bank <= 4'b1110;	  
    else if (prg_write && prg_ain[15]) begin
      case(prg_ain[14:12])
      2: prg_bank <= prg_din[3:0];     // $A000
      3: chr_bank_0a <= prg_din[4:0];  // $B000
      4: chr_bank_0b <= prg_din[4:0];  // $C000
      5: chr_bank_1a <= prg_din[4:0];  // $D000
      6: chr_bank_1b <= prg_din[4:0];  // $E000
      7: mirroring <=  prg_din[0];     // $F000
      endcase
    end
  end
  
// PPU reads $0FD8 through $0FDF: latch 0 is set to $FD for subsequent reads
// PPU reads $0FE8 through $0FEF: latch 0 is set to $FE for subsequent reads
// PPU reads $1FD8 through $1FDF: latch 1 is set to $FD for subsequent reads
// PPU reads $1FE8 through $1FEF: latch 1 is set to $FE for subsequent reads
  always @(posedge clk) if (ce && chr_read) begin
    latch_0 <= (chr_ain & 14'h3ff8) == 14'h0fd8 ? 1'd0 : (chr_ain & 14'h3ff8) == 14'h0fe8 ? 1'd1 : latch_0;
    latch_1 <= (chr_ain & 14'h3ff8) == 14'h1fd8 ? 1'd0 : (chr_ain & 14'h3ff8) == 14'h1fe8 ? 1'd1 : latch_1;
  end
  
  // The PRG bank to load. Each increment here is 16kb. So valid values are 0..15.
  reg [3:0] prgsel;
  always @* begin
    casez(prg_ain[14])
    1'b0:    prgsel = prg_bank;
    default: prgsel = 4'b1111;
    endcase
  end
  wire [21:0] prg_aout_tmp = {4'b00_00, prgsel, prg_ain[13:0]};

  // The CHR bank to load. Each increment here is 4kb. So valid values are 0..31.
  reg [4:0] chrsel;
  always @* begin
    casez({chr_ain[12], latch_0, latch_1})
    3'b00?: chrsel = chr_bank_0a;
    3'b01?: chrsel = chr_bank_0b;
    3'b1?0: chrsel = chr_bank_1a;
    3'b1?1: chrsel = chr_bank_1b;
    endcase
  end
  assign chr_aout = {5'b100_00, chrsel, chr_ain[11:0]};
  
  // The a10 VRAM address line. (Used for mirroring)
  assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];
  assign vram_ce = chr_ain[13];
  
  assign chr_allow = flags[15];
  
  wire prg_is_ram = prg_ain >= 'h6000 && prg_ain < 'h8000;
  assign prg_allow = prg_ain[15] && !prg_write ||
                     prg_is_ram;
  wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
  assign prg_aout = prg_is_ram ? prg_ram : prg_aout_tmp;

endmodule

module MMC5(input clk, input ce, input ppu_ce, input reset,
            input [31:0] flags,
            input [19:0] ppuflags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din, output reg [7:0] prg_dout,
            output prg_allow,                            // Enable access to memory for the specified operation.
				input chr_read,
				input chr_write,
				input [7:0] chr_din,
            input [13:0] chr_ain, output reg [21:0] chr_aout,
            output reg [7:0] chr_dout, output has_chr_dout,
            output chr_allow,                            // Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce,                              // True if the address should be routed to the internal 2kB VRAM.
            output irq,
				output [15:0] audio);
  reg [1:0] prg_mode, chr_mode;
  reg prg_protect_1, prg_protect_2;
  reg [1:0] extended_ram_mode;
  reg [7:0] mirroring;
  reg [7:0] fill_tile;
  reg [1:0] fill_attr;
  reg [2:0] prg_ram_bank;
  reg [7:0] prg_bank_0, prg_bank_1, prg_bank_2;
  reg [6:0] prg_bank_3;
  reg [9:0] chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_3,
            chr_bank_4, chr_bank_5, chr_bank_6, chr_bank_7,
            chr_bank_8, chr_bank_9, chr_bank_a, chr_bank_b;
  reg [1:0] upper_chr_bank_bits;
  reg chr_last; // Which CHR set was written to last?
  
  reg [4:0] vsplit_startstop;
  reg vsplit_enable, vsplit_side;
  reg [7:0] vsplit_scroll, vsplit_bank;
  
  reg [7:0] irq_scanline;
  reg irq_enable;
  reg irq_pending;
  
  reg [7:0] multiplier_1;
  reg [7:0] multiplier_2; 
  wire [15:0] multiply_result = multiplier_1 * multiplier_2;
  
  reg [7:0] expansion_ram[0:1023]; // Block RAM, otherwise we need to time multiplex..
  reg [7:0] last_read_ram;
  reg [7:0] last_read_exattr;
  reg [7:0] last_read_vram;
  reg last_chr_read;
  
  // unpack ppu flags
  //reg display_enable;
  //wire ppu_in_frame = ppuflags[0] & display_enable;
  wire ppu_in_frame = ppuflags[0];
  wire ppu_sprite16 = ppuflags[1];
  //reg ppu_sprite16;
  wire [8:0] ppu_cycle = ppuflags[10:2]; 
  wire [8:0] ppu_scanline = ppuflags[19:11];
  
  // Handle IO register writes  
  always @(posedge clk) begin
    if (ce) begin
      if (prg_write && prg_ain[15:10] == 6'b010100) begin // $5000-$53FF
        //if (prg_ain <= 16'h5113) $write("%X <= %X (%d)\n", prg_ain, prg_din, ppu_scanline);
        casez(prg_ain[9:0])
        10'h100: prg_mode <= prg_din[1:0];
        10'h101: chr_mode <= prg_din[1:0];
        10'h102: prg_protect_1 <= (prg_din[1:0] == 2'b10);
        10'h103: prg_protect_2 <= (prg_din[1:0] == 2'b01);
        10'h104: extended_ram_mode <= prg_din[1:0];
        10'h105: mirroring <= prg_din;
        10'h106: fill_tile <= prg_din;
        10'h107: fill_attr <= prg_din[1:0];
        10'h113: prg_ram_bank <= prg_din[2:0];
        10'h114: prg_bank_0 <= prg_din;
        10'h115: prg_bank_1 <= prg_din;
        10'h116: prg_bank_2 <= prg_din;
        10'h117: prg_bank_3 <= prg_din[6:0];
        10'h120: chr_bank_0 <= {upper_chr_bank_bits, prg_din};
        10'h121: chr_bank_1 <= {upper_chr_bank_bits, prg_din};
        10'h122: chr_bank_2 <= {upper_chr_bank_bits, prg_din};
        10'h123: chr_bank_3 <= {upper_chr_bank_bits, prg_din};
        10'h124: chr_bank_4 <= {upper_chr_bank_bits, prg_din};
        10'h125: chr_bank_5 <= {upper_chr_bank_bits, prg_din};
        10'h126: chr_bank_6 <= {upper_chr_bank_bits, prg_din};
        10'h127: chr_bank_7 <= {upper_chr_bank_bits, prg_din};
        10'h128: chr_bank_8  <= {upper_chr_bank_bits, prg_din};
        10'h129: chr_bank_9  <= {upper_chr_bank_bits, prg_din};
        10'h12a: chr_bank_a  <= {upper_chr_bank_bits, prg_din};
        10'h12b: chr_bank_b  <= {upper_chr_bank_bits, prg_din};
        10'h130: upper_chr_bank_bits <= prg_din[1:0];
        10'h200: {vsplit_enable, vsplit_side, vsplit_startstop} <= {prg_din[7:6], prg_din[4:0]};
        10'h201: vsplit_scroll <= prg_din;
        10'h202: vsplit_bank <= prg_din;
        10'h203: irq_scanline <= prg_din;
        10'h204: irq_enable <= prg_din[7];
        10'h205: multiplier_1 <= prg_din;
        10'h206: multiplier_2 <= prg_din;
        default: begin end
        endcase
        
        // Remember which set of CHR was written to last.
        if (prg_ain[9:4] == 6'b010010)//(prg_ain[9:0] >= 10'h120 && prg_ain[9:0] < 10'h130)
          chr_last <= prg_ain[3];
      end
		//Not currently passing prg_write when ppu_cs
      //if (prg_write && prg_ain == 16'h2000) begin // $2000
		//  ppu_sprite16 <= (prg_din[5]);
		//end
      //if (prg_write && prg_ain == 16'h2001) begin // $2001
		//  display_enable <= (prg_din[4:3] != 2'b0);
		//end
      
    end
	 
      // Mode 0/1 - Not readable (returns open bus), can only be written while the PPU is rendering (otherwise, 0 is written)
      // Mode 2 - Readable and writable
      // Mode 3 - Read-only
      if (extended_ram_mode != 3) begin
        if (ppu_ce && !ppu_in_frame && !extended_ram_mode[1] && chr_write && (mirrbits == 2) && chr_ain[13])
          expansion_ram[chr_ain[9:0]] <= chr_din;
        else if (ce && prg_write && prg_ain[15:10] == 6'b010111) // $5C00-$5FFF
          expansion_ram[prg_ain[9:0]] <= (extended_ram_mode[1] || ppu_in_frame) ? prg_din : 8'd0;
      end
    if (reset) begin
      prg_bank_3 <= 7'h7F;
      prg_mode <= 3;
    end
  end
  
  // Read from MMC5
  always @* begin
    prg_dout = 8'hFF; // By default open bus.
    if (prg_ain[15:10] == 6'b010111 && extended_ram_mode[1]) begin
      prg_dout = last_read_ram;
    end else if (prg_ain == 16'h5204) begin
      prg_dout = {irq_pending, ppu_in_frame, 6'b111111};
    end else if (prg_ain == 16'h5205) begin
      prg_dout = multiply_result[7:0];
    end else if (prg_ain == 16'h5206) begin
      prg_dout = multiply_result[15:8];
    end
  end
  
  // Determine IRQ handling
  reg last_scanline, irq_trig;
  always @(posedge clk) if (ce || ppu_ce) begin
    if (ce && prg_read && prg_ain == 16'h5204)
      irq_pending <= 0;
    irq_trig <= (irq_scanline != 0 && irq_scanline < 240 && ppu_scanline == {1'b0, irq_scanline});
    last_scanline <= ppu_scanline[0];
    if (ppu_scanline[0] != last_scanline && irq_trig)
      irq_pending <= 1;
  end
  assign irq = irq_pending && irq_enable;

  // Determine if vertical split is active.
  reg [5:0] cur_tile;     // Current tile the PPU is fetching
  reg [5:0] new_cur_tile; // New value for |cur_tile|
  reg [7:0] vscroll;      // Current y scroll for the split region
  reg last_in_split_area, in_split_area;

  // Compute if we're in the split area right now by counting PPU tiles.
  always @* begin
    new_cur_tile = (ppu_cycle[8:3] == 40) ? 6'd0 : (cur_tile + 6'b1);
    in_split_area = last_in_split_area;
    if (ppu_cycle[2:0] == 0 && ppu_cycle < 336) begin
      if (new_cur_tile == 0)
        in_split_area = !vsplit_side;
      else if (new_cur_tile == {1'b0, vsplit_startstop})
        in_split_area = vsplit_side;
      else if (new_cur_tile == 34)
        in_split_area = 0;
    end
  end
  always @(posedge clk) if (ppu_ce) begin
    last_in_split_area <= in_split_area;
    if (ppu_cycle[2:0] == 0 && ppu_cycle < 336)
      cur_tile <= new_cur_tile;
  end
  // Keep track of scroll
  always @(posedge clk) if (ppu_ce) begin
    if (ppu_cycle == 319)
      vscroll <= ppu_scanline[8] ? vsplit_scroll : 
                 (vscroll == 239) ? 8'b0 : vscroll + 8'b1;
  end

  // Mirroring bits
  // %00 = NES internal NTA
  // %01 = NES internal NTB
  // %10 = use ExRAM as NT
  // %11 = Fill Mode
  wire [1:0] mirrbits = (chr_ain[11:10] == 0) ? mirroring[1:0] : 
                        (chr_ain[11:10] == 1) ? mirroring[3:2] : 
                        (chr_ain[11:10] == 2) ? mirroring[5:4] : 
                                                mirroring[7:6];

  // Compute the new overriden nametable/attr address the split will read from instead
  // when the VSplit is active.
  // Cycle 0, 1 = nametable
  // Cycle 2, 3 = attribute
  // Named it loopy so I can copypaste from PPU code :)
  wire [9:0] loopy = {vscroll[7:3], cur_tile[4:0]};              
  wire [9:0] split_addr = (ppu_cycle[1] == 0) ? loopy :                            // name table
                                                {4'b1111, loopy[9:7], loopy[4:2]}; // attribute table
  // Selects 2 out of the attr bits read from exram.
  wire [1:0] split_attr = (!loopy[1] && !loopy[6]) ? last_read_ram[1:0] : 
                          ( loopy[1] && !loopy[6]) ? last_read_ram[3:2] :
                          (!loopy[1] &&  loopy[6]) ? last_read_ram[5:4] : 
                                                     last_read_ram[7:6];
  // If splitting is active or not
  wire insplit = in_split_area && vsplit_enable;

  // Currently reading the attribute byte?
  wire exattr_read = (extended_ram_mode == 1) && (ppu_cycle[2:1]==1) && ppu_in_frame;
  
  // If the current chr read should be redirected from |chr_dout| instead.
  assign has_chr_dout = chr_ain[13] && (mirrbits[1] || insplit || exattr_read);
  wire [1:0] override_attr = insplit ? split_attr : (extended_ram_mode == 1) ? last_read_exattr[7:6] : fill_attr;
  always @* begin
    if (ppu_in_frame) begin
      if (ppu_cycle[1] == 0) begin
        // Name table fetch
        if (insplit || mirrbits[0] == 0) chr_dout = (extended_ram_mode[1] ? 8'b0 : last_read_ram);
        else begin
          //$write("Inserting filltile!\n");
          chr_dout = fill_tile;
        end
      end else begin
        // Attribute table fetch
        if (!insplit && !exattr_read && mirrbits[0] == 0) chr_dout = (extended_ram_mode[1] ? 8'b0 : last_read_ram);
        else chr_dout = {override_attr, override_attr, override_attr, override_attr};
      end
	 end else begin
      chr_dout = last_read_vram;
	 end
  end

  // Handle reading from the expansion ram.
  // 0 - Use as extra nametable (possibly for split mode)
  // 1 - Use as extended attribute data OR an extra nametable
  // 2 - Use as ordinary RAM
  // 3 - Use as ordinary RAM, write protected
  wire [9:0] exram_read_addr = extended_ram_mode[1] ? prg_ain[9:0] : 
                               insplit              ? split_addr :
                                                      chr_ain[9:0];
  always @(posedge clk) begin
    last_read_ram <= expansion_ram[exram_read_addr];
    if ((ppu_cycle[2] == 0) && (ppu_cycle[1] == 0) && ppu_in_frame) begin
      last_read_exattr <= last_read_ram;
    end
    last_chr_read <= chr_read;
    if (!chr_read && last_chr_read)
      last_read_vram <= extended_ram_mode[1] ? 8'b0 : last_read_ram;
  end

  // Compute PRG address to read from.
  reg [7:0] prgsel;
  always @* begin
    casez({prg_mode, prg_ain[15:13]})
    5'b??_0??: prgsel = {5'b0xxxx, prg_ram_bank};                // $6000-$7FFF all modes
    5'b00_1??: prgsel = {1'b1, prg_bank_3[6:2], prg_ain[14:13]}; // $8000-$FFFF mode 0, 32kB (prg_bank_3, skip 2 bits)

    5'b01_10?: prgsel = {      prg_bank_1[7:1], prg_ain[13]};    // $8000-$BFFF mode 1, 16kB (prg_bank_1, skip 1 bit)
    5'b01_11?: prgsel = {1'b1, prg_bank_3[6:1], prg_ain[13]};    // $C000-$FFFF mode 1, 16kB (prg_bank_3, skip 1 bit)

    5'b10_10?: prgsel = {      prg_bank_1[7:1], prg_ain[13]};    // $8000-$BFFF mode 2, 16kB (prg_bank_1, skip 1 bit)
    5'b10_110: prgsel = {      prg_bank_2};                      // $C000-$DFFF mode 2, 8kB  (prg_bank_2)
    5'b10_111: prgsel = {1'b1, prg_bank_3};                      // $E000-$FFFF mode 2, 8kB  (prg_bank_3)

    5'b11_100: prgsel = {      prg_bank_0};                      // $8000-$9FFF mode 3, 8kB (prg_bank_0)
    5'b11_101: prgsel = {      prg_bank_1};                      // $A000-$BFFF mode 3, 8kB (prg_bank_1)
    5'b11_110: prgsel = {      prg_bank_2};                      // $C000-$DFFF mode 3, 8kB (prg_bank_2)
    5'b11_111: prgsel = {1'b1, prg_bank_3};                      // $E000-$FFFF mode 3, 8kB (prg_bank_3)
    endcase
	 //Original
    //prgsel[7] = !prgsel[7]; // 0 means RAM, doh.
    
	 //Done below
    //if (prgsel[7])
    //  prgsel[7] = 0;  //ROM
    //else
    //  // Limit to 64k RAM.
    //  prgsel[7:3] = 5'b1_1100;  //RAM location for saves
  end
  assign prg_aout = {prgsel[7] ? {2'b00, prgsel[6:0]} : {6'b11_1100, prgsel[2:0]}, prg_ain[12:0]};    // 8kB banks

  // Registers $5120-$5127 apply to sprite graphics and $5128-$512B for background graphics, but ONLY when 8x16 sprites are enabled.
  // Otherwise, the last set of registers written to (either $5120-$5127 or $5128-$512B) will be used for all graphics.
  // 0 if using $5120-$5127, 1 if using $5128-$512F
  wire is_bg_fetch = !(ppu_cycle[8] && !ppu_cycle[6]);
  wire chrset = (ppu_sprite16 && ppu_in_frame) ? is_bg_fetch : chr_last; 
  reg [9:0] chrsel;
  always @* begin
    casez({chr_mode, chr_ain[12:10], chrset})
    6'b00_???_0: chrsel = {chr_bank_7[6:0], chr_ain[12:10]}; // $0000-$1FFF mode 0, 8 kB
    6'b00_???_1: chrsel = {chr_bank_b[6:0], chr_ain[12:10]}; // $0000-$1FFF mode 0, 8 kB
    
    6'b01_0??_0: chrsel = {chr_bank_3[7:0], chr_ain[11:10]}; // $0000-$0FFF mode 1, 4 kB
    6'b01_1??_0: chrsel = {chr_bank_7[7:0], chr_ain[11:10]}; // $1000-$1FFF mode 1, 4 kB
    6'b01_???_1: chrsel = {chr_bank_b[7:0], chr_ain[11:10]}; // $0000-$0FFF mode 1, 4 kB

    6'b10_00?_0: chrsel = {chr_bank_1[8:0], chr_ain[10]};    // $0000-$07FF mode 2, 2 kB
    6'b10_01?_0: chrsel = {chr_bank_3[8:0], chr_ain[10]};    // $0800-$0FFF mode 2, 2 kB
    6'b10_10?_0: chrsel = {chr_bank_5[8:0], chr_ain[10]};    // $1000-$17FF mode 2, 2 kB
    6'b10_11?_0: chrsel = {chr_bank_7[8:0], chr_ain[10]};    // $1800-$1FFF mode 2, 2 kB
    6'b10_?0?_1: chrsel = {chr_bank_9[8:0], chr_ain[10]};    // $0000-$07FF mode 2, 2 kB
    6'b10_?1?_1: chrsel = {chr_bank_b[8:0], chr_ain[10]};    // $0800-$0FFF mode 2, 2 kB

    6'b11_000_0: chrsel = chr_bank_0;                        // $0000-$03FF mode 3, 1 kB
    6'b11_001_0: chrsel = chr_bank_1;                        // $0400-$07FF mode 3, 1 kB
    6'b11_010_0: chrsel = chr_bank_2;                        // $0800-$0BFF mode 3, 1 kB
    6'b11_011_0: chrsel = chr_bank_3;                        // $0C00-$0FFF mode 3, 1 kB
    6'b11_100_0: chrsel = chr_bank_4;                        // $1000-$13FF mode 3, 1 kB
    6'b11_101_0: chrsel = chr_bank_5;                        // $1400-$17FF mode 3, 1 kB
    6'b11_110_0: chrsel = chr_bank_6;                        // $1800-$1BFF mode 3, 1 kB
    6'b11_111_0: chrsel = chr_bank_7;                        // $1C00-$1FFF mode 3, 1 kB
    6'b11_?00_1: chrsel = chr_bank_8;                        // $0000-$03FF mode 3, 1 kB
    6'b11_?01_1: chrsel = chr_bank_9;                        // $0400-$07FF mode 3, 1 kB
    6'b11_?10_1: chrsel = chr_bank_a;                        // $0800-$0BFF mode 3, 1 kB
    6'b11_?11_1: chrsel = chr_bank_b;                        // $0C00-$0FFF mode 3, 1 kB
    endcase
  
    chr_aout = {2'b10, chrsel, chr_ain[9:0]};    // 1kB banks
    
    // Override |chr_aout| if we're in a vertical split.
    if (ppu_in_frame && insplit) begin
      //$write("In vertical split!\n");
      chr_aout = {2'b10, vsplit_bank, chr_ain[11:3], vscroll[2:0]};
    end else if (ppu_in_frame && extended_ram_mode == 1 && is_bg_fetch && (ppu_cycle[2:1]!=0)) begin 
      //$write("In exram thingy!\n");
      // Extended attribute mode. Replace the page with the page from exram.
      chr_aout = {2'b10, upper_chr_bank_bits, last_read_exattr[5:0], chr_ain[11:0]};
    end
      
  end
  
  // The a10 VRAM address line. (Used for mirroring)
  assign vram_a10 = mirrbits[0];
  assign vram_ce = chr_ain[13] && !mirrbits[1];
  
  // Writing to RAM is enabled only when the protect bits say so.  
  wire prg_ram_we = prg_protect_1 && prg_protect_2;
  assign prg_allow = (prg_ain >= 16'h6000) && (!prg_write || ((!prgsel[7]) && prg_ram_we));
  
  // MMC5 boards typically have no CHR RAM.
  assign chr_allow = flags[15];

  wire [7:0] apu_dout;
  wire apu_cs = (prg_ain[15:5]==11'b0101_0000_000) && (prg_ain[3]==0);
  wire DmaReq;      // 1 when DMC wants DMA
  wire [15:0] DmaAddr;  // Address DMC wants to read
  wire odd_or_even;
  wire apu_irq;       // IRQ asserted
  APU mmc5apu(1, clk, ppu_ce, reset,
          prg_ain[4:0], prg_din, apu_dout, 
          prg_write && apu_cs, prg_read && apu_cs,
          5'b10011,
          audio,
          DmaReq,
          1,
          DmaAddr,
          0,
          odd_or_even,
          apu_irq);
  
endmodule

// iNES mapper 64 and 158 - Tengen's version of MMC3
module Rambo1(input clk, input ce, input reset,
              input [31:0] flags,
              input [15:0] prg_ain, output [21:0] prg_aout,
              input prg_read, prg_write,                   // Read / write signals
              input [7:0] prg_din,
              output prg_allow,                            // Enable access to memory for the specified operation.
              input [13:0] chr_ain, output [21:0] chr_aout,
              output chr_allow,                            // Allow write
              output vram_a10,                             // Value for A10 address line
              output vram_ce,                              // True if the address should be routed to the internal 2kB VRAM.
              output reg irq);
  reg [3:0] bank_select;             // Register to write to next
  reg prg_rom_bank_mode;             // Mode for PRG banking
  reg chr_K;                         // Mode for CHR banking
  reg chr_a12_invert;                // Mode for CHR banking
  reg mirroring;                     // 0 = vertical, 1 = horizontal
  reg irq_enable, irq_reload;        // IRQ enabled, and IRQ reload requested
  reg [7:0] irq_latch, counter;      // IRQ latch value and current counter
  reg want_irq;
  reg [7:0] chr_bank_0, chr_bank_1;  // Selected CHR banks
  reg [7:0] chr_bank_2, chr_bank_3, chr_bank_4, chr_bank_5;
  reg [7:0] chr_bank_8, chr_bank_9;
  reg [5:0] prg_bank_0, prg_bank_1, prg_bank_2;  // Selected PRG banks
  reg irq_cycle_mode;
  reg [1:0] cycle_counter;
 
  // Mapper has vram_a10 wired to CHR A17
  wire mapper64 = (flags[7:0] == 64);

  // This code detects rising edges on a12.
  reg old_a12_edge;
  reg [1:0] a12_ctr;
  wire a12_edge = (chr_ain[12] && a12_ctr == 0) || old_a12_edge;
  always @(posedge clk) begin
    old_a12_edge <= a12_edge && !ce;
    a12_ctr <= chr_ain[12] ? 2'b11 : (a12_ctr != 0 && ce) ? a12_ctr - 2'b01 : a12_ctr;
  end
  
  always @(posedge clk) if (reset) begin
    bank_select <= 0;
    prg_rom_bank_mode <= 0;
    chr_K <= 0;
    chr_a12_invert <= 0;
    mirroring <= 0;
    {irq_enable, irq_reload} <= 0;
    {irq_latch, counter} <= 0;
    want_irq <= 0;
    {chr_bank_0, chr_bank_1} <= 0;
    {chr_bank_2, chr_bank_3, chr_bank_4, chr_bank_5} <= 0;
    {chr_bank_8, chr_bank_9} <= 0;
    {prg_bank_0, prg_bank_1, prg_bank_2} <= 6'b111111;
    irq_cycle_mode <= 0;
    cycle_counter <= 0;
    irq <= 0;
  end else if (ce) begin
    cycle_counter <= cycle_counter + 1'd1;
        
    if (prg_write && prg_ain[15]) begin
      case({prg_ain[14:13], prg_ain[0]})
      // Bank select ($8000-$9FFE, even)
      3'b00_0: {chr_a12_invert, prg_rom_bank_mode, chr_K, bank_select} <= {prg_din[7:5], prg_din[3:0]}; 
      // Bank data ($8001-$9FFF, odd)
      3'b00_1:
        case (bank_select) 
        0: chr_bank_0 <= prg_din;       // Select 2 (K=0) or 1 (K=1) KB CHR bank at PPU $0000 (or $1000);
        1: chr_bank_1 <= prg_din;       // Select 2 (K=0) or 1 (K=1) KB CHR bank at PPU $0800 (or $1800);
        2: chr_bank_2 <= prg_din;       // Select 1 KB CHR bank at PPU $1000-$13FF (or $0000-$03FF);
        3: chr_bank_3 <= prg_din;       // Select 1 KB CHR bank at PPU $1400-$17FF (or $0400-$07FF);
        4: chr_bank_4 <= prg_din;       // Select 1 KB CHR bank at PPU $1800-$1BFF (or $0800-$0BFF);
        5: chr_bank_5 <= prg_din;       // Select 1 KB CHR bank at PPU $1C00-$1FFF (or $0C00-$0FFF);
        6: prg_bank_0 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $8000-$9FFF (or $C000-$DFFF);
        7: prg_bank_1 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $A000-$BFFF
        8: chr_bank_8 <= prg_din;       // If K=1, Select 1 KB CHR bank at PPU $0400 (or $1400);
        9: chr_bank_9 <= prg_din;       // If K=1, Select 1 KB CHR bank at PPU $0C00 (or $1C00)
        15: prg_bank_2 <= prg_din[5:0]; // Select 8 KB PRG ROM bank at $C000-$DFFF (or $8000-$9FFF);
        endcase
      3'b01_0: mirroring <= prg_din[0];                   // Mirroring ($A000-$BFFE, even)
      3'b01_1: begin end
      3'b10_0: irq_latch <= prg_din;                      // IRQ latch ($C000-$DFFE, even)
      3'b10_1: begin 
                 {irq_reload, irq_cycle_mode} <= {1'b1, prg_din[0]}; // IRQ reload ($C001-$DFFF, odd)
                 cycle_counter <= 0;
               end
      3'b11_0: {irq_enable, irq} <= 2'b0;                 // IRQ disable ($E000-$FFFE, even)
      3'b11_1: irq_enable <= 1;                           // IRQ enable ($E001-$FFFF, odd)
      endcase
    end

    if (irq_cycle_mode ? (cycle_counter == 3) : a12_edge) begin
      if (irq_reload || counter == 0) begin
        counter <= irq_latch;
        want_irq <= irq_reload;
      end else begin
        counter <= counter - 1'd1;
        want_irq <= 1;
      end
      if (counter == 0 && want_irq && !irq_reload && irq_enable)
        irq <= 1;
      irq_reload <= 0;
    end
    
  end
  // The PRG bank to load. Each increment here is 8kb. So valid values are 0..63.
  reg [5:0] prgsel;
  always @* begin
    casez({prg_ain[14:13], prg_rom_bank_mode})
    3'b00_0: prgsel = prg_bank_0;  // $8000 is R:6
    3'b01_0: prgsel = prg_bank_1;  // $A000 is R:7
    3'b10_0: prgsel = prg_bank_2;  // $C000 is R:F
    3'b11_0: prgsel = 6'b111111;   // $E000 fixed to last bank
    3'b00_1: prgsel = prg_bank_2;  // $8000 is R:F
    3'b01_1: prgsel = prg_bank_0;  // $A000 is R:6
    3'b10_1: prgsel = prg_bank_1;  // $C000 is R:7
    3'b11_1: prgsel = 6'b111111;   // $E000 fixed to last bank
    endcase
  end
  // The CHR bank to load. Each increment here is 1kb. So valid values are 0..255.
  reg [7:0] chrsel;
  always @* begin
    casez({chr_ain[12] ^ chr_a12_invert, chr_ain[11], chr_ain[10], chr_K})
    4'b00?_0: chrsel = {chr_bank_0[7:1], chr_ain[10]};
    4'b01?_0: chrsel = {chr_bank_1[7:1], chr_ain[10]};
    4'b000_1: chrsel = chr_bank_0;
    4'b001_1: chrsel = chr_bank_8;
    4'b010_1: chrsel = chr_bank_1;
    4'b011_1: chrsel = chr_bank_9;
    4'b100_?: chrsel = chr_bank_2;
    4'b101_?: chrsel = chr_bank_3;
    4'b110_?: chrsel = chr_bank_4;
    4'b111_?: chrsel = chr_bank_5;
    endcase
  end
  assign prg_aout = {3'b00_0,  prgsel, prg_ain[12:0]};
  assign {chr_allow, chr_aout} = {flags[15], 4'b10_00, chrsel, chr_ain[9:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign vram_a10 = mapper64 ? chrsel[7] :  // Mapper 64 controls mirroring by switching the top bits of the CHR address
                    mirroring ? chr_ain[11] : chr_ain[10];
  assign vram_ce = chr_ain[13];
endmodule


// #13 - CPROM - Used by Videomation
module Mapper13(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output vram_a10,                             // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
  reg [1:0] chr_bank;
  always @(posedge clk) if (reset) begin
    chr_bank <= 0;
  end else if (ce) begin
    if (prg_ain[15] && prg_write)
      chr_bank <= prg_din[1:0];
  end
  assign prg_aout = {7'b00_0000_0, prg_ain[14:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
  assign chr_aout = {8'b01_0000_00, chr_ain[12] ? chr_bank : 2'b00, chr_ain[11:0]};
  assign vram_ce = chr_ain[13];
  assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];
endmodule

// #15 -  100-in-1 Contra Function 16
module Mapper15(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output vram_a10,                             // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
// 15 bit  8 7  bit  0  Address bus
// ---- ---- ---- ----
// 1xxx xxxx xxxx xxSS
// |                ||
// |                ++- Select PRG ROM bank mode
// |                    0: 32K; 1: 128K (UNROM style); 2: 8K; 3: 16K
// +------------------- Always 1
// 7  bit  0  Data bus
// ---- ----
// bMBB BBBB
// |||| ||||
// ||++-++++- Select 16 KB PRG ROM bank
// |+-------- Select nametable mirroring mode (0=vertical; 1=horizontal)
// +--------- Select 8 KB half of 16 KB PRG ROM bank
//            (should be 0 except in bank mode 0)
  reg [1:0] prg_rom_bank_mode;
  reg prg_rom_bank_lowbit;
  reg mirroring;
  reg [5:0] prg_rom_bank;
  always @(posedge clk) if (reset) begin
    prg_rom_bank_mode <= 0;
    prg_rom_bank_lowbit <= 0;
    mirroring <= 0;
    prg_rom_bank <= 0;
  end else if (ce) begin
    if (prg_ain[15] && prg_write)
      {prg_rom_bank_mode, prg_rom_bank_lowbit, mirroring, prg_rom_bank} <= {prg_ain[1:0], prg_din[7:0]};
  end
  reg [6:0] prg_bank;
  always begin
    casez({prg_rom_bank_mode, prg_ain[14]})
    // Bank mode 0 ( 32K ) / CPU $8000-$BFFF: Bank B / CPU $C000-$FFFF: Bank (B OR 1)
    3'b00_0: prg_bank = {prg_rom_bank, prg_ain[13]};
    3'b00_1: prg_bank = {prg_rom_bank | 6'b1, prg_ain[13]};
    // Bank mode 1 ( 128K ) / CPU $8000-$BFFF: Switchable 16 KB bank B / CPU $C000-$FFFF: Fixed to last bank in the cart
    3'b01_0: prg_bank = {prg_rom_bank, prg_ain[13]};
    3'b01_1: prg_bank = {6'b111111, prg_ain[13]};
    // Bank mode 2 ( 8K ) / CPU $8000-$9FFF: Sub-bank b of 16 KB PRG ROM bank B / CPU $A000-$FFFF: Mirrors of $8000-$9FFF
    3'b10_?: prg_bank = {prg_rom_bank, prg_rom_bank_lowbit};
    // Bank mode 3 ( 16K ) / CPU $8000-$BFFF: 16 KB bank B / CPU $C000-$FFFF: Mirror of $8000-$BFFF
    3'b11_?: prg_bank = {prg_rom_bank, prg_ain[13]};
    endcase
  end
  assign prg_aout = {2'b00, prg_bank, prg_ain[12:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15]; // CHR RAM?
  assign chr_aout = {9'b10_0000_000, chr_ain[12:0]};
  assign vram_ce = chr_ain[13];
  assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];
endmodule

// Mapper 16, 159 Bandai
module Mapper16(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din, output [7:0] prg_dout,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                      		// Allow write
            output reg vram_a10,                         // Value for A10 address line
            output vram_ce,                     			// True if the address should be routed to the internal 2kB VRAM.
				output [14:0] mapper_addr,
				input [7:0] mapper_data_in,
				output [7:0] mapper_data_out,
				output mapper_prg_write, output mapper_ovr,
				output reg irq); 

	reg [3:0] prg_bank;
	reg [7:0] chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_3,
				 chr_bank_4, chr_bank_5, chr_bank_6, chr_bank_7;
	reg [3:0] prg_sel;
	reg [1:0] mirroring;
	reg irq_enable;
	reg irq_up;
	reg [15:0] irq_counter;
	reg [15:0] irq_latch;
	reg eeprom_scl, eeprom_sda;
	wire submapper5 = (flags[24:21] == 5);
	wire mapper159 = (flags[7:0] == 159);
	wire mapperalt = submapper5 | mapper159;
	
	always @(posedge clk) if (reset) begin
		prg_bank <= 4'hF;
		chr_bank_0 <= 0;
		chr_bank_1 <= 0;
		chr_bank_2 <= 0;
		chr_bank_3 <= 0;
		chr_bank_4 <= 0;
		chr_bank_5 <= 0;
		chr_bank_6 <= 0;
		chr_bank_7 <= 0;
		mirroring <= 0;
		irq_counter <= 0;
		irq_latch <= 0;
		irq_up <= 0;
		eeprom_scl <= 0;
		eeprom_sda <= 0;
	end else if (ce) begin
		irq_up <= 1'b0;
		if (prg_write)
			if(((prg_ain[14:13] == 2'b11) && (!mapperalt)) || (prg_ain[15]))				// Cover all from $6000 to $FFFF to maximize compatibility
				case(prg_ain & 'hf)				// Registers are mapped every 16 bytes
				'h0: chr_bank_0 <= prg_din[7:0];
				'h1: chr_bank_1 <= prg_din[7:0];
				'h2: chr_bank_2 <= prg_din[7:0];
				'h3: chr_bank_3 <= prg_din[7:0];
				'h4: chr_bank_4 <= prg_din[7:0];
				'h5: chr_bank_5 <= prg_din[7:0];
				'h6: chr_bank_6 <= prg_din[7:0];
				'h7: chr_bank_7 <= prg_din[7:0];
				'h8: prg_bank <= prg_din[3:0];
				'h9: mirroring <= prg_din[1:0];
				'ha: {irq_up, irq_enable} <= {1'b1, prg_din[0]};
				'hb: if (mapperalt) irq_latch[7:0] <= prg_din[7:0]; else irq_counter[7:0] <= prg_din[7:0];
				'hc: if (mapperalt) irq_latch[15:8] <= prg_din[7:0]; else irq_counter[15:8] <= prg_din[7:0];
				'hd: {eeprom_sda, eeprom_scl} <= prg_din[6:5];//RAM enable or EEPROM control
				endcase

		if (irq_enable)
			irq_counter <= irq_counter - 16'd1;
		
		if (irq_up) begin
			irq <= 1'b0;	// IRQ ACK
			if (mapperalt)
				irq_counter <= irq_latch;
		end
		
		if ((irq_counter == 16'h0000) && (irq_enable))
			irq <= 1'b1;	// IRQ
			
	end
	
	always begin
      // mirroring
      casez(mirroring[1:0])
      2'b00:   vram_a10 = {chr_ain[10]};    // vertical
      2'b01:   vram_a10 = {chr_ain[11]};    // horizontal
      2'b1?:   vram_a10 = {mirroring[0]};   // single screen lower
      endcase
	end 
	
   reg [3:0] prgsel;  
	always begin
		case(prg_ain[15:14])
		2'b10: 	prgsel = prg_bank;			// $8000 is swapable
		2'b11: 	prgsel = 4'hF;					// $C000 is hardwired to last bank
		default: prgsel = 0;
		endcase
	end

   reg [7:0] chrsel;  
   always begin
    casez(chr_ain[12:10])
    0: chrsel = chr_bank_0;
    1: chrsel = chr_bank_1;
    2: chrsel = chr_bank_2;
    3: chrsel = chr_bank_3;
    4: chrsel = chr_bank_4;
    5: chrsel = chr_bank_5;
    6: chrsel = chr_bank_6;
    7: chrsel = chr_bank_7;
    endcase
   end	
	assign chr_aout = {4'b10_00, chrsel, chr_ain[9:0]};					// 1kB banks
	wire [21:0] prg_aout_tmp = {4'b00_00, prgsel, prg_ain[13:0]};  	// 16kB banks	
	
	wire prg_is_ram = (prg_ain >= 'h6000) && (prg_ain < 'h8000);
   wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
   assign prg_aout = prg_is_ram ? prg_ram : prg_aout_tmp;
	// EEPROM - not used - Could use write to EEPROM cycle for both reads and write accesses, but this is easier
	assign prg_dout = prg_is_ram ? prg_write ? mapper_data_out : {3'b111, sda_out, 4'b1111} : 8'hFF;
  
   assign prg_allow = (prg_ain[15] && !prg_write);
	assign chr_allow = flags[15];
	assign vram_ce = chr_ain[13];

	wire sda_out;
   wire [7:0] ram_addr;
   wire ram_read;
	assign mapper_addr[14:8] = 0;
	assign mapper_addr[7:0] = ram_addr;
	assign mapper_ovr = 1'b1;
	EEPROM_24C0x eeprom(
		.type_24C01(mapper159),         //24C01 is 128 bytes, 24C02 is 256 bytes
		.clk(clk),
		.ce(ce),
		.reset(reset),
		.SCL(eeprom_scl),               // Serial Clock
		.SDA_in(eeprom_sda),            // Serial Data (same pin as below, split for convenience)
		.SDA_out(sda_out),              // Serial Data (same pin as above, split for convenience)
		.E_id(3'b000),                  // Chip Enable
		.WC_n(1'b0),                    // ~Write Control
		.data_from_ram(mapper_data_in), // Data read from RAM
		.data_to_ram(mapper_data_out),  // Data written to RAM
		.ram_addr(ram_addr),            // RAM Address
		.ram_read(ram_read),            // RAM read
		.ram_write(mapper_prg_write),   // RAM write
		.ram_done(1'b1));               // RAM access done
	
endmodule

// Mapper 18, Jaleco SS88006
module Mapper18(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din, output [7:0] prg_dout,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                      		// Allow write
            output reg vram_a10,                         // Value for A10 address line
            output vram_ce,                     			// True if the address should be routed to the internal 2kB VRAM.
				output reg irq); 

	reg [7:0] prg_bank_0, prg_bank_1, prg_bank_2;
	reg [7:0] chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_3,
				 chr_bank_4, chr_bank_5, chr_bank_6, chr_bank_7;
	reg [3:0] prg_sel;
	reg [1:0] mirroring;
	reg irq_ack;
	reg [3:0] irq_enable;
	reg [15:0] irq_reload;
	reg [15:0] irq_counter;
	reg [1:0] ram_enable;
	
	always @(posedge clk) if (reset) begin
		prg_bank_0 <= 8'hFF;
		prg_bank_1 <= 8'hFF;
		prg_bank_2 <= 8'hFF;
		chr_bank_0 <= 0;
		chr_bank_1 <= 0;
		chr_bank_2 <= 0;
		chr_bank_3 <= 0;
		chr_bank_4 <= 0;
		chr_bank_5 <= 0;
		chr_bank_6 <= 0;
		chr_bank_7 <= 0;
		mirroring <= 0;
		irq_reload <= 0;
		irq_counter <= 0;
		irq_enable <= 4'h0;
	end else if (ce) begin
	   irq_ack <= 1'b0;
		if (prg_write)
			if(prg_ain[15])						// Cover all from $8000 to $FFFF to maximize compatibility
				case({prg_ain[14:12],prg_ain[1:0]})				// 
				5'b000_00: prg_bank_0[3:0] <= prg_din[3:0];
				5'b000_01: prg_bank_0[7:4] <= prg_din[3:0];
				5'b000_10: prg_bank_1[3:0] <= prg_din[3:0];
				5'b000_11: prg_bank_1[7:4] <= prg_din[3:0];
				5'b001_00: prg_bank_2[3:0] <= prg_din[3:0];
				5'b001_01: prg_bank_2[7:4] <= prg_din[3:0];
				5'b010_00: chr_bank_0[3:0] <= prg_din[3:0];
				5'b010_01: chr_bank_0[7:4] <= prg_din[3:0];
				5'b010_10: chr_bank_1[3:0] <= prg_din[3:0];
				5'b010_11: chr_bank_1[7:4] <= prg_din[3:0];
				5'b011_00: chr_bank_2[3:0] <= prg_din[3:0];
				5'b011_01: chr_bank_2[7:4] <= prg_din[3:0];
				5'b011_10: chr_bank_3[3:0] <= prg_din[3:0];
				5'b011_11: chr_bank_3[7:4] <= prg_din[3:0];
				5'b100_00: chr_bank_4[3:0] <= prg_din[3:0];
				5'b100_01: chr_bank_4[7:4] <= prg_din[3:0];
				5'b100_10: chr_bank_5[3:0] <= prg_din[3:0];
				5'b100_11: chr_bank_5[7:4] <= prg_din[3:0];
				5'b101_00: chr_bank_6[3:0] <= prg_din[3:0];
				5'b101_01: chr_bank_6[7:4] <= prg_din[3:0];
				5'b101_10: chr_bank_7[3:0] <= prg_din[3:0];
				5'b101_11: chr_bank_7[7:4] <= prg_din[3:0];
				5'b110_00: irq_reload[3:0] <= prg_din[3:0];
				5'b110_01: irq_reload[7:4] <= prg_din[3:0];
				5'b110_10: irq_reload[11:8] <= prg_din[3:0];
				5'b110_11: irq_reload[15:12] <= prg_din[3:0];
				5'b111_00: {irq_ack, irq_counter} <= {1'b1, irq_reload};
				5'b111_01: {irq_ack, irq_enable} <= {1'b1, prg_din[3:0]};
				5'b111_10: mirroring <= prg_din[1:0];
				5'b111_11: ram_enable <= prg_din[1:0];
				endcase

		//Is this necessary? or even correct?  Just load number of needed bits into separate counter instead?
		if (irq_enable[0]) begin
			irq_counter[3:0] <= irq_counter[3:0] - 4'd1;
			if (irq_counter[3:0] == 4'h0) begin
				if (irq_enable[3]) begin
					irq <= 1'b1;	// IRQ
				end else begin
					irq_counter[7:4] <= irq_counter[7:4] - 4'd1;
					if (irq_counter[7:4] == 4'h0) begin
						if (irq_enable[2]) begin
							irq <= 1'b1;	// IRQ
						end else begin
							irq_counter[11:8] <= irq_counter[11:8] - 4'd1;
							if (irq_counter[11:8] == 4'h0) begin
								if (irq_enable[1]) begin
									irq <= 1'b1;	// IRQ
								end else begin
									irq_counter[15:12] <= irq_counter[15:12] - 4'd1;
									if (irq_counter[15:12] == 4'h0) begin
										irq <= 1'b1;	// IRQ
									end
								end
							end
						end
					end
				end
			end
		end
		if (irq_ack)
			irq <= 1'b0;	// IRQ ACK
			
	end
	
	always begin
      // mirroring
      casez(mirroring[1:0])
      2'b00:   vram_a10 = {chr_ain[11]};    // horizontal
      2'b01:   vram_a10 = {chr_ain[10]};    // vertical
      2'b1?:   vram_a10 = {mirroring[0]};   // single screen lower
      endcase
	end 
	
   reg [7:0] prgsel;  
	always begin
		case(prg_ain[14:13])
		2'b00: 	prgsel = prg_bank_0;			// $8000 is swapable
		2'b01: 	prgsel = prg_bank_1;			// $A000 is swapable
		2'b10: 	prgsel = prg_bank_2;			// $C000 is swapable
		2'b11: 	prgsel = 8'hFF;				// $E000 is hardwired to last bank
		endcase
	end

   reg [7:0] chrsel;  
   always begin
    casez(chr_ain[12:10])
    0: chrsel = chr_bank_0;
    1: chrsel = chr_bank_1;
    2: chrsel = chr_bank_2;
    3: chrsel = chr_bank_3;
    4: chrsel = chr_bank_4;
    5: chrsel = chr_bank_5;
    6: chrsel = chr_bank_6;
    7: chrsel = chr_bank_7;
    endcase
   end	
	assign chr_aout = {4'b10_00, chrsel, chr_ain[9:0]};					// 1kB banks
	wire [21:0] prg_aout_tmp = {2'b00, prgsel[6:0], prg_ain[12:0]};  	// 8kB banks	
	
	wire prg_is_ram = (prg_ain >= 'h6000) && (prg_ain < 'h8000);
   wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
   assign prg_aout = prg_is_ram ? prg_ram : prg_aout_tmp;
	assign prg_dout = 8'hFF;
  
   assign prg_allow = (prg_ain[15] && !prg_write) || (prg_is_ram && ram_enable[0] && (ram_enable[1] || !prg_write));
	assign chr_allow = flags[15];
	assign vram_ce = chr_ain[13];
endmodule

// Tepples/Multi-discrete mapper
// This mapper can emulate other mappers,  such as mapper #0, mapper #2
module Mapper28(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                output prg_open_bus,                         // PRG Data not driven
                output prg_conflict,                         // PRG Bus Conflict
                input [13:0] chr_ain, output [21:0] chr_aout,
					 output reg [7:0] chr_dout, output has_chr_dout,
                output chr_allow,                      // Allow write
                output reg vram_a10,                         // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
    reg [6:0] a53prg;    // output PRG ROM (A14-A20 on ROM)
    reg [1:0] a53chr;    // output CHR RAM (A13-A14 on RAM)
   
    reg [3:0] inner;    // "inner" bank at 01h
    reg [5:0] mode;     // mode register at 80h
    reg [5:0] outer;    // "outer" bank at 81h  
    reg [2:0] selreg;   // selector register
    reg [3:0] security; // selector register
    
    // Allow writes to 0x5000 only when launching through the proper mapper ID.
    wire [7:0] mapper = flags[7:0];
    wire allow_select = (mapper == 8'd28); 
	 wire extend_bit = (mapper == 97);

    always @(posedge clk) if (reset) begin
      mode[5:2] <= 0;         // NROM mode, 32K mode
      outer[5:0] <= 6'h3f;    // last bank
      inner <= 0;
      selreg <= 1;
      
      // Set value for mirroring
      if (mapper == 2 || mapper == 0 || mapper == 3 || mapper == 94 || mapper == 180 || mapper == 185)
        mode[1:0] <= flags[14] ? 2'b10 : 2'b11;
        
      // UNROM #2 - Current bank in $8000-$BFFF and fixed top half of outer bank in $C000-$FFFF
      if (mapper == 2) begin
        mode[5:2] <= 4'b1111; // 256K banks, UNROM mode
      end
		
      // CNROM #3 - Fixed PRG bank, switchable CHR bank.
      if (mapper == 3)
        selreg <= 0;

      // CNROM #185 - Fixed PRG bank, Fixed CHR Bank, Security.
      if (mapper == 185)
        selreg <= 4;

      // UNROM #180 - Fixed first PRG bank, Fixed CHR Bank.
      if (mapper == 180) begin
        selreg <= 1;
		  mode[5:2] <= 4'b1110;
		  outer[5:0] <= 6'h00;
      end

      // IREM TAM-S1 IC #97 - Fixed first PRG bank, Fixed CHR Bank, Mirroring.
      if (mapper == 97) begin
        selreg <= 6;
		  mode[5:2] <= 4'b1110;
		  outer[5:0] <= 6'h3F;
      end

      // IREM TAM-S1 IC #94 - Fixed last PRG bank, Fixed CHR Bank
      if (mapper == 94) begin
        selreg <= 7;
		  mode[5:2] <= 4'b1111;
      end

      // AxROM #7 - Switch 32kb rom bank + switchable nametables
      if (mapper == 7) begin
        mode[1:0] <= 2'b00;   // Switchable VRAM page.
        mode[5:2] <= 4'b1100; // 256K banks, (B)NROM mode
		  outer[5:0] <= 6'h00;
      end
    end else if (ce) begin
      if ((prg_ain[15:12] == 4'h5) & prg_write && allow_select)
			selreg <= {1'b0,prg_din[7], prg_din[0]};        // select register
      if (prg_ain[15] & prg_write) begin
        casez (selreg)
        3'b000:  {mode[0], a53chr}  <= {(mode[1] ? mode[0] : prg_din[4]), prg_din[1:0]};  // CHR RAM bank
        3'b001:  {mode[0], inner}   <= {(mode[1] ? mode[0] : prg_din[4]), prg_din[3:0]};  // "inner" bank
        3'b010:  {mode}             <= {prg_din[5:0]};                                    // mode register
        3'b011:  {outer}            <= {prg_din[5:0]};                                    // "outer" bank
        3'b10?:  {security}         <= {prg_din[5:4],prg_din[1:0]};                       // security
		  3'b110:  {mode[1:0],inner}  <= {prg_din[7] ^ prg_din[6], prg_din[6], prg_din[3:0]};  // "inner" bank
		  3'b111:  {inner}            <= {prg_din[5:2]};                                    // "inner" bank
        endcase
      end
    end
    
    always begin
      // mirroring mode
      casez(mode[1:0])
      2'b0?   :   vram_a10 = {mode[0]};        // 1 screen lower
      2'b10   :   vram_a10 = {chr_ain[10]};    // vertical
      2'b11   :   vram_a10 = {chr_ain[11]};    // horizontal
      endcase

      // PRG ROM bank size select
      casez({mode[5:2], prg_ain[14]})
      5'b00_0?_?  :  a53prg = {outer[5:0],             prg_ain[14]};  // 32K banks, (B)NROM mode
      5'b01_0?_?  :  a53prg = {outer[5:1], inner[0],   prg_ain[14]};  // 64K banks, (B)NROM mode
      5'b10_0?_?  :  a53prg = {outer[5:2], inner[1:0], prg_ain[14]};  // 128K banks, (B)NROM mode
      5'b11_0?_?  :  a53prg = {outer[5:3], inner[2:0], prg_ain[14]};  // 256K banks, (B)NROM mode
      
      5'b00_10_1,
      5'b00_11_0  :  a53prg = {outer[5:0], inner[0]};             // 32K banks, UNROM mode
      5'b01_10_1,
      5'b01_11_0  :  a53prg = {outer[5:1], inner[1:0]};           // 64K banks, UNROM mode
      5'b10_10_1,
      5'b10_11_0  :  a53prg = {outer[5:2], inner[2:0]};           // 128K banks, UNROM mode
      5'b11_10_1,
      5'b11_11_0  :  a53prg = {outer[5:3], inner[3:0]};           // 256K banks, UNROM mode
      
      default     :  a53prg = {outer[5:0], extend_bit ? outer[0] : prg_ain[14]};  // 16K fixed bank
      endcase
		chr_dout = 8'hFF;//chr_ain[7:0]; // return open bus = LSB of address? below when CHR disabled by security
    end

  assign vram_ce = chr_ain[13];
  assign prg_aout = {1'b0, (a53prg & 7'b0011111), prg_ain[13:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign prg_conflict = prg_ain[15] && (mapper == 3) && (submapper != 1);
  assign prg_open_bus = (prg_ain[15:13] == 3'b011) && (mapper == 7);
  assign chr_allow = flags[15];
  assign chr_aout = {7'b10_0000_0, a53chr, chr_ain[12:0]};
  wire [4:0] submapper = flags[24:21];
  assign has_chr_dout = (mapper == 185) && (   ((submapper == 0) && (security[1:0] == 2'b00))
                                            || ((submapper == 4) && (security[1:0] != 2'b00))
                                            || ((submapper == 5) && (security[1:0] != 2'b01))
                                            || ((submapper == 6) && (security[1:0] != 2'b10))
                                            || ((submapper == 7) && (security[1:0] != 2'b11)));
endmodule

// 30-UNROM512
module Mapper30(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output reg vram_a10,                         // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
    reg [4:0] prgbank;
    reg [1:0] chrbank;
	 reg [2:0] mirror;
	 wire four_screen = (mirror[2:1] == 2'b11);
    
    always @(posedge clk) if (reset) begin
      // Set value for mirroring
        mirror[2:1] <= {flags[16], flags[14]};
    end else if (ce) begin
      if (prg_ain[15] & prg_write) begin
        {mirror[0], chrbank, prgbank}   <= prg_din[7:0];
      end
    end
    
    always begin
      // mirroring mode
      casez({mirror[2:1],chr_ain[13]})
      3'b001   :   vram_a10 = {chr_ain[11]};    // horizontal
      3'b011   :   vram_a10 = {chr_ain[10]};    // vertical
      3'b101   :   vram_a10 = {mirror[0]};      // 1 screen
      3'b111   :   vram_a10 = {chr_ain[10]};    // 4 screen
      default  :   vram_a10 = {chr_ain[10]};    // pattern table
      endcase
    end

  assign prg_aout = {3'b000, prg_ain[14] ? 5'b11111 : prgbank, prg_ain[13:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
  assign chr_aout = {flags[15] ? 7'b11_1111_1 : 7'b10_0000_0, (four_screen && (chr_ain[13])) ? 2'b11 : chrbank, chr_ain[12:11], vram_a10, chr_ain[9:0]};
  assign vram_ce = chr_ain[13] && !four_screen;
endmodule

// 32 - IREM
module Mapper32(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output reg vram_a10,                         // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
    reg [4:0] prgreg0;
    reg [4:0] prgreg1;
    reg [7:0] chrreg0;
    reg [7:0] chrreg1;
    reg [7:0] chrreg2;
    reg [7:0] chrreg3;
    reg [7:0] chrreg4;
    reg [7:0] chrreg5;
    reg [7:0] chrreg6;
    reg [7:0] chrreg7;
	 reg prgmode;
	 reg mirror;
	 wire submapper1 = (flags[21] == 1); // default (0) default submapper; (1) Major League
	 reg [4:0] prgsel;
	 reg [7:0] chrsel;

    always @(posedge clk) if (reset) begin
      prgmode <= 1'b0;
    end else if (ce) begin
      if ((prg_ain[15:14] == 2'b10) & prg_write) begin
        casez ({prg_ain[13:12], submapper1, prg_ain[2:0]})
        6'b00_?_???:  prgreg0            <= prg_din[4:0];
        6'b01_0_???:  {prgmode, mirror}  <= prg_din[1:0];
        6'b10_0_???:  prgreg1            <= prg_din[4:0];
        6'b11_?_000:  chrreg0            <= prg_din;
        6'b11_?_001:  chrreg1            <= prg_din;
        6'b11_?_010:  chrreg2            <= prg_din;
        6'b11_?_011:  chrreg3            <= prg_din;
        6'b11_?_100:  chrreg4            <= prg_din;
        6'b11_?_101:  chrreg5            <= prg_din;
        6'b11_?_110:  chrreg6            <= prg_din;
        6'b11_?_111:  chrreg7            <= prg_din;
        endcase
      end
    end
    
    always begin
      // mirroring mode
      casez({submapper1, mirror})
      2'b00   :   vram_a10 = {chr_ain[10]};    // vertical
      2'b01   :   vram_a10 = {chr_ain[11]};    // horizontal
      2'b1?   :   vram_a10 = {1'b1};           // 1 screen lower
      endcase

      // PRG ROM bank size select
      casez({prg_ain[14:13], prgmode})
      3'b000  :  prgsel = prgreg0;
      3'b001  :  prgsel = {5'b11110};
      3'b01?  :  prgsel = prgreg1;
      3'b100  :  prgsel = {5'b11110};
      3'b101  :  prgsel = prgreg0;
      3'b11?  :  prgsel = {5'b11111};
		endcase

      // CHR ROM bank size select
      casez({chr_ain[12:10]})
      3'b000  :  chrsel = chrreg0;
      3'b001  :  chrsel = chrreg1;
      3'b010  :  chrsel = chrreg2;
      3'b011  :  chrsel = chrreg3;
      3'b100  :  chrsel = chrreg4;
      3'b101  :  chrsel = chrreg5;
      3'b110  :  chrsel = chrreg6;
      3'b111  :  chrsel = chrreg7;
      endcase
    end

  assign vram_ce = chr_ain[13];
  assign prg_aout = {4'b00_00, prgsel, prg_ain[12:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
  assign chr_aout = {4'b10_00, chrsel, chr_ain[9:0]};
endmodule

// Mapper 42, used for hacked FDS games converted to cartridge form
module Mapper42(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                      		// Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce,                     			// True if the address should be routed to the internal 2kB VRAM.
				output reg irq); 

	reg [3:0] prg_bank;
	reg [3:0] chr_bank;
	reg [3:0] prg_sel;
	reg mirroring;
	reg irq_enable;
	reg [14:0] irq_counter;
	
	always @(posedge clk) if (reset) begin
		prg_bank <= 0;
		chr_bank <= 0;
		mirroring <= flags[14];
		irq_counter <= 0;
	end else if (ce) begin
		if (prg_write)
			case(prg_ain & 16'he003)
			16'h8000: chr_bank <= prg_din[3:0];
			16'he000: prg_bank <= prg_din[3:0];
			16'he001: mirroring <= prg_din[3];
			16'he002: irq_enable <= prg_din[1];
			endcase

		if (irq_enable)
			irq_counter <= irq_counter + 15'd1;
		else begin
			irq <= 1'b0;	// ACK
			irq_counter <= 0;
		end	
		
		if (irq_counter == 15'h6000)
			irq <= 1'b1;
			
	end
	
	always @* begin
/* PRG bank selection
	6000-7FFF: Selectable
	8000-9FFF: bank #0Ch
	A000-BFFF: bank #0Dh
	C000-DFFF: bank #0Eh
	E000-FFFF: bank #0Fh
*/	
		case(prg_ain[15:13])
		3'b011: 	prg_sel = prg_bank;                // $6000-$7FFF
		3'b100: 	prg_sel = 4'hC;
		3'b101: 	prg_sel = 4'hD;
		3'b110: 	prg_sel = 4'hE;
		3'b111: 	prg_sel = 4'hF;
		default: prg_sel = 0;
		endcase
	end 
	assign prg_aout = {5'b0, prg_sel, prg_ain[12:0]};    		// 8kB banks
	assign chr_aout = {5'b10_000, chr_bank, chr_ain[12:0]};	// 8kB banks

	assign prg_allow = (prg_ain >= 16'h6000) && !prg_write;
	assign chr_allow = flags[15];
	assign vram_ce = chr_ain[13];
	assign vram_a10 = mirroring ? chr_ain[10] : chr_ain[11];
endmodule

// Mapper 65, IREM H3001
module Mapper65(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                      		// Allow write
            output reg vram_a10,                         // Value for A10 address line
            output vram_ce,                     			// True if the address should be routed to the internal 2kB VRAM.
				output reg irq); 

	reg [7:0] prg_bank_0, prg_bank_1, prg_bank_2;
	reg [7:0] chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_3,
				 chr_bank_4, chr_bank_5, chr_bank_6, chr_bank_7;
	reg mirroring;
	reg irq_ack;
	reg irq_enable;
	reg [15:0] irq_reload;
	reg [15:0] irq_counter;
	
	always @(posedge clk) if (reset) begin
		prg_bank_0 <= 8'h00;
		prg_bank_1 <= 8'h01;
		prg_bank_2 <= 8'hFE;
		chr_bank_0 <= 0;
		chr_bank_1 <= 0;
		chr_bank_2 <= 0;
		chr_bank_3 <= 0;
		chr_bank_4 <= 0;
		chr_bank_5 <= 0;
		chr_bank_6 <= 0;
		chr_bank_7 <= 0;
		mirroring <= 0;
		irq_reload <= 0;
		irq_counter <= 0;
		irq_enable <= 0;
	end else if (ce) begin
	   irq_ack <= 1'b0;
		if ((prg_write) && (prg_ain[15]))						// Cover all from $8000 to $FFFF to maximize compatibility
			case({prg_ain[14:12],prg_ain[2:0]})				// 
			6'b000_000: prg_bank_0 <= prg_din;
			6'b010_000: prg_bank_1 <= prg_din;
			6'b100_000: prg_bank_2 <= prg_din;
			6'b011_000: chr_bank_0 <= prg_din;
			6'b011_001: chr_bank_1 <= prg_din;
			6'b011_010: chr_bank_2 <= prg_din;
			6'b011_011: chr_bank_3 <= prg_din;
			6'b011_100: chr_bank_4 <= prg_din;
			6'b011_101: chr_bank_5 <= prg_din;
			6'b011_110: chr_bank_6 <= prg_din;
			6'b011_111: chr_bank_7 <= prg_din;
			6'b001_001: mirroring <= prg_din[7];
			6'b001_011: {irq_ack, irq_enable} <= {1'b1, prg_din[7]};
			6'b001_100: {irq_ack, irq_counter} <= {1'b1, irq_reload};
			6'b001_101: irq_reload[15:8] <= prg_din;
			6'b001_110: irq_reload[7:0] <= prg_din;
			endcase

		if (irq_enable) begin
			irq_counter <= irq_counter - 16'd1;
			if (irq_counter == 16'h0) begin
				irq <= 1'b1;	// IRQ
				irq_enable <= 0;
				irq_counter <= 0;
			end
		end
		if (irq_ack)
			irq <= 1'b0;	// IRQ ACK
	end
	
	always begin
      vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];    // horizontal:vertical
	end 
	
   reg [7:0] prgsel;  
	always begin
		case(prg_ain[14:13])
		2'b00: 	prgsel = prg_bank_0;			// $8000 is swapable
		2'b01: 	prgsel = prg_bank_1;			// $A000 is swapable
		2'b10: 	prgsel = prg_bank_2;			// $C000 is swapable
		2'b11: 	prgsel = 8'hFF;				// $E000 is hardwired to last bank
		endcase
	end

   reg [7:0] chrsel;  
   always begin
    casez(chr_ain[12:10])
    0: chrsel = chr_bank_0;
    1: chrsel = chr_bank_1;
    2: chrsel = chr_bank_2;
    3: chrsel = chr_bank_3;
    4: chrsel = chr_bank_4;
    5: chrsel = chr_bank_5;
    6: chrsel = chr_bank_6;
    7: chrsel = chr_bank_7;
    endcase
   end	
	assign chr_aout = {4'b10_00, chrsel, chr_ain[9:0]};					// 1kB banks
	assign prg_aout = {2'b00, prgsel[6:0], prg_ain[12:0]};  	// 8kB banks	
  
   assign prg_allow = (prg_ain[15] && !prg_write);
	assign chr_allow = flags[15];
	assign vram_ce = chr_ain[13];
endmodule

// 11 - Color Dreams
// 38 - Bit Corps
// 86 - Jaleco JF-13 -- no audio samples
// 87 - Jaleco JF-11,JF-14
// 101 - Jaleco JF-11,JF-14
// 140 - Jaleco JF-11,JF-14
// 66 - GxROM
module Mapper66(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output vram_a10,                             // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
  reg [1:0] prg_bank;
  reg [3:0] chr_bank;
  wire [7:0] mapper = flags[7:0];
  wire GXROM = (mapper == 66);
  wire BitCorps = (mapper == 38);
  wire Mapper140 = (mapper == 140);
  wire Mapper101 = (mapper == 101);
  wire Mapper86 = (mapper == 86);
  wire Mapper87 = (mapper == 87);
  always @(posedge clk) if (reset) begin
    prg_bank <= 0;
    chr_bank <= 0;
  end else if (ce) begin
    if (prg_ain[15] & prg_write) begin
      if (GXROM)
        {prg_bank, chr_bank} <= {prg_din[5:4], 2'b0, prg_din[1:0]};
      else // Color Dreams
        {chr_bank, prg_bank} <= {prg_din[7:4], prg_din[1:0]};
    end
    else if ((prg_ain[15:12]==4'h7) & prg_write & BitCorps) begin
      {chr_bank, prg_bank} <= {prg_din[3:0]};
    end
    else if ((prg_ain[15:12]==4'h6) & prg_write) begin
       if (Mapper140) begin
         {prg_bank, chr_bank} <= {prg_din[5:4], prg_din[3:0]};
       end else if (Mapper101) begin
        {chr_bank} <= {prg_din[3:0]}; // All 8 bits instead?
       end else if (Mapper87) begin
        {chr_bank} <= {2'b00, prg_din[0], prg_din[1]};
       end else if (Mapper86) begin
         {prg_bank, chr_bank} <= {prg_din[5:4], 1'b0, prg_din[6], prg_din[1:0]};
       end
    end
  end
  assign prg_aout = {5'b00_000, prg_bank, prg_ain[14:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
  assign chr_aout = {5'b10_000, chr_bank, chr_ain[12:0]};
  assign vram_ce = chr_ain[13];
  assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];
endmodule


// Mapper 190, Magic Kid GooGoo
// Mapper 67, Sunsoft-3
module Mapper67(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                      		// Allow write
            output reg vram_a10,                         // Value for A10 address line
            output vram_ce,                     			// True if the address should be routed to the internal 2kB VRAM.
				output reg irq); 

	reg [7:0] prg_bank_0;
	reg [7:0] chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_3;
	reg [1:0] mirroring;
	reg irq_ack;
	reg irq_enable;
	reg irq_low;
	reg [15:0] irq_counter;
	wire mapper190 = (flags[7:0] == 190);
	
	always @(posedge clk) if (reset) begin
		prg_bank_0 <= 0;
		chr_bank_0 <= 0;
		chr_bank_1 <= 0;
		chr_bank_2 <= 0;
		chr_bank_3 <= 0;
		mirroring <= 2'b00; //vertical for mapper190
		irq_counter <= 0;
		irq_enable <= 0;
		irq_low <= 0;
	end else if (ce) begin
	   irq_ack <= 1'b0;
		if ((prg_write) && (prg_ain[15]))						// Cover all from $8000 to $FFFF to maximize compatibility
		  if (!mapper190)
			casez({prg_ain[14:11],irq_low})				// 
			5'b000_1_?: chr_bank_0 <= prg_din;
			5'b001_1_?: chr_bank_1 <= prg_din;
			5'b010_1_?: chr_bank_2 <= prg_din;
			5'b011_1_?: chr_bank_3 <= prg_din;
			5'b110_1_?: mirroring <= prg_din[1:0];
			5'b111_1_?: prg_bank_0 <= prg_din;
			5'b100_1_0: {irq_low, irq_counter[15:8]} <= {1'b1,prg_din};
			5'b100_1_1: {irq_low, irq_counter[7:0]} <= {1'b0,prg_din};
			5'b101_1_?: {irq_low, irq_ack, irq_enable} <= {2'b01, prg_din[4]};
			endcase
		  else
			casez({prg_ain[13],prg_ain[1:0]})				// 
			3'b0_??: prg_bank_0[3:0] <= {prg_ain[14],prg_din[2:0]};
			3'b1_00: chr_bank_0 <= prg_din;
			3'b1_01: chr_bank_1 <= prg_din;
			3'b1_10: chr_bank_2 <= prg_din;
			3'b1_11: chr_bank_3 <= prg_din;
			endcase

		if (irq_enable) begin
			irq_counter <= irq_counter - 16'd1;
			if (irq_counter == 16'h0) begin
				irq <= 1'b1;	// IRQ
				irq_enable <= 0;
			end
		end
		if (irq_ack)
			irq <= 1'b0;	// IRQ ACK
	end
	
	always begin
      casez({mirroring})
      2'b00   :   vram_a10 = {chr_ain[10]};    // vertical
      2'b01   :   vram_a10 = {chr_ain[11]};    // horizontal
      2'b1?   :   vram_a10 = {mirroring[0]};   // 1 screen lower:upper
      endcase
	end 
	
   reg [7:0] prgsel;  
	always begin
		case(prg_ain[14])
		1'b0: 	prgsel = prg_bank_0;						// $8000 is swapable
		1'b1: 	prgsel = mapper190 ? 8'h00 : 8'hFF;	// $C000 is hardwired to first/last bank
		endcase
	end

   reg [7:0] chrsel;  
   always begin
    casez(chr_ain[12:11])
    0: chrsel = chr_bank_0;
    1: chrsel = chr_bank_1;
    2: chrsel = chr_bank_2;
    3: chrsel = chr_bank_3;
    endcase
   end	
	assign chr_aout = {3'b10_0, chrsel, chr_ain[10:0]};					//  2kB banks
	wire [21:0] prg_aout_tmp = {2'b00, prgsel[5:0], prg_ain[13:0]};  	// 16kB banks	
	
	wire prg_is_ram = (prg_ain >= 'h6000) && (prg_ain < 'h8000);
   wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
   assign prg_aout = prg_is_ram ? prg_ram : prg_aout_tmp;
  
   assign prg_allow = (prg_ain[15] && !prg_write) || prg_is_ram;
	assign chr_allow = flags[15];
	assign vram_ce = chr_ain[13];
endmodule

// 34 - BxROM or NINA-001
module Mapper34(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output vram_a10,                             // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
  reg [5:0] prg_bank;
  reg [3:0] chr_bank_0, chr_bank_1;
  
  wire NINA = (flags[13:11] != 0); // NINA is used when there is more than 8kb of CHR
  always @(posedge clk) if (reset) begin
    prg_bank <= 0;
    chr_bank_0 <= 0;
    chr_bank_1 <= 1; // To be compatible with BxROM
  end else if (ce && prg_write) begin
    if (!NINA) begin // BxROM
      if (prg_ain[15])
        prg_bank <= prg_din[5:0]; //[1:0] offical, [5:0] oversize
    end else begin // NINA
      if (prg_ain == 16'h7ffd)
        prg_bank <= prg_din[5:0]; //[1:0] offical, [5:0] oversize
      else if (prg_ain == 16'h7ffe)
        chr_bank_0 <= prg_din[3:0];
      else if (prg_ain == 16'h7fff)
        chr_bank_1 <= prg_din[3:0];
    end
  end

  wire [21:0] prg_aout_tmp = {1'b0, prg_bank, prg_ain[14:0]};
  assign chr_allow = flags[15];
  assign chr_aout = {6'b10_0000, chr_ain[12] == 0 ? chr_bank_0 : chr_bank_1, chr_ain[11:0]};
  assign vram_ce = chr_ain[13];
  assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];

  wire prg_is_ram = (prg_ain >= 'h6000 && prg_ain < 'h8000) && NINA;
  assign prg_allow = prg_ain[15] && !prg_write ||
                     prg_is_ram;
  wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
  assign prg_aout = prg_is_ram ? prg_ram : prg_aout_tmp;
endmodule

// 41 - Caltron 6-in-1
module Mapper41(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output vram_a10,                             // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
  reg [2:0] prg_bank;
  reg [1:0] chr_outer_bank, chr_inner_bank;
  reg mirroring;
  
  always @(posedge clk) if (reset) begin
    prg_bank <= 0;
    chr_outer_bank <= 0;
    chr_inner_bank <= 0;
    mirroring <= 0;
  end else if (ce && prg_write) begin
    if (prg_ain[15:11] == 5'b01100) begin
      {mirroring, chr_outer_bank, prg_bank} <= prg_ain[5:0];
    end else if (prg_ain[15] && prg_bank[2]) begin
      // The Inner CHR Bank Select only can be written while the PRG ROM bank is 4, 5, 6, or 7
      chr_inner_bank <= prg_din[1:0];
    end
  end

  assign prg_aout = {4'b00_00, prg_bank, prg_ain[14:0]};
  assign chr_allow = flags[15];
  assign chr_aout = {5'b10_000, chr_outer_bank, chr_inner_bank, chr_ain[12:0]};
  assign vram_ce = chr_ain[13];
  assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];
  assign prg_allow = prg_ain[15] && !prg_write;
endmodule

// #68 - Sunsoft-4 - Game After Burner, and some japanese games. MAX: 128kB PRG, 256kB CHR
module Mapper68(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output vram_a10,                             // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
  reg [6:0] chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_3;
  reg [6:0] nametable_0, nametable_1;
  reg [2:0] prg_bank;
  reg use_chr_rom;
  reg mirroring;
  always @(posedge clk) if (reset) begin
    chr_bank_0 <= 0;
    chr_bank_1 <= 0;
    chr_bank_2 <= 0;
    chr_bank_3 <= 0;
    nametable_0 <= 0;
    nametable_1 <= 0;
    prg_bank <= 0;
    use_chr_rom <= 0;
    mirroring <= 0;
  end else if (ce) begin
    if (prg_ain[15] && prg_write) begin
//      $write("REG[%d] <= %X\n", prg_ain[14:12], prg_din);
      case(prg_ain[14:12])
      0: chr_bank_0  <= prg_din[6:0]; // $8000-$8FFF: 2kB CHR bank at $0000
      1: chr_bank_1  <= prg_din[6:0]; // $9000-$9FFF: 2kB CHR bank at $0800
      2: chr_bank_2  <= prg_din[6:0]; // $A000-$AFFF: 2kB CHR bank at $1000
      3: chr_bank_3  <= prg_din[6:0]; // $B000-$BFFF: 2kB CHR bank at $1800
      4: nametable_0 <= prg_din[6:0]; // $C000-$CFFF: 1kB Nametable register 0 at $2000
      5: nametable_1 <= prg_din[6:0]; // $D000-$DFFF: 1kB Nametable register 1 at $2400
      6: {use_chr_rom, mirroring} <= {prg_din[4], prg_din[0]};  // $E000-$EFFF: Nametable control
      7: prg_bank <= prg_din[2:0]; 
      endcase
    end
  end
  wire [2:0] prgout = (prg_ain[14] ? 3'b111 : prg_bank);
  assign prg_aout = {5'b00_000, prgout, prg_ain[13:0]};
  assign prg_allow = prg_ain[15] && !prg_write;

  reg [6:0] chrout;  
  always begin
    casez(chr_ain[12:11])
    0: chrout = chr_bank_0;
    1: chrout = chr_bank_1;
    2: chrout = chr_bank_2;
    3: chrout = chr_bank_3;
    endcase
  end
  assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];
  wire [6:0] nameout = (vram_a10 == 0) ? nametable_0 : nametable_1;
 
  assign chr_allow = flags[15];
  assign chr_aout = (chr_ain[13] == 0) ? {4'b10_00, chrout, chr_ain[10:0]} : {5'b10_001, nameout, chr_ain[9:0]};
  assign vram_ce = chr_ain[13] && !use_chr_rom;

endmodule

// 69 - Sunsoft FME-7
module Mapper69(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                          // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                             // Allow write
                output reg vram_a10,                          // Value for A10 address line
                output vram_ce,                               // True if the address should be routed to the internal 2kB VRAM.
                output reg irq,
                output [15:0] audio);
  reg [7:0] chr_bank[0:7];
  reg [4:0] prg_bank[0:3];
  reg [1:0] mirroring;
  reg irq_countdown, irq_trigger;
  reg [15:0] irq_counter;
  reg [3:0] addr;
  reg ram_enable, ram_select;
  wire [16:0] new_irq_counter = irq_counter - {15'b0, irq_countdown};
  always @(posedge clk) if (reset) begin
    chr_bank[0] <= 0;
    chr_bank[1] <= 0;
    chr_bank[2] <= 0;
    chr_bank[3] <= 0;
    chr_bank[4] <= 0;
    chr_bank[5] <= 0;
    chr_bank[6] <= 0;
    chr_bank[7] <= 0;
    prg_bank[0] <= 0;
    prg_bank[1] <= 0;
    prg_bank[2] <= 0;
    prg_bank[3] <= 0;
    mirroring <= 0;
    irq_countdown <= 0;
    irq_trigger <= 0;
    irq_counter <= 0;
    addr <= 0;
    ram_enable <= 0;
    ram_select <= 0;
    irq <= 0;
  end else if (ce) begin
    irq_counter <= new_irq_counter[15:0];
    if (irq_trigger && new_irq_counter[16]) irq <= 1;
    if (!irq_trigger) irq <= 0;
      
    if (prg_ain[15] & prg_write) begin
      case (prg_ain[14:13])
      0: addr <= prg_din[3:0];
      1: begin
          case(addr)
          0,1,2,3,4,5,6,7: chr_bank[addr[2:0]] <= prg_din;
          8,9,10,11:       prg_bank[addr[1:0]] <= prg_din[4:0];
          12:              mirroring <= prg_din[1:0];
          13:              {irq_countdown, irq_trigger} <= {prg_din[7], prg_din[0]};
          14:              irq_counter[7:0] <= prg_din;
          15:              irq_counter[15:8] <= prg_din;
          endcase
          if (addr == 8) {ram_enable, ram_select} <= prg_din[7:6];
        end
      endcase
    end
  end
  always begin
    casez(mirroring[1:0])
    2'b00   :   vram_a10 = {chr_ain[10]};    // vertical
    2'b01   :   vram_a10 = {chr_ain[11]};    // horizontal
    2'b1?   :   vram_a10 = {mirroring[0]};   // 1 screen lower
    endcase
  end
  reg [4:0] prgout;
  reg [7:0] chrout;
  always begin
    casez(prg_ain[15:13])
    3'b011:  prgout = prg_bank[0];
    3'b100:  prgout = prg_bank[1];
    3'b101:  prgout = prg_bank[2];
    3'b110:  prgout = prg_bank[3];
    3'b111:  prgout = 5'b11111;
    default: prgout = 5'bxxxxx;
    endcase
    chrout = chr_bank[chr_ain[12:10]];
  end
  wire ram_cs = (prg_ain[15] == 0 && ram_select);
  assign prg_aout = {1'b0, ram_cs, 2'b00, prgout[4:0], prg_ain[12:0]};
  assign prg_allow = ram_cs ? ram_enable : !prg_write;
  assign chr_allow = flags[15];
  assign chr_aout = {4'b10_00, chrout, chr_ain[9:0]};
  assign vram_ce = chr_ain[13];

//Taken from Loopy's Power Pak mapper source
//audio
    wire [6:0] fme7_out;
	 wire [15:0] fme7_sample;
    FME7_sound snd0(clk, ce, reset, prg_write, prg_ain, prg_din, fme7_out);
    //FME7_sound snd0(m2, reset, nesprg_we, prgain, nesprgdin, fme7_out);
    //pdm #(7) pdm_mod(clk20, fme7_out, exp6);

  //Need a better lookup table for this
  //This is just the NES APU lookup table, which is designed for 2 4-bit square waves, not 3
  ApuLookupTable lookup(clk, 
                        {4'b0, fme7_out[5:1]}, //fme7_out range: 0-2D
                        {8'b0},                //No triange, noise or DMC
                        fme7_sample);
  assign audio = {fme7_sample[14:0], 1'b0};    // Double.  Volume will be slightly higher, rather than slightly lower than expected
	 
endmodule

// #71,#232 - Camerica
module Mapper71(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output vram_a10,                             // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
  reg [3:0] prg_bank;
  reg ciram_select;
  wire mapper232 = (flags[7:0] == 232);
  always @(posedge clk) if (reset) begin
    prg_bank <= 0;
    ciram_select <= 0;
  end else if (ce) begin
    if (prg_ain[15] && prg_write) begin
      //$write("%X <= %X (bank = %x)\n", prg_ain, prg_din, prg_bank);
      if (!prg_ain[14] && mapper232) // $8000-$BFFF Outer bank select (only on iNES 232)
        prg_bank[3:2] <= prg_din[4:3];
      if (prg_ain[14:13] == 0)       // $8000-$9FFF Fire Hawk Mirroring
        ciram_select <= prg_din[4];
      if (prg_ain[14])               // $C000-$FFFF Bank select
        prg_bank <= {mapper232 ? prg_bank[3:2] : prg_din[3:2], prg_din[1:0]};
    end
  end
  reg [3:0] prgout;
  always begin
    casez({prg_ain[14], mapper232})
    2'b0?: prgout = prg_bank;
    2'b10: prgout = 4'b1111;
    2'b11: prgout = {prg_bank[3:2], 2'b11};
    endcase
  end
  assign prg_aout = {4'b00_00, prgout, prg_ain[13:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
  assign chr_aout = {9'b10_0000_000, chr_ain[12:0]};
  assign vram_ce = chr_ain[13];
  // XXX(ludde): Fire hawk uses flags[14] == 0 while no other game seems to do that.
  // So when flags[14] == 0 we use ciram_select instead.
  assign vram_a10 = flags[14] ? chr_ain[10] : ciram_select;
endmodule


// 92 - Jaleco JF-19 -- no audio samples
// 72 - Jaleco JF-17 -- no audio samples
module Mapper72(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output vram_a10,                             // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
  reg [3:0] prg_bank;
  reg [3:0] chr_bank;
  wire [7:0] mapper = flags[7:0];
  reg last_prg;
  reg last_chr;
  wire mapper72 = (mapper == 72);

  always @(posedge clk) if (reset) begin
    prg_bank <= 0;
    chr_bank <= 0;
	 last_prg <= 0;
	 last_chr <= 0;
  end else if (ce) begin
    if (prg_ain[15] & prg_write) begin
      if ((!last_prg) && (prg_din[7]))
        {prg_bank} <= {prg_din[3:0]};
      if ((!last_chr) && (prg_din[6]))
        {chr_bank} <= {prg_din[3:0]};
		{last_prg, last_chr} <= prg_din[7:6];
    end
  end
  assign prg_aout = {4'b00_00, prg_ain[14] ^ mapper72 ? prg_bank : mapper72 ? 4'b1111 : 4'b0000, prg_ain[13:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
  assign chr_aout = {5'b10_000, chr_bank, chr_ain[12:0]};
  assign vram_ce = chr_ain[13];
  assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];
endmodule

// 77-IREM
module Mapper77(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output reg vram_a10,                         // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
    reg [3:0] prgbank;
    reg [3:0] chrbank;
    
    always @(posedge clk) if (reset) begin
        prgbank <= 0;
		  chrbank <= 0;
    end else if (ce) begin
      if (prg_ain[15] & prg_write) begin
        {chrbank, prgbank}   <= prg_din[7:0];
      end
    end
    
  always begin
     vram_a10 = {chr_ain[10]};    // four screen (consecutive)
  end

  assign prg_aout = {3'b000, prgbank, prg_ain[14:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = chrram;
  wire chrram = (chr_ain[13:11]!=3'b000);
  assign chr_aout[10:0] = {chr_ain[10:0]};
  assign chr_aout[21:11] = chrram ? {8'b11_1111_11, chr_ain[13:11]} : {7'b10_0000_0, chrbank};
  assign vram_ce = 0;
endmodule

// #78-IREM-HOLYDIVER/JALECO-JF-16
// #70,#152-Bandai
module Mapper78(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output vram_a10,                             // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
  reg [3:0] prg_bank;
  reg [3:0] chr_bank;
  reg mirroring;  // See vram_a10_t
  wire mapper70 = (flags[7:0] == 70);
  wire mapper152 = (flags[7:0] == 152);
  wire onescreen = (flags[22:21] == 1) | mapper152; // default (0 or 3) Holy Diver submapper; (1) JALECO-JF-16
  always @(posedge clk) if (reset) begin
    prg_bank <= 0;
    chr_bank <= 0;
    mirroring <= flags[14];
  end else if (ce) begin
    if (prg_ain[15] == 1'b1 && prg_write) begin
      if (mapper70)
        {prg_bank, chr_bank} <= prg_din;
      else if (mapper152)
        {mirroring, prg_bank[2:0], chr_bank} <= prg_din;
      else
        {chr_bank, mirroring, prg_bank[2:0]} <= prg_din;
    end
  end
  assign prg_aout = {4'b00_00, (prg_ain[14] ? 4'b1111 : prg_bank), prg_ain[13:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
  assign chr_aout = {5'b10_000, chr_bank, chr_ain[12:0]};
  assign vram_ce = chr_ain[13];

  // The a10 VRAM address line. (Used for mirroring)
  reg vram_a10_t;
  always begin
    case({onescreen, mirroring})
    2'b00: vram_a10_t = chr_ain[11];   // One screen, horizontal
    2'b01: vram_a10_t = chr_ain[10];   // One screen, vertical
    2'b10: vram_a10_t = 0;             // One screen, lower bank
    2'b11: vram_a10_t = 1;             // One screen, upper bank
    endcase
  end
  assign vram_a10 = vram_a10_t;
endmodule

// #79,#113 - NINA-03 / NINA-06
module Mapper79(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output vram_a10,                             // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
  reg [2:0] prg_bank;
  reg [3:0] chr_bank;
  reg mirroring;  // 0: Horizontal, 1: Vertical
  wire mapper113 = (flags[7:0] == 113); // NINA-06
  always @(posedge clk) if (reset) begin
    prg_bank <= 0;
    chr_bank <= 0;
    mirroring <= 0;
  end else if (ce) begin
    if (prg_ain[15:13] == 3'b010 && prg_ain[8] && prg_write)
      {mirroring, chr_bank[3], prg_bank, chr_bank[2:0]} <= prg_din;
  end
  assign prg_aout = {4'b00_00, prg_bank, prg_ain[14:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
  assign chr_aout = {5'b10_000, chr_bank, chr_ain[12:0]};
  assign vram_ce = chr_ain[13];
  wire mirrconfig = mapper113 ? mirroring : flags[14]; // Mapper #13 has mapper controlled mirroring
  assign vram_a10 = mirrconfig ? chr_ain[10] : chr_ain[11]; // 0: horiz, 1: vert
endmodule


// #89,#93,#184 - Sunsoft mappers
module Mapper89(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output reg vram_a10,                         // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
    reg [2:0] prgsel;
    reg [3:0] chrsel0;
    reg [3:0] chrsel1;
	 reg [2:0] prg_temp;
	 reg [4:0] chr_temp;
   
    reg mirror;
    
    wire [7:0] mapper = flags[7:0];
    wire mapper89 = (mapper == 8'd89); 
    wire mapper93 = (mapper == 8'd93); 
    wire mapper184 = (mapper == 8'd184); 

    always @(posedge clk) if (reset) begin
        prgsel <= 3'b110;
        chrsel0 <= 4'b1111;
        chrsel1 <= 4'b1111;
    end else if (ce) begin
      if (prg_ain[15] & prg_write & mapper89) begin
        {chrsel0[3], prgsel, mirror, chrsel0[2:0]}  <= prg_din;
      end else if (prg_ain[15] & prg_write & mapper93) begin
        prgsel  <= prg_din[6:4];
		  // chrrameanble <= prg_din[0];
      end else if ((prg_ain[15:13]==3'b011) & prg_write & mapper184) begin
        {chrsel1[3:0], chrsel0[3:0]}  <= {2'b01,prg_din[5:4],1'b0,prg_din[2:0]};
		end
    end
    
    always begin
      // mirroring mode
      casez({mapper89,flags[14]})
      2'b00   :   vram_a10 = {chr_ain[11]};    // horizontal
      2'b01   :   vram_a10 = {chr_ain[10]};    // vertical
      2'b1?   :   vram_a10 = {mirror};         // 1 screen
      endcase

      // PRG ROM bank size select
      casez({mapper184, prg_ain[14]})
      2'b00 :  prg_temp = {prgsel};            // 16K banks
      2'b01 :  prg_temp = {3'b111};            // 16K banks last
      2'b1? :  prg_temp = {2'b0,prg_ain[14]};  // 32K banks pass thru
      endcase

      // CHR ROM bank size select
      casez({mapper184, chr_ain[12]})
      2'b0? :  chr_temp = {chrsel0, chr_ain[12]};// 8K Bank
      2'b10 :  chr_temp = {1'b0,chrsel0};  // 4K Bank
      2'b11 :  chr_temp = {1'b0,chrsel1};  // 4K Bank
      endcase
    end

  assign vram_ce = chr_ain[13];
  assign prg_aout = {5'b0, prg_temp, prg_ain[13:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
  assign chr_aout = {5'b10_000, chr_temp, chr_ain[11:0]};
endmodule

// #105 - NES-EVENT. Retrofits an MMC3 with lots of extra logic.
module NesEvent(input clk, input ce, input reset,
                input [15:0] prg_ain, output reg [21:0] prg_aout,
                input [13:0] chr_ain, output [21:0] chr_aout,
                input [3:0] mmc1_chr,                   // Upper 4 CHR output control bits from MMC chip
                input [21:0] mmc1_aout,                 // PRG output address from MMC chip
                output irq);
  // $A000-BFFF:   [...I OAA.]
  //      I = IRQ control / initialization toggle
  //      O = PRG Mode/Chip select
  //      A = PRG Reg 'A'
  // Mapper gets "initialized" by setting I bit to 0 then to 1.
  // On powerup and reset, the first 32k of PRG (from the first PRG chip) is selected at $8000 *no matter what*.
  // PRG cannot be swapped until the mapper has been "initialized" by setting the 'I' bit to 0, then to '1'.  This
  // toggling will "unlock" PRG swapping on the mapper.
  reg unlocked, old_val;
  reg [29:0] counter;
  
  reg [3:0] oldbits;
  always @(posedge clk) if (reset) begin
    old_val <= 0;
    unlocked <= 0;
    counter <= 0;
  end else if (ce) begin
    // Handle unlock.
    if (mmc1_chr[3] && !old_val) unlocked <= 1;
    old_val <= mmc1_chr[3];
    // The 'I' bit in $A000 controls the IRQ counter.  When cleared, the IRQ counter counts up every cycle.  When
    // set, the IRQ counter is reset to 0 and stays there (does not count), and the pending IRQ is acknowledged.
    counter <= mmc1_chr[3] ? 1'd0 : counter + 1'd1;
    
    if (mmc1_chr != oldbits) begin
      //$write("NESEV Control Bits: %X => %X (%d)\n", oldbits, mmc1_chr, unlocked);
      oldbits <= mmc1_chr;
    end
  end
  // In the official tournament, 'C' was closed, and the others were open, so the counter had to reach $2800000.
  assign irq = (counter[29:25] == 5'b10100);
  always begin
    if (!prg_ain[15]) begin
      // WRAM is always routed as usual.
      prg_aout = mmc1_aout; 
    end else if (!unlocked) begin
      // Not initialized yet, mapper switch disabled.
      prg_aout = {7'b00_0000_0, prg_ain[14:0]}; 
    end else if (mmc1_chr[2] == 0) begin
      // O=0:  Use first PRG chip (first 128k), use 'A' PRG Reg, 32k swap
      prg_aout = {5'b00_000, mmc1_chr[1:0], prg_ain[14:0]};
    end else begin
      // O=1:  Use second PRG chip (second 128k), use 'B' PRG Reg, MMC1 style swap
      prg_aout = mmc1_aout;
    end
  end
  // 8kB CHR RAM.
  assign chr_aout = {9'b10_0000_000, chr_ain[12:0]};
endmodule

// 107 Magicseries Magic Dragon
module Mapper107(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                          // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                             // Allow write
                output vram_a10,                              // Value for A10 address line
                output vram_ce);                              // True if the address should be routed to the internal 2kB VRAM.
  reg [6:0] prg_bank;
  reg [7:0] chr_bank;
  always @(posedge clk) if (reset) begin
    prg_bank <= 0;
    chr_bank <= 0;
  end else if (ce) begin
    if (prg_ain[15] & prg_write) begin
      prg_bank <= prg_din[7:1];
      chr_bank <= prg_din[7:0];
    end
  end
  assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];
  assign prg_aout = {1'b0, prg_bank[5:0], prg_ain[14:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
  assign chr_aout = {2'b10, chr_bank[6:0], chr_ain[12:0]};
  assign vram_ce = chr_ain[13];
endmodule

// mapper 165
module Mapper165(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input chr_read, input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                            // Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce,                              // True if the address should be routed to the internal 2kB VRAM.
            output reg irq);
  reg [2:0] bank_select;             // Register to write to next
  reg prg_rom_bank_mode;             // Mode for PRG banking
  reg chr_a12_invert;                // Mode for CHR banking
  reg mirroring;                     // 0 = vertical, 1 = horizontal
  reg irq_enable, irq_reload;        // IRQ enabled, and IRQ reload requested
  reg [7:0] irq_latch, counter;      // IRQ latch value and current counter
  reg ram_enable, ram_protect;       // RAM protection bits
  reg [5:0] prg_bank_0, prg_bank_1;  // Selected PRG banks
  wire prg_is_ram;

  reg [6:0] chr_bank_0, chr_bank_1;  // Selected CHR banks
  reg [7:0] chr_bank_2, chr_bank_4;
  reg latch_0, latch_1;
  
  wire [7:0] new_counter = (counter == 0 || irq_reload) ? irq_latch : counter - 1'd1;
  reg [3:0] a12_ctr; 
   
  always @(posedge clk) if (reset) begin
    irq <= 0;
    bank_select <= 0;
    prg_rom_bank_mode <= 0;
    chr_a12_invert <= 0;
    mirroring <= flags[14];
    {irq_enable, irq_reload} <= 0;
    {irq_latch, counter} <= 0;
    {ram_enable, ram_protect} <= 0;
    {chr_bank_0, chr_bank_1, chr_bank_2, chr_bank_4} <= 0;
    {prg_bank_0, prg_bank_1} <= 0;
    a12_ctr <= 0;
  end else if (ce) begin
  
    if (prg_write && prg_ain[15]) begin
      case({prg_ain[14], prg_ain[13], prg_ain[0]})
      3'b00_0: {chr_a12_invert, prg_rom_bank_mode, bank_select} <= {prg_din[7], prg_din[6], prg_din[2:0]}; // Bank select ($8000-$9FFE, even)
      3'b00_1: begin // Bank data ($8001-$9FFF, odd)
        case (bank_select) 
        0: chr_bank_0 <= prg_din[7:1];  // Select 2 KB CHR bank at PPU $0000-$07FF (or $1000-$17FF);
        1: chr_bank_1 <= prg_din[7:1];  // Select 2 KB CHR bank at PPU $0800-$0FFF (or $1800-$1FFF);
        2: chr_bank_2 <= prg_din;       // Select 1 KB CHR bank at PPU $1000-$13FF (or $0000-$03FF);
        3: ;                            // Select 1 KB CHR bank at PPU $1400-$17FF (or $0400-$07FF);
        4: chr_bank_4 <= prg_din;       // Select 1 KB CHR bank at PPU $1800-$1BFF (or $0800-$0BFF);
        5: ;                            // Select 1 KB CHR bank at PPU $1C00-$1FFF (or $0C00-$0FFF);
        6: prg_bank_0 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $8000-$9FFF (or $C000-$DFFF);
        7: prg_bank_1 <= prg_din[5:0];  // Select 8 KB PRG ROM bank at $A000-$BFFF
        endcase
      end
      3'b01_0: mirroring <= prg_din[0];                   // Mirroring ($A000-$BFFE, even)
      3'b01_1: {ram_enable, ram_protect} <= prg_din[7:6]; // PRG RAM protect ($A001-$BFFF, odd)
      3'b10_0: irq_latch <= prg_din;                      // IRQ latch ($C000-$DFFE, even)
      3'b10_1: irq_reload <= 1;                           // IRQ reload ($C001-$DFFF, odd)
      3'b11_0: begin irq_enable <= 0; irq <= 0; end       // IRQ disable ($E000-$FFFE, even)
      3'b11_1: irq_enable <= 1;                           // IRQ enable ($E001-$FFFF, odd)
      endcase
    end

    // Trigger IRQ counter on rising edge of chr_ain[12]
    // All MMC3A's and non-Sharp MMC3B's will generate only a single IRQ when $C000 is $00.
    // This is because this version of the MMC3 generates IRQs when the scanline counter is decremented to 0.
    // In addition, writing to $C001 with $C000 still at $00 will result in another single IRQ being generated.
    // In the community, this is known as the "alternate" or "old" behavior.
    // All MMC3C's and Sharp MMC3B's will generate an IRQ on each scanline while $C000 is $00.
    // This is because this version of the MMC3 generates IRQs when the scanline counter is equal to 0.
    // In the community, this is known as the "normal" or "new" behavior.
    if (chr_ain[12] && a12_ctr == 0) begin
      counter <= new_counter;
      if ( (counter != 0 || irq_reload) && new_counter == 0 && irq_enable) begin
//        $write("MMC3 SCANLINE IRQ!\n");
        irq <= 1;
      end
      irq_reload <= 0;      
    end
    a12_ctr <= chr_ain[12] ? 4'b1111 : (a12_ctr != 0) ? a12_ctr - 4'b0001 : a12_ctr;
  end

  // The PRG bank to load. Each increment here is 8kb. So valid values are 0..63.
  reg [5:0] prgsel;
  always @* begin
    casez({prg_ain[14:13], prg_rom_bank_mode})
    3'b00_0: prgsel = prg_bank_0;  // $8000 mode 0
    3'b00_1: prgsel = 6'b111110;   // $8000 fixed to second last bank
    3'b01_?: prgsel = prg_bank_1;  // $A000 mode 0,1
    3'b10_0: prgsel = 6'b111110;   // $C000 fixed to second last bank
    3'b10_1: prgsel = prg_bank_0;  // $C000 mode 1
    3'b11_?: prgsel = 6'b111111;   // $E000 fixed to last bank
    endcase
  end
  wire [21:0] prg_aout_tmp = {3'b00_0,  prgsel, prg_ain[12:0]};

// PPU reads $0FD0: latch 0 is set to $FD for subsequent reads
// PPU reads $0FE0: latch 0 is set to $FE for subsequent reads
// PPU reads $1FD0 through $1FDF: latch 1 is set to $FD for subsequent reads
// PPU reads $1FE0 through $1FEF: latch 1 is set to $FE for subsequent reads
  always @(posedge clk) if (ce && chr_read) begin
    latch_0 <= (chr_ain & 14'h3fff) == 14'h0fd0 ? 1'd0 : (chr_ain & 14'h3fff) == 14'h0fe0 ? 1'd1 : latch_0;
    latch_1 <= (chr_ain & 14'h3ff0) == 14'h1fd0 ? 1'd0 : (chr_ain & 14'h3ff0) == 14'h1fe0 ? 1'd1 : latch_1;
  end

  // The CHR bank to load. Each increment here is 1kb. So valid values are 0..255.
  reg [7:0] chrsel;
  always @* begin
    casez({chr_ain[12] ^ chr_a12_invert, latch_0, latch_1})
    3'b0_0?: chrsel = {chr_bank_0, chr_ain[10]};	// 2Kb page
    3'b0_1?: chrsel = {chr_bank_1, chr_ain[10]};	// 2Kb page
    3'b1_?0: chrsel = chr_bank_2;
    3'b1_?1: chrsel = chr_bank_4;
    endcase
  end
  
  assign {chr_allow, chr_aout} = {flags[15] && (chrsel < 4), 4'b10_00, chrsel, chr_ain[9:0]};

  assign prg_is_ram = prg_ain >= 'h6000 && prg_ain < 'h8000 && ram_enable && !(ram_protect && prg_write);
  assign prg_allow = prg_ain[15] && !prg_write || prg_is_ram;
  wire [21:0] prg_ram = {9'b11_1100_000, prg_ain[12:0]};
  assign prg_aout = prg_is_ram ? prg_ram : prg_aout_tmp;
  assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];  
  assign vram_ce = chr_ain[13];
endmodule

// 218 - Magic Floor
module Mapper218(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                      // Allow write
                output vram_a10,                             // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.

  assign prg_aout = {7'b00_0000_0, prg_ain[14:0]};
  assign chr_allow =1'b1;
  assign chr_aout = {9'b10_0000_000, chr_ain[12:11], vram_a10, chr_ain[9:0]};
  assign vram_ce = 1'b1; //Always internal CHR RAM (no CHR ROM or RAM on cart)
  assign vram_a10 = flags[16] ? (flags[14] ? chr_ain[13] : chr_ain[12]) : flags[14] ? chr_ain[10] : chr_ain[11]; // 11=1ScrB, 10=1ScrA, 01=vertical,00=horizontal
  assign prg_allow = prg_ain[15] && !prg_write;
endmodule

// iNES Mapper 228 represents the board used by Active Enterprises for Action 52 and Cheetahmen II.
module Mapper228(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                          // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                             // Allow write
                output vram_a10,                              // Value for A10 address line
                output vram_ce);                              // True if the address should be routed to the internal 2kB VRAM.
  reg mirroring;
  reg [1:0] prg_chip;
  reg [4:0] prg_bank;
  reg prg_bank_mode;
  reg [5:0] chr_bank;
  always @(posedge clk) if (reset) begin
    {mirroring, prg_chip, prg_bank, prg_bank_mode} <= 0;
    chr_bank <= 0;
  end else if (ce) begin
    if (prg_ain[15] & prg_write) begin
      {mirroring, prg_chip, prg_bank, prg_bank_mode} <= prg_ain[13:5];
      chr_bank <= {prg_ain[3:0], prg_din[1:0]};
    end
  end
  assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];
  wire prglow = prg_bank_mode ? prg_bank[0] : prg_ain[14];
  wire [1:0] addrsel = {prg_chip[1], prg_chip[1] ^ prg_chip[0]};
  assign prg_aout = {1'b0, addrsel, prg_bank[4:1], prglow, prg_ain[13:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
  assign chr_aout = {3'b10_0, chr_bank, chr_ain[12:0]};
  assign vram_ce = chr_ain[13];
endmodule

module Mapper234(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                          // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                             // Allow write
                output vram_a10,                              // Value for A10 address line
                output vram_ce);                              // True if the address should be routed to the internal 2kB VRAM.
  reg [2:0] block, inner_chr;
  reg mode, mirroring, inner_prg;
  always @(posedge clk) if (reset) begin
    block <= 0;
    {mode, mirroring} <= 0;
    inner_chr <= 0;
    inner_prg <= 0;
  end else if (ce) begin
    if (prg_read && prg_ain[15:7] == 9'b1111_1111_1) begin
      // Outer bank control $FF80 - $FF9F
      if (prg_ain[6:0] < 7'h20 && (block == 0)) begin
        {mirroring, mode} <= prg_din[7:6];
        block <= prg_din[3:1];
        {inner_chr[2], inner_prg} <= {prg_din[0], prg_din[0]};
      end
      // Inner bank control ($FFE8-$FFF7)
      if (prg_ain[6:0] >= 7'h68 && prg_ain[6:0] < 7'h78) begin
        {inner_chr[2], inner_prg} <= mode ? {prg_din[6], prg_din[0]} : {inner_chr[2], inner_prg};
        inner_chr[1:0] <= prg_din[5:4];
      end
    end
  end
  assign vram_a10 = mirroring ? chr_ain[11] : chr_ain[10];
  assign prg_aout = {3'b00_0, block, inner_prg, prg_ain[14:0]};
  assign chr_aout = {3'b10_0, block, inner_chr, chr_ain[12:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
  assign vram_ce = chr_ain[13];
endmodule

// VRC1 (75)
module VRC1(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                            // Allow write
                output reg vram_a10,                         // Value for A10 address line
                output vram_ce);                             // True if the address should be routed to the internal 2kB VRAM.
    reg [3:0] prg_bank0, prg_bank1, prg_bank2;
    reg [4:0] chr_bank0, chr_bank1;
	 reg [1:0] mirroring;
	 reg [3:0] prg_tmp;
	 reg [4:0] chr_tmp;
    
    always @(posedge clk) if (reset) begin
      // Set value for mirroring
      mirroring[1:0] <= {flags[16], !flags[14]};
    end else if (ce) begin
      if (prg_ain[15] & prg_write) begin
        case (prg_ain[14:12])
        3'b000:  prg_bank0      <= prg_din[3:0];  // PRG bank 0x8000-0x9FFF
        3'b001:  {chr_bank1[4],chr_bank0[4],mirroring[0]} <= prg_din[2:0];
        3'b010:  prg_bank1      <= prg_din[3:0];  // PRG bank 0xA000-0xBFFF
        3'b100:  prg_bank2      <= prg_din[3:0];  // PRG bank 0xC000-0xEFFF
        3'b110:  chr_bank0[3:0] <= prg_din[3:0];  // CHR bank 0x0000-0x0FFF
        3'b111:  chr_bank1[3:0] <= prg_din[3:0];  // CHR bank 0x1000-0x1FFF
        endcase
      end
    end
    
    always begin
      // mirroring mode
      casez(mirroring[1:0])
      2'b00   :   vram_a10 = {chr_ain[10]};    // vertical
      2'b01   :   vram_a10 = {chr_ain[11]};    // horizontal
      2'b1?   :   vram_a10 = {mirroring[0]};   // 4 screen // Not implemented
      endcase

      // PRG ROM bank size select
      casez(prg_ain[14:13])
		2'b00 : prg_tmp = prg_bank0;
		2'b01 : prg_tmp = prg_bank1;
		2'b10 : prg_tmp = prg_bank2;
		2'b11 : prg_tmp = 4'b1111;
      endcase

      // PRG ROM bank size select
      casez(chr_ain[12])
		1'b0 : chr_tmp = chr_bank0;
		1'b1 : chr_tmp = chr_bank1;
      endcase
    end

  assign vram_ce = chr_ain[13];
  assign prg_aout = {5'b00_000, prg_tmp, prg_ain[12:0]};
  assign prg_allow = prg_ain[15] && !prg_write;
  assign chr_allow = flags[15];
  assign chr_aout = {5'b10_000, chr_tmp, chr_ain[11:0]};
endmodule

// VRC3 (73)
module VRC3(input clk, input ce, input reset,
                input [31:0] flags,
                input [15:0] prg_ain, output [21:0] prg_aout,
                input prg_read, prg_write,                   // Read / write signals
                input [7:0] prg_din,
                output prg_allow,                            // Enable access to memory for the specified operation.
                input [13:0] chr_ain, output [21:0] chr_aout,
                output chr_allow,                            // Allow write
                output vram_a10,                             // Value for A10 address line
                output vram_ce,                              // True if the address should be routed to the internal 2kB VRAM.
					 output reg irq);                             
    reg [2:0] prg_bank;
	 reg [4:0] irq_enable;
	 reg [15:0] irq_latch;
	 reg [15:0] irq_counter;
    
    always @(posedge clk) if (reset) begin
      // Set value for mirroring
		irq <= 0;
		prg_bank <= 0;
		irq_enable <= 0;
    end else if (ce) begin
	   irq_enable[3] <= 1'b0;
      if (prg_ain[15] & prg_write) begin
        case (prg_ain[14:12])
        3'b000:  irq_latch[3:0]   <= prg_din[3:0];
        3'b001:  irq_latch[7:4]   <= prg_din[3:0];
        3'b010:  irq_latch[11:8]  <= prg_din[3:0];
        3'b011:  irq_latch[15:12] <= prg_din[3:0];
        3'b100:  irq_enable[4:0]  <= {2'b11, prg_din[2:0]};
        3'b101:  irq_enable[4:3]  <= 2'b01;
        3'b111:  prg_bank         <= prg_din[2:0];  // PRG bank 0x8000-0xBFFF
        endcase
      end

		if (irq_enable[1]) begin
			irq_counter[7:0] <= irq_counter[7:0] + 8'd1;
			if (irq_counter[7:0] == 8'hFF) begin
				if (irq_enable[2]) begin
					irq <= 1'b1;	// IRQ
				end else begin
					irq_counter[15:8] <= irq_counter[15:8] + 8'd1;
					if (irq_counter[15:8] == 8'hFF) begin
						irq <= 1'b1;	// IRQ
					end
				end
			end
		end
		if (irq_enable[3]) begin
			irq <= 1'b0;	// IRQ ACK
			if (irq_enable[4])
				irq_counter <= irq_latch;
			else
				irq_enable[1] <= irq_enable[0];
		end
    end
    
  assign vram_ce = chr_ain[13];
  assign vram_a10 = flags[14] ? chr_ain[10] : chr_ain[11];
  wire prg_is_ram = (prg_ain[15:13] == 3'b011);//prg_ain >= 'h6000 && prg_ain < 'h8000;
  assign prg_aout = prg_is_ram ? {9'b11_1100_000, prg_ain[12:0]} : {5'b00_000, prg_ain[14] ? 3'b111 : prg_bank, prg_ain[13:0]};
  assign prg_allow = (prg_ain[15] && !prg_write) || prg_is_ram;
  assign chr_allow = flags[15];
  assign chr_aout = {8'b10_0000_00, chr_ain[13:0]};
endmodule

// VRC2 and VRC4
module VRC24(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                            // Allow write
            output reg vram_a10,                         // Value for A10 address line
            output vram_ce,                              // True if the address should be routed to the internal 2kB VRAM.
            output irq);
    reg [4:0] prg_bank0, prg_bank1;
    reg [8:0] chr_bank0, chr_bank1, chr_bank2, chr_bank3, chr_bank4, chr_bank5, chr_bank6, chr_bank7;
	 reg [1:0] mirroring;
	 reg [4:0] prg_tmp;
	 reg [8:0] chr_tmp;
	 reg prg_invert;
	 wire mapper21 = (flags[7:0] == 21);
	 wire mapper22 = (flags[7:0] == 22);
	 wire mapper23 = (flags[7:0] == 23);
	 //wire mapper25 = (flags[7:0] == 25); //default
	 wire mapperVRC4 = (flags[7:0] != 22) && (flags[24:21] != 3);
	 wire [1:0] registers = {mapper21 ?  {(prg_ain[7]|prg_ain[2]),(prg_ain[6]|prg_ain[1])} :
	                         mapper22 ?  {(prg_ain[0]),           (prg_ain[1])           } :
	                         mapper23 ?  {(prg_ain[3]|prg_ain[1]),(prg_ain[2]|prg_ain[0])} :
									 /*mapper25*/{(prg_ain[2]|prg_ain[0]),(prg_ain[3]|prg_ain[1])}};
    
    always @(posedge clk) if (reset) begin
      // Set value for mirroring
      mirroring[1:0] <= {1'b0, !flags[14]};
		prg_invert <= 0;
		prg_bank0 <= 5'd0;
		prg_bank1 <= 5'd1;
		chr_bank0 <= 9'd0;
		chr_bank1 <= 9'd1;
		chr_bank2 <= 9'd2;
		chr_bank3 <= 9'd3;
		chr_bank4 <= 9'd4;
		chr_bank5 <= 9'd5;
		chr_bank6 <= 9'd6;
		chr_bank7 <= 9'd7;
    end else if (ce) begin
      if (prg_ain[15] & prg_write) begin
        casez ({prg_ain[14:12], registers, mapperVRC4})
        6'b000_??_?:  prg_bank0      <= prg_din[4:0];  // PRG bank 0x8000-0x9FFF or 0xC000-0xDFFF
        6'b001_??_0:  mirroring[0]   <= prg_din[0];
        6'b001_0?_1:  mirroring      <= prg_din[1:0];
        6'b001_1?_1:  prg_invert     <= prg_din[1];
        6'b010_??_?:  prg_bank1      <= prg_din[4:0];  // PRG bank 0xA000-0xBFFF
        6'b011_00_?:  chr_bank0[3:0] <= prg_din[3:0];  // CHR bank 0x0000-0x03FF
        6'b011_01_?:  chr_bank0[8:4] <= prg_din[4:0];  // CHR bank 0x0000-0x03FF
        6'b011_10_?:  chr_bank1[3:0] <= prg_din[3:0];  // CHR bank 0x0400-0x07FF
        6'b011_11_?:  chr_bank1[8:4] <= prg_din[4:0];  // CHR bank 0x0400-0x07FF
        6'b100_00_?:  chr_bank2[3:0] <= prg_din[3:0];  // CHR bank 0x0800-0x0BFF
        6'b100_01_?:  chr_bank2[8:4] <= prg_din[4:0];  // CHR bank 0x0800-0x0BFF
        6'b100_10_?:  chr_bank3[3:0] <= prg_din[3:0];  // CHR bank 0x0C00-0x0FFF
        6'b100_11_?:  chr_bank3[8:4] <= prg_din[4:0];  // CHR bank 0x0C00-0x0FFF
        6'b101_00_?:  chr_bank4[3:0] <= prg_din[3:0];  // CHR bank 0x1000-0x13FF
        6'b101_01_?:  chr_bank4[8:4] <= prg_din[4:0];  // CHR bank 0x1000-0x13FF
        6'b101_10_?:  chr_bank5[3:0] <= prg_din[3:0];  // CHR bank 0x1400-0x17FF
        6'b101_11_?:  chr_bank5[8:4] <= prg_din[4:0];  // CHR bank 0x1400-0x17FF
        6'b110_00_?:  chr_bank6[3:0] <= prg_din[3:0];  // CHR bank 0x1800-0x1BFF
        6'b110_01_?:  chr_bank6[8:4] <= prg_din[4:0];  // CHR bank 0x1800-0x1BFF
        6'b110_10_?:  chr_bank7[3:0] <= prg_din[3:0];  // CHR bank 0x1C00-0x1FFF
        6'b110_11_?:  chr_bank7[8:4] <= prg_din[4:0];  // CHR bank 0x1C00-0x1FFF
        //6'b111_??_1:  IRQ Stuff;  // IRQ
        endcase
      end
    end
    
    always begin
      // mirroring mode
      casez(mirroring[1:0])
      2'b00   :   vram_a10 = {chr_ain[10]};    // vertical
      2'b01   :   vram_a10 = {chr_ain[11]};    // horizontal
      2'b1?   :   vram_a10 = {mirroring[0]};   // 1 screen
      endcase

      // PRG ROM bank size select
      casez({prg_ain[14:13],prg_invert})
		3'b00_0 : prg_tmp = prg_bank0;
		3'b00_1 : prg_tmp = 5'b11110;
		3'b01_? : prg_tmp = prg_bank1;
		3'b10_0 : prg_tmp = 5'b11110;
		3'b10_1 : prg_tmp = prg_bank0;
		3'b11_? : prg_tmp = 5'b11111;
      endcase

      // PRG ROM bank size select
      casez(chr_ain[12:10])
		3'b000 : chr_tmp = chr_bank0;
		3'b001 : chr_tmp = chr_bank1;
		3'b010 : chr_tmp = chr_bank2;
		3'b011 : chr_tmp = chr_bank3;
		3'b100 : chr_tmp = chr_bank4;
		3'b101 : chr_tmp = chr_bank5;
		3'b110 : chr_tmp = chr_bank6;
		3'b111 : chr_tmp = chr_bank7;
      endcase
    end

  assign vram_ce = chr_ain[13];
  wire [21:13] prg_aout_tmp = {4'b00_00, prg_tmp};
  wire [21:13] prg_ram = {9'b11_1100_000};
  wire prg_is_ram = (prg_ain[15:13] == 3'b011);//prg_ain >= 'h6000 && prg_ain < 'h8000;
  assign prg_aout[21:13] = prg_is_ram ? prg_ram : prg_aout_tmp;
  assign prg_aout[12:0] = prg_ain[12:0];
  assign prg_allow = (prg_ain[15] && !prg_write) || prg_is_ram;
  assign chr_allow = flags[15];
  assign chr_aout = {3'b10_0, vram_ce ? {5'b00000, chr_ain[13:10]} : mapper22 ? {1'b0, chr_tmp[8:1]} : chr_tmp, chr_ain[9:0]};

  wire irqll = {prg_ain[15:12],registers[1:0]}==6'b1111_00; // 0xF000
  wire irqlh = {prg_ain[15:12],registers[1:0]}==6'b1111_01; // 0xF001
  wire irqc  = {prg_ain[15:12],registers[1:0]}==6'b1111_10; // 0xF002
  wire irqa  = {prg_ain[15:12],registers[1:0]}==6'b1111_11; // 0xF003
  wire irqout;
  assign irq = irqout & mapperVRC4;
  vrcIRQ vrc4irq(clk,reset,prg_write,{irqlh,irqll},irqc,irqa,prg_din,irqout,ce);
endmodule

module VRC6(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din, output [7:0] prg_dout,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                            // Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce,                              // True if the address should be routed to the internal 2kB VRAM.
            output irq,
				output [15:0] audio);
	 wire nesprg_oe;
    wire [7:0] neschrdout;
	 wire neschr_oe;
	 wire wram_oe;
	 wire wram_we;
	 wire prgram_we;
	 wire chrram_oe;
	 wire prgram_oe;
	 wire [18:13] ramprgaout;
	 wire exp6;
	 reg [7:0] m2;
	 wire m2_n = 1;//~ce;  //m2_n not used as clk.  Invert m2 (ce).
  always @(posedge clk) begin
    m2[7:1] <= m2[6:0];
	 m2[0] <= ce;
  end
//module MAPVRC6(              //signal descriptions in powerpak.v
//    input m2, input m2_n, input clk20, input reset, input nesprg_we, output nesprg_oe, input neschr_rd,
//    input neschr_wr, input [15:0] prgain, input [13:0] chrain, input [7:0] nesprgdin, input [7:0] ramprgdin, output reg [7:0] nesprgdout,
//    output [7:0] neschrdout, output neschr_oe, output chrram_we, output chrram_oe, output wram_oe, output wram_we, output prgram_we,
//    output prgram_oe, output [18:10] ramchraout, output [18:13] ramprgaout, output irq, output ciram_ce, output exp6,
//    input cfg_boot, input [18:12] cfg_chrmask, input [18:13] cfg_prgmask, input cfg_vertical, input cfg_fourscreen, input cfg_chrram,
//    input ce, output prg_allow, output [11:0] snd_level, input mapper26);
    MAPVRC6 vrc6(m2[7], m2_n, clk, reset, prg_write, nesprg_oe, 0, 
		1, prg_ain, chr_ain, prg_din, 8'b0, prg_dout,
		neschrdout, neschr_oe, chr_allow, chrram_oe, wram_oe, wram_we, prgram_we,
		prgram_oe, chr_aout[18:10], ramprgaout, irq, vram_ce, exp6, 
		0, 7'b1111111, 6'b111111, flags[14], flags[16], flags[15],
		ce, audio, flags[1]);

    assign chr_aout[21:19] = 3'b100;
    assign chr_aout[9:0] = chr_ain[9:0];
	 assign vram_a10 = chr_aout[10];
	 wire [21:13] prg_aout_tmp = {3'b00_0, ramprgaout};
	 wire [21:13] prg_ram = {9'b11_1100_000};
	 wire prg_is_ram = prg_ain >= 'h6000 && prg_ain < 'h8000;
	 assign prg_aout[21:13] = prg_is_ram ? prg_ram : prg_aout_tmp;
    assign prg_aout[12:0] = prg_ain[12:0];
	 assign prg_allow = (prg_ain[15] && !prg_write) || prg_is_ram;

endmodule

module VRC7(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                            // Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce,                              // True if the address should be routed to the internal 2kB VRAM.
            output irq,
				output [15:0] audio);
				
    assign chr_aout[21:18] = 4'b1000;
    assign chr_aout[9:0] = chr_ain[9:0];
	 assign chr_aout[17:11] = chrbank[17:11];
    assign chr_aout[10]=!chr_ain[13] ? chrbank[10] : ((mirror==0 & chr_ain[10]) | (mirror==1 & chr_ain[11]) | (mirror==3));
    assign vram_ce=chr_ain[13];
	 assign vram_a10=chr_aout[10];
	 assign chr_allow=!chr_ain[13] & flags[15];
	 
	 wire [21:13] prg_aout_tmp = {3'b00_0, prgbankin};
	 wire [21:13] prg_ram = {9'b11_1100_000};
	 wire prg_is_ram = prg_ain >= 'h6000 && prg_ain < 'h8000;
	 assign prg_aout[21:13] = prg_is_ram ? prg_ram : prg_aout_tmp;
    assign prg_aout[12:0] = prg_ain[12:0];
	 assign prg_allow = (prg_ain[15] && !prg_write) || (prg_is_ram && (!prg_write || ramw));

    reg [7:0] chrbank0, chrbank1, chrbank2, chrbank3, chrbank4, chrbank5, chrbank6, chrbank7;
    reg [1:0] mirror;
    reg [5:0] prgbank8;
    reg [5:0] prgbankA;
    reg [5:0] prgbankC;
	 wire prg_ain43 = prg_ain[4] ^ prg_ain[3];
	 reg ramw, soff;

    always@(posedge clk) begin
        if (reset)
		      soff <= 1'b0;
        if(ce && prg_write) begin
            casex({prg_ain[15:12],prg_ain43})
                5'b10000:prgbank8<=prg_din[5:0]; //8000
                5'b10001:prgbankA<=prg_din[5:0]; //8008/10
                5'b10010:prgbankC<=prg_din[5:0]; //9000
                5'b10100:chrbank0<=prg_din;      //A000
                5'b10101:chrbank1<=prg_din;      //A008/10
                5'b10110:chrbank2<=prg_din;      //B000
                5'b10111:chrbank3<=prg_din;      //B008/10
                5'b11000:chrbank4<=prg_din;      //C000
                5'b11001:chrbank5<=prg_din;      //C008/10
                5'b11010:chrbank6<=prg_din;      //D000
                5'b11011:chrbank7<=prg_din;      //D008/10
                5'b11100:{ramw,soff,mirror}<={prg_din[7:6],prg_din[1:0]};   //E000
                //5'b11101:irqlatch<=nesprgdin;      //E008/10
                //5'b11110:{irqM,irqA}<={nesprgdin[2],nesprgdin[0]}; //F000
            endcase
        end
    end

    reg [18:13] prgbankin;
    reg [17:10] chrbank;
    always@* begin
        casex(prg_ain[15:13])
            3'b100:prgbankin=prgbank8;                  //89
            3'b101:prgbankin=prgbankA;                  //AB
            3'b110:prgbankin=prgbankC;                  //CD
            default:prgbankin=6'b111111;                //EF
        endcase
        case(chr_ain[12:10])
            0:chrbank=chrbank0;
            1:chrbank=chrbank1;
            2:chrbank=chrbank2;
            3:chrbank=chrbank3;
            4:chrbank=chrbank4;
            5:chrbank=chrbank5;
            6:chrbank=chrbank6;
            7:chrbank=chrbank7;
        endcase
    end
	 
	 wire irql = {prg_ain[15:12],prg_ain43}==5'b11101; // 0xE008 or 0xE010
	 wire irqc = {prg_ain[15:12],prg_ain43}==5'b11110; // 0xF000
	 wire irqa = {prg_ain[15:12],prg_ain43}==5'b11111; // 0xF008 or 0xF010
	 
	 vrcIRQ vrc7irq(clk,reset,prg_write,{irql,irql},irqc,irqa,prg_din,irq,ce);

	 reg [3:0] ce_count;
    always@(posedge clk) begin
		if (ce)
			ce_count <= 0;
		else
			ce_count <= ce_count + 4'd1;
	 end
	 wire ack;
	 wire ce_ym2143 = ce | (ce_count==4'd5);
	 wire [13:0] ym2143audio;
	 wire wr_audio = prg_write && (prg_ain[15:6]==10'b1001_0000_00) && (prg_ain[4:0]==5'b1_0000); //0x9010 or 0x9030
	 eseopll ym2143vrc7 (clk,reset, ce_ym2143,wr_audio,ce_ym2143,ack,wr_audio,{15'b0,prg_ain[5]},prg_din,ym2143audio);
	 //No clipping. Lower volume.
	 //wire [12:0] ym2143audiounsigned = ym2143audio[12:0] ^ 13'b1_0000_0000_0000; // 10 bits * 6 channels = Max 13 bits.
	 //assign audio[15:0] = soff ? 16'h8000 : {ym2143audiounsigned, 3'b0};
	 //Clipping possible.  Higher volume.
	 wire [11:0] ym2143audiounsigned = ym2143audio[13:12]==3'b10 ? 12'h000 : ym2143audio[13:11]==3'b01 ? 12'hFFF : ym2143audio[11:0] ^ 12'b1000_0000_0000; // Cheat one bit (some clipping)
	 assign audio[15:0] = soff ? 16'h8000 : {ym2143audiounsigned, 4'b0};

endmodule

module N106(input clk, input ce, input reset,
            input [31:0] flags,
            input [15:0] prg_ain, output [21:0] prg_aout,
            input prg_read, prg_write,                   // Read / write signals
            input [7:0] prg_din, output [7:0] prg_dout,
            output prg_allow,                            // Enable access to memory for the specified operation.
            input [13:0] chr_ain, output [21:0] chr_aout,
            output chr_allow,                            // Allow write
            output vram_a10,                             // Value for A10 address line
            output vram_ce,                              // True if the address should be routed to the internal 2kB VRAM.
            output irq,
				output [15:0] audio);
	 wire nesprg_oe;
    wire [7:0] neschrdout;
	 wire neschr_oe;
	 wire wram_oe;
	 wire wram_we;
	 wire prgram_we;
	 wire chrram_oe;
	 wire prgram_oe;
	 wire [18:13] ramprgaout;
	 wire exp6;
	 reg [7:0] m2;
	 wire m2_n = 1;//~ce;  //m2_n not used as clk.  Invert m2 (ce).
  always @(posedge clk) begin
    m2[7:1] <= m2[6:0];
	 m2[0] <= ce;
  end
//module MAPN106(              //signal descriptions in powerpak.v
//    input m2, input m2_n, input clk20, input reset, input nesprg_we, output nesprg_oe, input neschr_rd,
//    input neschr_wr, input [15:0] prgain, input [13:0] chrain, input [7:0] nesprgdin, input [7:0] ramprgdin, output reg [7:0] nesprgdout,
//    output [7:0] neschrdout, output neschr_oe, output chrram_we, output chrram_oe, output wram_oe, output wram_we, output prgram_we,
//    output prgram_oe, output [18:10] ramchraout, output [18:13] ramprgaout, output irq, output ciram_ce, output exp6,
//    input cfg_boot, input [18:12] cfg_chrmask, input [18:13] cfg_prgmask, input cfg_vertical, input cfg_fourscreen, input cfg_chrram,
//    input ce, output prg_allow, output [11:0] snd_level, input mapper26);
    MAPN106 n106(m2[7], m2_n, clk, reset, prg_write, nesprg_oe, 0, 
		1, prg_ain, chr_ain, prg_din, 8'b0, prg_dout,
		neschrdout, neschr_oe, chr_allow, chrram_oe, wram_oe, wram_we, prgram_we,
		prgram_oe, chr_aout[18:10], ramprgaout, irq, vram_ce, exp6, 
		0, 7'b1111111, 6'b111111, flags[14], flags[16], flags[15],
		ce, (flags[7:0]==210), flags[24:21], audio[15:5]);

    assign chr_aout[21:19] = 3'b100;
    assign chr_aout[9:0] = chr_ain[9:0];
	 assign vram_a10 = chr_aout[10];
	 wire [21:13] prg_aout_tmp = {3'b00_0, ramprgaout};
	 wire [21:13] prg_ram = {9'b11_1100_000};
	 wire prg_is_ram = prg_ain >= 'h6000 && prg_ain < 'h8000;
	 assign prg_aout[21:13] = prg_is_ram ? prg_ram : prg_aout_tmp;
    assign prg_aout[12:0] = prg_ain[12:0];
	 assign prg_allow = (prg_ain[15] && !prg_write) || prg_is_ram;
    assign audio[4:0] = 4'b0;

endmodule

//  - Famicom Disk System
module MapperFDS(input clk, input ce, input reset,
                 input [31:0] flags,
                 input [15:0] prg_ain, output [21:0] prg_aout,
                 input prg_read, prg_write,                   // Read / write signals
                 input [7:0] prg_din, output [7:0] prg_dout,
                 output prg_allow,                          // Enable access to memory for the specified operation.
                 input [13:0] chr_ain, output [21:0] chr_aout,
                 output chr_allow,                             // Allow write
                 output vram_a10,                              // Value for A10 address line
                 output vram_ce,                               // True if the address should be routed to the internal 2kB VRAM.
                 output irq,
                 output [15:0] audio,
                 input fds_swap,
                 input [1:0] diskside_manual);
	 wire nesprg_oe;
    wire [7:0] neschrdout;
	 wire neschr_oe;
	 wire wram_oe;
	 wire wram_we;
	 wire prgram_we;
	 wire chrram_oe;
	 wire prgram_oe;
	 wire exp6;
	 reg [7:0] m2;
	 wire m2_n = 1;//~ce;  //m2_n not used as clk.  Invert m2 (ce).
  always @(posedge clk) begin
    m2[7:1] <= m2[6:0];
	 m2[0] <= ce;
  end
	 
//module MAPFDS(              //signal descriptions in powerpak.v
//    input m2, input m2_n, input clk20, input reset, input nesprg_we, output nesprg_oe, input neschr_rd,
//    input neschr_wr, input [15:0] prgain, input [13:0] chrain, input [7:0] nesprgdin, input [7:0] ramprgdin, output reg [7:0] nesprgdout,
//    output [7:0] neschrdout, output neschr_oe, output chrram_we, output chrram_oe, output wram_oe, output wram_we, output prgram_we,
//    output prgram_oe, output [18:10] ramchraout, output [18:13] ramprgaout, output irq, output ciram_ce, output exp6,
//    input cfg_boot, input [18:12] cfg_chrmask, input [18:13] cfg_prgmask, input cfg_vertical, input cfg_fourscreen, input cfg_chrram,
//    input ce, output prg_allow, output [11:0] snd_level);
    MAPFDS fds(m2[7], m2_n, clk, reset, prg_write, nesprg_oe, 0, 
		1, prg_ain, chr_ain, prg_din, 8'b0, prg_dout,
		neschrdout, neschr_oe, chr_allow, chrram_oe, wram_oe, wram_we, prgram_we,
		prgram_oe, chr_aout[18:10], prg_aout[18:0], irq, vram_ce, exp6, 
		0, 7'b1111111, 6'b111111, flags[14], flags[16], flags[15],
		ce, fds_swap, prg_allow, audio[15:4], diskside_manual);
    assign chr_aout[21:19] = 3'b100;
    assign chr_aout[9:0] = chr_ain[9:0];
	 assign vram_a10 = chr_aout[10];
    assign prg_aout[21:19] = 3'b000;
    //assign prg_aout[12:0] = prg_ain[12:0];
    assign audio[3:0] = 4'b0;

endmodule

module MultiMapper(input clk, input ce, input ppu_ce, input reset,
                   input [19:0] ppuflags,                           // Misc flags from PPU for MMC5 cheating
                   input [31:0] flags,                              // Misc flags from ines header {prg_size(3), chr_size(3), mapper(8)}
                   input [15:0] prg_ain, output reg [21:0] prg_aout,// PRG Input / Output Address Lines
                   input prg_read, prg_write,                       // PRG Read / write signals
                   input [7:0] prg_din, output reg [7:0] prg_dout,  // PRG Data
                   input [7:0] prg_from_ram,                        // PRG Data from RAM
                   output reg prg_allow,                            // PRG Allow write access
                   output reg prg_open_bus,                         // PRG Data Not Driven
                   output reg prg_conflict,                         // PRG Data is ROM & prg_din
                   input chr_read,                                  // Read from CHR
                   input chr_write,                                 // Write to CHR
						 input [7:0] chr_din,
                   input [13:0] chr_ain, output reg [21:0] chr_aout,// CHR Input / Output Address Lines
                   output reg [7:0] chr_dout,                       // Value to override CHR data with
                   output reg has_chr_dout,                         // True if CHR data should be overridden
                   output reg chr_allow,                            // CHR Allow write
                   output reg vram_a10,                             // CHR Value for A10 address line
                   output reg vram_ce,                              // CHR True if the address should be routed to the internal 2kB VRAM.
                   output reg [14:0] mapper_addr,
                   input [7:0] mapper_data_in,
                   output reg [7:0] mapper_data_out,
                   output reg mapper_prg_write, output reg mapper_ovr,
                   output reg irq,
                   output reg [15:0] audio,                         // External Audio
						 input fds_swap,
						 input [1:0] diskside_manual);                                 // FDS Disk Swap Pause
  wire mmc0_prg_allow, mmc0_vram_a10, mmc0_vram_ce, mmc0_chr_allow;
  wire [21:0] mmc0_prg_addr, mmc0_chr_addr;
  MMC0 mmc0(clk, ce, flags, prg_ain, mmc0_prg_addr, prg_read, prg_write, prg_din, mmc0_prg_allow,
                            chr_ain, mmc0_chr_addr, mmc0_chr_allow, mmc0_vram_a10, mmc0_vram_ce);

  wire mmc1_prg_allow, mmc1_vram_a10, mmc1_vram_ce, mmc1_chr_allow;
  wire [21:0] mmc1_prg_addr, mmc1_chr_addr;
  MMC1 mmc1(clk, ce, reset, flags, prg_ain, mmc1_prg_addr, prg_read, prg_write, prg_din, mmc1_prg_allow,
                                   chr_ain, mmc1_chr_addr, mmc1_chr_allow, mmc1_vram_a10, mmc1_vram_ce);

  wire map28_prg_allow, map28_open_bus, map28_conflict, map28_vram_a10, map28_vram_ce, map28_chr_allow;
  wire [21:0] map28_prg_addr, map28_chr_addr;
  wire [7:0]  map28_chr_dout;
  wire  map28_has_chr_dout;
  Mapper28 map28(clk, ce, reset, flags, prg_ain, map28_prg_addr, prg_read, prg_write, prg_din, map28_prg_allow, map28_open_bus, map28_conflict,
                                        chr_ain, map28_chr_addr, map28_chr_dout, map28_has_chr_dout, map28_chr_allow,
													 map28_vram_a10, map28_vram_ce);

  wire map30_prg_allow, map30_vram_a10, map30_vram_ce, map30_chr_allow;
  wire [21:0] map30_prg_addr, map30_chr_addr;
  Mapper30 map30(clk, ce, reset, flags, prg_ain, map30_prg_addr, prg_read, prg_write, prg_din, map30_prg_allow,
                                        chr_ain, map30_chr_addr, map30_chr_allow, map30_vram_a10, map30_vram_ce);

  wire map32_prg_allow, map32_vram_a10, map32_vram_ce, map32_chr_allow;
  wire [21:0] map32_prg_addr, map32_chr_addr;
  Mapper32 map32(clk, ce, reset, flags, prg_ain, map32_prg_addr, prg_read, prg_write, prg_din, map32_prg_allow,
                                        chr_ain, map32_chr_addr, map32_chr_allow, map32_vram_a10, map32_vram_ce);

  wire mmc2_prg_allow, mmc2_vram_a10, mmc2_vram_ce, mmc2_chr_allow;
  wire [21:0] mmc2_prg_addr, mmc2_chr_addr;
  MMC2 mmc2(clk, ppu_ce, reset, flags, prg_ain, mmc2_prg_addr, prg_read, prg_write, prg_din, mmc2_prg_allow,
                                   chr_read, chr_ain, mmc2_chr_addr, mmc2_chr_allow, mmc2_vram_a10, mmc2_vram_ce);

  wire mmc3_prg_allow, mmc3_vram_a10, mmc3_vram_ce, mmc3_chr_allow, mmc3_irq;
  wire [21:0] mmc3_prg_addr, mmc3_chr_addr;
  MMC3 mmc3(clk, ppu_ce, reset, flags, prg_ain, mmc3_prg_addr, prg_read, prg_write, prg_din, mmc3_prg_allow,
                                   chr_ain, mmc3_chr_addr, mmc3_chr_allow, mmc3_vram_a10, mmc3_vram_ce, mmc3_irq);

  wire mmc4_prg_allow, mmc4_vram_a10, mmc4_vram_ce, mmc4_chr_allow;
  wire [21:0] mmc4_prg_addr, mmc4_chr_addr;
  MMC4 mmc4(clk, ppu_ce, reset, flags, prg_ain, mmc4_prg_addr, prg_read, prg_write, prg_din, mmc4_prg_allow,
                                   chr_read, chr_ain, mmc4_chr_addr, mmc4_chr_allow, mmc4_vram_a10, mmc4_vram_ce);

  wire mmc5_prg_allow, mmc5_vram_a10, mmc5_vram_ce, mmc5_chr_allow, mmc5_irq;
  wire [21:0] mmc5_prg_addr, mmc5_chr_addr;
  wire [7:0] mmc5_chr_dout, mmc5_prg_dout;
  wire mmc5_has_chr_dout;
  wire [15:0] mmc5_audio;
  MMC5 mmc5(clk, ce, ppu_ce, reset, flags, ppuflags, prg_ain, mmc5_prg_addr, prg_read, prg_write, prg_din, mmc5_prg_dout, mmc5_prg_allow,
                                   chr_read, chr_write, chr_din, chr_ain, mmc5_chr_addr, mmc5_chr_dout, mmc5_has_chr_dout, 
                                   mmc5_chr_allow, mmc5_vram_a10, mmc5_vram_ce, mmc5_irq, mmc5_audio);

  wire map13_prg_allow, map13_vram_a10, map13_vram_ce, map13_chr_allow;
  wire [21:0] map13_prg_addr, map13_chr_addr;
  Mapper13 map13(clk, ce, reset, flags, prg_ain, map13_prg_addr, prg_read, prg_write, prg_din, map13_prg_allow,
                                        chr_ain, map13_chr_addr, map13_chr_allow, map13_vram_a10, map13_vram_ce);

  wire map15_prg_allow, map15_vram_a10, map15_vram_ce, map15_chr_allow;
  wire [21:0] map15_prg_addr, map15_chr_addr;
  Mapper15 map15(clk, ce, reset, flags, prg_ain, map15_prg_addr, prg_read, prg_write, prg_din, map15_prg_allow,
                                        chr_ain, map15_chr_addr, map15_chr_allow, map15_vram_a10, map15_vram_ce);

  wire map16_prg_allow, map16_vram_a10, map16_vram_ce, map16_chr_allow, map16_irq, map16_prg_write, map16_ovr;
  wire [21:0] map16_prg_addr, map16_chr_addr;
  wire [7:0] map16_prg_dout, map16_data_out;
  wire [14:0] map16_mapper_addr;
  Mapper16 map16(clk, ce, reset, flags, prg_ain, map16_prg_addr, prg_read, prg_write, prg_din, map16_prg_dout, map16_prg_allow,
                                        chr_ain, map16_chr_addr, map16_chr_allow, map16_vram_a10, map16_vram_ce, 
													 map16_mapper_addr, mapper_data_in, map16_data_out, map16_prg_write, map16_ovr,
													 map16_irq);

  wire map18_prg_allow, map18_vram_a10, map18_vram_ce, map18_chr_allow, map18_irq;
  wire [21:0] map18_prg_addr, map18_chr_addr;
  wire [7:0] map18_prg_dout;
  Mapper18 map18(clk, ce, reset, flags, prg_ain, map18_prg_addr, prg_read, prg_write, prg_din, map18_prg_dout, map18_prg_allow,
                                        chr_ain, map18_chr_addr, map18_chr_allow, map18_vram_a10, map18_vram_ce, map18_irq);

  wire map34_prg_allow, map34_vram_a10, map34_vram_ce, map34_chr_allow;
  wire [21:0] map34_prg_addr, map34_chr_addr;
  Mapper34 map34(clk, ce, reset, flags, prg_ain, map34_prg_addr, prg_read, prg_write, prg_din, map34_prg_allow,
                                        chr_ain, map34_chr_addr, map34_chr_allow, map34_vram_a10, map34_vram_ce);

  wire map41_prg_allow, map41_vram_a10, map41_vram_ce, map41_chr_allow;
  wire [21:0] map41_prg_addr, map41_chr_addr;
  Mapper41 map41(clk, ce, reset, flags, prg_ain, map41_prg_addr, prg_read, prg_write, prg_din, map41_prg_allow,
                                        chr_ain, map41_chr_addr, map41_chr_allow, map41_vram_a10, map41_vram_ce);

  wire map42_prg_allow, map42_vram_a10, map42_vram_ce, map42_chr_allow, map42_irq;
  wire [21:0] map42_prg_addr, map42_chr_addr;
  Mapper42 map42(clk, ce, reset, flags, prg_ain, map42_prg_addr, prg_read, prg_write, prg_din, map42_prg_allow,
                                        chr_ain, map42_chr_addr, map42_chr_allow, map42_vram_a10, map42_vram_ce, map42_irq);

  wire map65_prg_allow, map65_vram_a10, map65_vram_ce, map65_chr_allow, map65_irq;
  wire [21:0] map65_prg_addr, map65_chr_addr;
  Mapper65 map65(clk, ce, reset, flags, prg_ain, map65_prg_addr, prg_read, prg_write, prg_din, map65_prg_allow,
                                        chr_ain, map65_chr_addr, map65_chr_allow, map65_vram_a10, map65_vram_ce, map65_irq);

  wire map66_prg_allow, map66_vram_a10, map66_vram_ce, map66_chr_allow;
  wire [21:0] map66_prg_addr, map66_chr_addr;
  Mapper66 map66(clk, ce, reset, flags, prg_ain, map66_prg_addr, prg_read, prg_write, prg_din, map66_prg_allow,
                                        chr_ain, map66_chr_addr, map66_chr_allow, map66_vram_a10, map66_vram_ce);

  wire map67_prg_allow, map67_vram_a10, map67_vram_ce, map67_chr_allow, map67_irq;
  wire [21:0] map67_prg_addr, map67_chr_addr;
  Mapper67 map67(clk, ce, reset, flags, prg_ain, map67_prg_addr, prg_read, prg_write, prg_din, map67_prg_allow,
                                        chr_ain, map67_chr_addr, map67_chr_allow, map67_vram_a10, map67_vram_ce, map67_irq);

  wire map68_prg_allow, map68_vram_a10, map68_vram_ce, map68_chr_allow;
  wire [21:0] map68_prg_addr, map68_chr_addr;
  Mapper68 map68(clk, ce, reset, flags, prg_ain, map68_prg_addr, prg_read, prg_write, prg_din, map68_prg_allow,
                                        chr_ain, map68_chr_addr, map68_chr_allow, map68_vram_a10, map68_vram_ce);

  wire map69_prg_allow, map69_vram_a10, map69_vram_ce, map69_chr_allow, map69_irq;
  wire [21:0] map69_prg_addr, map69_chr_addr;
  wire [15:0] map69_audio;
  Mapper69 map69(clk, ce, reset, flags, prg_ain, map69_prg_addr, prg_read, prg_write, prg_din, map69_prg_allow,
                                        chr_ain, map69_chr_addr, map69_chr_allow, map69_vram_a10, map69_vram_ce, map69_irq, map69_audio);

  wire map71_prg_allow, map71_vram_a10, map71_vram_ce, map71_chr_allow;
  wire [21:0] map71_prg_addr, map71_chr_addr;
  Mapper71 map71(clk, ce, reset, flags, prg_ain, map71_prg_addr, prg_read, prg_write, prg_din, map71_prg_allow,
                                        chr_ain, map71_chr_addr, map71_chr_allow, map71_vram_a10, map71_vram_ce);

  wire map72_prg_allow, map72_vram_a10, map72_vram_ce, map72_chr_allow;
  wire [21:0] map72_prg_addr, map72_chr_addr;
  Mapper72 map72(clk, ce, reset, flags, prg_ain, map72_prg_addr, prg_read, prg_write, prg_din, map72_prg_allow,
                                        chr_ain, map72_chr_addr, map72_chr_allow, map72_vram_a10, map72_vram_ce);

  wire map77_prg_allow, map77_vram_a10, map77_vram_ce, map77_chr_allow;
  wire [21:0] map77_prg_addr, map77_chr_addr;
  Mapper77 map77(clk, ce, reset, flags, prg_ain, map77_prg_addr, prg_read, prg_write, prg_din, map77_prg_allow,
                                        chr_ain, map77_chr_addr, map77_chr_allow, map77_vram_a10, map77_vram_ce);

  wire map78_prg_allow, map78_vram_a10, map78_vram_ce, map78_chr_allow;
  wire [21:0] map78_prg_addr, map78_chr_addr;
  Mapper78 map78(clk, ce, reset, flags, prg_ain, map78_prg_addr, prg_read, prg_write, prg_din, map78_prg_allow,
                                        chr_ain, map78_chr_addr, map78_chr_allow, map78_vram_a10, map78_vram_ce);

  wire map79_prg_allow, map79_vram_a10, map79_vram_ce, map79_chr_allow;
  wire [21:0] map79_prg_addr, map79_chr_addr;
  Mapper79 map79(clk, ce, reset, flags, prg_ain, map79_prg_addr, prg_read, prg_write, prg_din, map79_prg_allow,
                                        chr_ain, map79_chr_addr, map79_chr_allow, map79_vram_a10, map79_vram_ce);

  wire map89_prg_allow, map89_vram_a10, map89_vram_ce, map89_chr_allow;
  wire [21:0] map89_prg_addr, map89_chr_addr;
  Mapper89 map89(clk, ce, reset, flags, prg_ain, map89_prg_addr, prg_read, prg_write, prg_din, map89_prg_allow,
                                        chr_ain, map89_chr_addr, map89_chr_allow, map89_vram_a10, map89_vram_ce);

  wire map107_prg_allow, map107_vram_a10, map107_vram_ce, map107_chr_allow;
  wire [21:0] map107_prg_addr, map107_chr_addr;
  Mapper107 map107(clk, ce, reset, flags, prg_ain, map107_prg_addr, prg_read, prg_write, prg_din, map107_prg_allow,
                                        chr_ain, map107_chr_addr, map107_chr_allow, map107_vram_a10, map107_vram_ce);

  wire map165_prg_allow, map165_vram_a10, map165_vram_ce, map165_chr_allow, map165_irq;
  wire [21:0] map165_prg_addr, map165_chr_addr;
  Mapper165 map165(clk, ppu_ce, reset, flags, prg_ain, map165_prg_addr, prg_read, prg_write, prg_din, map165_prg_allow,
													 chr_read, chr_ain, map165_chr_addr, map165_chr_allow, map165_vram_a10, map165_vram_ce, map165_irq);

  wire map218_prg_allow, map218_vram_a10, map218_vram_ce, map218_chr_allow;
  wire [21:0] map218_prg_addr, map218_chr_addr;
  Mapper218 map218(clk, ce, reset, flags, prg_ain, map218_prg_addr, prg_read, prg_write, prg_din, map218_prg_allow,
                                        chr_ain, map218_chr_addr, map218_chr_allow, map218_vram_a10, map218_vram_ce);

  wire map228_prg_allow, map228_vram_a10, map228_vram_ce, map228_chr_allow;
  wire [21:0] map228_prg_addr, map228_chr_addr;
  Mapper228 map228(clk, ce, reset, flags, prg_ain, map228_prg_addr, prg_read, prg_write, prg_din, map228_prg_allow,
                                          chr_ain, map228_chr_addr, map228_chr_allow, map228_vram_a10, map228_vram_ce);


  wire map234_prg_allow, map234_vram_a10, map234_vram_ce, map234_chr_allow;
  wire [21:0] map234_prg_addr, map234_chr_addr;
  Mapper234 map234(clk, ce, reset, flags, prg_ain, map234_prg_addr, prg_read, prg_write, prg_from_ram, map234_prg_allow,
                                          chr_ain, map234_chr_addr, map234_chr_allow, map234_vram_a10, map234_vram_ce);

  wire rambo1_prg_allow, rambo1_vram_a10, rambo1_vram_ce, rambo1_chr_allow, rambo1_irq;
  wire [21:0] rambo1_prg_addr, rambo1_chr_addr;
  Rambo1 rambo1(clk, ce, reset, flags, prg_ain, rambo1_prg_addr, prg_read, prg_write, prg_din, rambo1_prg_allow,
                                   chr_ain, rambo1_chr_addr, rambo1_chr_allow, rambo1_vram_a10, rambo1_vram_ce, rambo1_irq);

  wire [21:0] nesev_prg_addr, nesev_chr_addr;
  wire nesev_irq;
  NesEvent nesev(clk, ce, reset, prg_ain, nesev_prg_addr, chr_ain, nesev_chr_addr, mmc1_chr_addr[16:13], mmc1_prg_addr, nesev_irq);

  wire vrc1_prg_allow, vrc1_vram_a10, vrc1_vram_ce, vrc1_chr_allow;
  wire [21:0] vrc1_prg_addr, vrc1_chr_addr;
  VRC1 vrc1(clk, ce, reset, flags, prg_ain, vrc1_prg_addr, prg_read, prg_write, prg_din, vrc1_prg_allow,
                                        chr_ain, vrc1_chr_addr, vrc1_chr_allow, vrc1_vram_a10, vrc1_vram_ce);

  wire vrc3_prg_allow, vrc3_vram_a10, vrc3_vram_ce, vrc3_chr_allow, vrc3_irq;
  wire [21:0] vrc3_prg_addr, vrc3_chr_addr;
  VRC3 vrc3(clk, ce, reset, flags, prg_ain, vrc3_prg_addr, prg_read, prg_write, prg_din, vrc3_prg_allow,
                                        chr_ain, vrc3_chr_addr, vrc3_chr_allow, vrc3_vram_a10, vrc3_vram_ce, vrc3_irq);
  
  wire vrc24_prg_allow, vrc24_vram_a10, vrc24_vram_ce, vrc24_chr_allow, vrc24_irq;
  wire [21:0] vrc24_prg_addr, vrc24_chr_addr;
  VRC24 vrc24(clk, ce, reset, flags, prg_ain, vrc24_prg_addr, prg_read, prg_write, prg_din, vrc24_prg_allow,
                                   chr_ain, vrc24_chr_addr, vrc24_chr_allow, vrc24_vram_a10, vrc24_vram_ce, vrc24_irq);
  
  wire vrc6_prg_allow, vrc6_vram_a10, vrc6_vram_ce, vrc6_chr_allow, vrc6_irq;
  wire [21:0] vrc6_prg_addr, vrc6_chr_addr;
  wire [15:0] vrc6_audio;
  wire [7:0] vrc6_prg_dout;
  VRC6 vrc6(clk, ce, reset, flags, prg_ain, vrc6_prg_addr, prg_read, prg_write, prg_din, vrc6_prg_dout, vrc6_prg_allow,
                                   chr_ain, vrc6_chr_addr, vrc6_chr_allow, vrc6_vram_a10, vrc6_vram_ce, vrc6_irq, vrc6_audio);
  
  wire vrc7_prg_allow, vrc7_vram_a10, vrc7_vram_ce, vrc7_chr_allow, vrc7_irq;
  wire [21:0] vrc7_prg_addr, vrc7_chr_addr;
  wire [15:0] vrc7_audio;
  VRC7 vrc7(clk, ce, reset, flags, prg_ain, vrc7_prg_addr, prg_read, prg_write, prg_din, vrc7_prg_allow,
                                   chr_ain, vrc7_chr_addr, vrc7_chr_allow, vrc7_vram_a10, vrc7_vram_ce, vrc7_irq, vrc7_audio);
  
  wire map19_prg_allow, map19_vram_a10, map19_vram_ce, map19_chr_allow, map19_irq;
  wire [21:0] map19_prg_addr, map19_chr_addr;
  wire [15:0] map19_audio;
  wire [7:0] map19_prg_dout;
  N106 n106(clk, ce, reset, flags, prg_ain, map19_prg_addr, prg_read, prg_write, prg_din, map19_prg_dout, map19_prg_allow,
                                   chr_ain, map19_chr_addr, map19_chr_allow, map19_vram_a10, map19_vram_ce, map19_irq, map19_audio);

  wire mapfds_prg_allow, mapfds_vram_a10, mapfds_vram_ce, mapfds_chr_allow, mapfds_irq;
  wire [21:0] mapfds_prg_addr, mapfds_chr_addr;
  wire [15:0] mapfds_audio;
  wire [7:0] mapfds_chr_dout, mapfds_prg_dout;
  MapperFDS mapfds(clk, ce, reset, flags, prg_ain, mapfds_prg_addr, prg_read, prg_write, prg_din, mapfds_prg_dout, mapfds_prg_allow,
                                        chr_ain, mapfds_chr_addr, mapfds_chr_allow, mapfds_vram_a10, mapfds_vram_ce, mapfds_irq,
													 mapfds_audio, fds_swap, diskside_manual);

  // Mask 
  reg [5:0] prg_mask;
  reg [6:0] chr_mask;

  always @* begin
    case(flags[10:8])
    0: prg_mask = 6'b000000;
    1: prg_mask = 6'b000001;
    2: prg_mask = 6'b000011;
    3: prg_mask = 6'b000111;
    4: prg_mask = 6'b001111;
    5: prg_mask = 6'b011111;
    default: prg_mask = 6'b111111;
    endcase

    case(flags[13:11])
    0: chr_mask = 7'b0000000;
    1: chr_mask = 7'b0000001;
    2: chr_mask = 7'b0000011;
    3: chr_mask = 7'b0000111;
    4: chr_mask = 7'b0001111;
    5: chr_mask = 7'b0011111;
    6: chr_mask = 7'b0111111;
    7: chr_mask = 7'b1111111;
    endcase
    
    irq = 0;
    prg_dout = 8'hff;
    has_chr_dout = 0;
    chr_dout = mmc5_chr_dout;
	 audio = 16'h0000;
	 mapper_addr = 14'h0000;
	 mapper_data_out = 8'h00;
	 mapper_prg_write = 1'b0;
	 mapper_ovr = 1'b0;
	 prg_open_bus = map28_open_bus; // Expand to other mappers?
	 prg_conflict = map28_conflict; // Expand to other mappers?
// 0 = Working
// 1 = Working
// 2 = Working
// 3 = Working
// 4 = Working
// 5 = Working/Audio needs testing/Some games graphics corruption (Just Breed)
// 7 = Working
// 9 = Working
// 10 = Working
// 11 = Working
// 13 = Working
// 15 = Working
// 16 = Working/EEPROM needs testing
// 18 = Needs testing
// 19 = Needs testing
// 20 = Needs testing
// 21 = Needs testing
// 22 = Needs testing
// 23 = Needs testing
// 24 = Needs testing
// 25 = Needs testing
// 26 = Needs testing
// 28 = Working
// 30 = No Self Flashing/Needs testing
// 32 = Needs testing
// 33 = Needs testing
// 34 = Working
// 37 = Needs testing
// 38 = Needs testing
// 41 = Working
// 42 = Working
// 47 = Working
// 48 = Needs testing
// 64 = Tons of GFX bugs
// 65 = Needs testing
// 66 = Working
// 67 = Needs testing
// 68 = Working
// 69 = Working
// 70 = Needs testing
// 71 = Working
// 72 = Needs testing/No Audio Samples
// 73 = Needs testing
// 74 = Needs testing
// 75 = Needs testing
// 76 = Needs testing
// 77 = Needs testing
// 78 = Submapper 1 Requires NES 2.0/Needs testing overall
// 79 = Working
// 80 = Needs testing
// 82 = Needs testing
// 85 = Needs testing/Audio needs testing
// 86 = Needs testing/No Audio Samples
// 87 = Needs testing
// 88 = Needs testing
// 89 = Needs testing
// 92 = Needs testing/No Audio Samples
// 93 = Needs testing
// 94 = Needs testing
// 95 = Needs testing
// 97 = Needs testing
// 101 = Needs testing
// 105 = Working
// 107 = Needs testing
// 112 = Needs testing
// 113 = Working
// 118 = Working
// 119 = Working
// 140 = Needs testing
// 152 = Needs testing
// 154 = Needs testing
// 155 = Needs testing
// 158 = Tons of GFX bugs
// 159 = Needs testing
// 165 = GFX corrupted
// 180 = Needs testing
// 184 = Needs testing
// 185 = Needs testing
// 190 = Not Tested
// 191 = Not Tested
// 192 = Not Tested
// 194 = Not Tested
// 195 = Not Tested
// 206 = Not Tested
// 207 = Needs testing
// 210 = Needs testing
// 218 = Working
// 228 = Working
// 234 = Not Tested        
    case(flags[7:0])
    155,
    1:  {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {mmc1_prg_addr, mmc1_prg_allow, mmc1_chr_addr, mmc1_vram_a10, mmc1_vram_ce, mmc1_chr_allow};
    9:  {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {mmc2_prg_addr, mmc2_prg_allow, mmc2_chr_addr, mmc2_vram_a10, mmc2_vram_ce, mmc2_chr_allow};
    118, // TxSROM connects A17 to CIRAM A10.
    119, // TQROM  uses the Nintendo MMC3 like other TxROM boards but uses the CHR bank number specially.
    47,  // Mapper 047 is a MMC3 multicart
    206, // MMC3 w/o IRQ or WRAM support
    112, // Like 206 with different layout
    88,  // NAMCOT-3433 is mapper 206-like, but connects PPU-A12 to CHROM A16.
    154, // NAMCOT-3453 is mapper 88-like, but with one screen mirroring.
    95,  // NAMCOT-3425 is mapper 206-like, but connects A16 to CIRAM A10.
    76,  // NAMCOT-3446 is mapper 206-like, but coarser chr banking.
    80,  // Taito X01-005 is MMC3-like with Internal RAM and no IRQ
    82,  // Tatio X01-017 is mapper 80-like with more Internal RAM
    207, // Tatio X01-005 is mapper 80-like with one screen mirroring
    48,  // MMC3-like with delayed IRQ
    33,  // Mapper 48 without IRQ and different mirroring location
    37,  // European Triple Cart (Super Mario, Tetris, Nintendo World Cup)
    74,  // MMC3 like but uses the CHR RAM.
    191, // MMC3 like but uses the CHR RAM.
    192, // MMC3 like but uses the CHR RAM.
    194, // MMC3 like but uses the CHR RAM.
    195, // MMC3 like but uses the CHR RAM.
    4:  {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {mmc3_prg_addr, mmc3_prg_allow, mmc3_chr_addr, mmc3_vram_a10, mmc3_vram_ce, mmc3_chr_allow, mmc3_irq};

    10: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {mmc4_prg_addr, mmc4_prg_allow, mmc4_chr_addr, mmc4_vram_a10, mmc4_vram_ce, mmc4_chr_allow};
	 
    5:  {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, has_chr_dout, prg_dout, irq, audio} = {mmc5_prg_addr, mmc5_prg_allow, mmc5_chr_addr, mmc5_vram_a10, mmc5_vram_ce, mmc5_chr_allow, mmc5_has_chr_dout, mmc5_prg_dout, mmc5_irq, mmc5_audio};

    0,
    2,
    3,
    7,
    94,
    97,
    180,
    185,
    28: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, chr_dout, has_chr_dout}      = {map28_prg_addr, map28_prg_allow, map28_chr_addr, map28_vram_a10, map28_vram_ce, map28_chr_allow, map28_chr_dout, map28_has_chr_dout};

    89,
    93,
    184: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map89_prg_addr, map89_prg_allow, map89_chr_addr, map89_vram_a10, map89_vram_ce, map89_chr_allow};

    30: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map30_prg_addr, map30_prg_allow, map30_chr_addr, map30_vram_a10, map30_vram_ce, map30_chr_allow};

    32: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map32_prg_addr, map32_prg_allow, map32_chr_addr, map32_vram_a10, map32_vram_ce, map32_chr_allow};

    13: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map13_prg_addr, map13_prg_allow, map13_chr_addr, map13_vram_a10, map13_vram_ce, map13_chr_allow};
    15: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map15_prg_addr, map15_prg_allow, map15_chr_addr, map15_vram_a10, map15_vram_ce, map15_chr_allow};

    159,
	 16: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, prg_dout, mapper_addr, mapper_data_out, mapper_prg_write, mapper_ovr, irq}
	   = {map16_prg_addr, map16_prg_allow, map16_chr_addr, map16_vram_a10, map16_vram_ce, map16_chr_allow, map16_prg_dout, map16_mapper_addr, map16_data_out, map16_prg_write, map16_ovr, map16_irq};
    
	 18: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, prg_dout, irq} = {map18_prg_addr, map18_prg_allow, map18_chr_addr, map18_vram_a10, map18_vram_ce, map18_chr_allow, map18_prg_dout, map18_irq};
    
	 34: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map34_prg_addr, map34_prg_allow, map34_chr_addr, map34_vram_a10, map34_vram_ce, map34_chr_allow};
    41: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map41_prg_addr, map41_prg_allow, map41_chr_addr, map41_vram_a10, map41_vram_ce, map41_chr_allow};

    64,
    158: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {rambo1_prg_addr, rambo1_prg_allow, rambo1_chr_addr, rambo1_vram_a10, rambo1_vram_ce, rambo1_chr_allow, rambo1_irq};

	 42: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {map42_prg_addr, map42_prg_allow, map42_chr_addr, map42_vram_a10, map42_vram_ce, map42_chr_allow, map42_irq};

	 65: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {map65_prg_addr, map65_prg_allow, map65_chr_addr, map65_vram_a10, map65_vram_ce, map65_chr_allow, map65_irq};
    190,
	 67: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {map67_prg_addr, map67_prg_allow, map67_chr_addr, map67_vram_a10, map67_vram_ce, map67_chr_allow, map67_irq};

    11,
    38,
    86,
    87,
    101,
    140,
    66: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map66_prg_addr, map66_prg_allow, map66_chr_addr, map66_vram_a10, map66_vram_ce, map66_chr_allow};
    68: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map68_prg_addr, map68_prg_allow, map68_chr_addr, map68_vram_a10, map68_vram_ce, map68_chr_allow};
    69: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq, audio} = {map69_prg_addr, map69_prg_allow, map69_chr_addr, map69_vram_a10, map69_vram_ce, map69_chr_allow, map69_irq, map69_audio};

    71,
    232: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}     = {map71_prg_addr, map71_prg_allow, map71_chr_addr, map71_vram_a10, map71_vram_ce, map71_chr_allow};

	 92,
    72: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map72_prg_addr, map72_prg_allow, map72_chr_addr, map72_vram_a10, map72_vram_ce, map72_chr_allow};

    77: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map77_prg_addr, map77_prg_allow, map77_chr_addr, map77_vram_a10, map77_vram_ce, map77_chr_allow};

    152,
    70,
    78: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}     = {map78_prg_addr, map78_prg_allow, map78_chr_addr, map78_vram_a10, map78_vram_ce, map78_chr_allow};

    79,
    113: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}     = {map79_prg_addr, map79_prg_allow, map79_chr_addr, map79_vram_a10, map79_vram_ce, map79_chr_allow};

    105: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq}= {nesev_prg_addr, mmc1_prg_allow, nesev_chr_addr, mmc1_vram_a10, mmc1_vram_ce, mmc1_chr_allow, nesev_irq};

    107: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map107_prg_addr, map107_prg_allow, map107_chr_addr, map107_vram_a10, map107_vram_ce, map107_chr_allow};

    165: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {map165_prg_addr, map165_prg_allow, map165_chr_addr, map165_vram_a10, map165_vram_ce, map165_chr_allow, map165_irq};

	 218: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {map218_prg_addr, map218_prg_allow, map218_chr_addr, map218_vram_a10, map218_vram_ce, map218_chr_allow};

    228: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}     = {map228_prg_addr, map228_prg_allow, map228_chr_addr, map228_vram_a10, map228_vram_ce, map228_chr_allow};
    234: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}     = {map234_prg_addr, map234_prg_allow, map234_chr_addr, map234_vram_a10, map234_vram_ce, map234_chr_allow};
    75: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow}      = {vrc1_prg_addr, vrc1_prg_allow, vrc1_chr_addr, vrc1_vram_a10, vrc1_vram_ce, vrc1_chr_allow};
    20: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, prg_dout, irq, audio} = {mapfds_prg_addr, mapfds_prg_allow, mapfds_chr_addr, mapfds_vram_a10, mapfds_vram_ce, mapfds_chr_allow, mapfds_prg_dout, mapfds_irq, mapfds_audio};
    21,
    22,
    23,
    25: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {vrc24_prg_addr, vrc24_prg_allow, vrc24_chr_addr, vrc24_vram_a10, vrc24_vram_ce, vrc24_chr_allow, vrc24_irq};
    73: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq} = {vrc3_prg_addr, vrc3_prg_allow, vrc3_chr_addr, vrc3_vram_a10, vrc3_vram_ce, vrc3_chr_allow, vrc3_irq};
    24,
    26: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, prg_dout, irq, audio} = {vrc6_prg_addr, vrc6_prg_allow, vrc6_chr_addr, vrc6_vram_a10, vrc6_vram_ce, vrc6_chr_allow, vrc6_prg_dout, vrc6_irq, vrc6_audio};
    85: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, irq, audio} = {vrc7_prg_addr, vrc7_prg_allow, vrc7_chr_addr, vrc7_vram_a10, vrc7_vram_ce, vrc7_chr_allow, vrc7_irq, vrc7_audio};
    210,
    19: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow, prg_dout, irq, audio} = {map19_prg_addr, map19_prg_allow, map19_chr_addr, map19_vram_a10, map19_vram_ce, map19_chr_allow, map19_prg_dout, map19_irq, map19_audio};
    default: {prg_aout, prg_allow, chr_aout, vram_a10, vram_ce, chr_allow} = {mmc0_prg_addr, mmc0_prg_allow, mmc0_chr_addr, mmc0_vram_a10, mmc0_vram_ce, mmc0_chr_allow};
    endcase
    if (prg_aout[21:20] == 2'b00)
      prg_aout[19:0] = {prg_aout[19:14] & prg_mask, prg_aout[13:0]};
    if (chr_aout[21:20] == 2'b10)
      chr_aout[19:0] = {chr_aout[19:13] & chr_mask, chr_aout[12:0]};
    // Remap the CHR address into VRAM, if needed.
    chr_aout = vram_ce ? {11'b11_0000_0000_0, vram_a10, chr_ain[9:0]} : chr_aout;
    prg_aout = (prg_ain < 'h2000) ? {11'b11_1000_0000_0, prg_ain[10:0]} : prg_aout;
    prg_allow = prg_allow || (prg_ain < 'h2000);
  end
endmodule

// PRG       = 0....
// CHR       = 10...
// CHR-VRAM  = 1100
// CPU-RAM   = 1110
// CARTRAM   = 1111
                 
