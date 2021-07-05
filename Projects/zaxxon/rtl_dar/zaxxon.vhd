---------------------------------------------------------------------------------
-- Zaxxon by Dar (darfpga@aol.fr) (23/11/2019)
-- http://darfpga.blogspot.fr
---------------------------------------------------------------------------------
--
-- release rev 00 : initial release
--  (23/11/2019)
---------------------------------------------------------------------------------
-- gen_ram.vhd & io_ps2_keyboard
-------------------------------- 
-- Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com/fpga64.html
---------------------------------------------------------------------------------
-- T80/T80se - Version : 304
-----------------------------
-- Z80 compatible microprocessor core
-- Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org)
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------

--  Features :
--   Video        : TV 15kHz
--   Coctail mode : Yes
--   Sound        : No (atm)

--  Use with MAME roms from zaxxon.zip
--
--  Use make_zaxxon_proms.bat to build vhd file from binaries
--  (CRC list included)

--  Zaxxon (Gremlin/SEGA) Hardware caracteristics :
--
--  VIDEO : 1xZ80@3MHz CPU accessing its program rom, working ram,
--    sprite data ram, I/O, sound board register and trigger.
--		  20Kx8bits program rom
--
--    3 graphic layers
--
--    One char map 32x28 tiles 
--      2x2Kx8bits graphics rom 2bits/pixel
--      static layout color rom 16 color/tile
--
--    One diagonal scrolling background map 8x8 tiles
--      4x8Kx8bits tile map rom (10 bits code + 4bits color)
--      3x8Kx8bits graphics rom 3bits/pixel
--
--    32 sprites, up to 8/scanline 32x32pixels with flip H/V
--      6bits code + 2 bits flip h/v, 5 bits color 
--      3x8Kx8bits graphics rom 3bits/pixel
--      
--    general palette 256 colors 3red 3green 2blue 
--       char 2bits/tile +  4bits color set/tile + 1bits global set
--       background 3bits/tile + 4 bits color set/tile + 1bits global set
--       sprites   3bits/sprite + 5 bits color set/sprite
--
--    Working ram : 4Kx8bits
--    char ram    : 1Kx8bits code, (+ static layout color rom)
--    sprites ram : 256x8bits + 32x9bits intermediate buffer + 256x8bits line buffer
--

--  SOUND : see zaxxon_sound_board.vhd

---------------------------------------------------------------------------------
--  Schematics remarks : IC board 834-0214 and 834-0257 or 834-0211
--  some details are missing or seems to be wrong:
--     - sprite buffer addresses flip control seems to be incomplete
--       (fliping adresses both at read and write is useless !)
--     - diagonal scrolling seems to be incomplete (BCK on U52 pin 4 where from ?)
--     - 834-0211 sheet 6 of 9 : 74ls161 U26 at C-5 no ouput used !
--     - 834-0211 sheet 7 of 9 : /128H, 128H and 256H dont agree with U21 Qc/Qd 
--       output ! 
--
--  tips :
--     Background tiles scrolls over H (and V) but map rom output are latched
--     at fixed Hcnt position (4H^). Graphics rom ouput latch is scrolled over H.
--
--     During visible area (hcnt(8) = 1) sprite data are transfered from sp_ram
--     to sp_online_ram. Only sprites visible on (next) line are transfered. So
--     64 sprites are defined in sp_ram and only 8 can be transfered to 
--     sp_online_ram. 
--
--     During line fly back (hcnt(8) = 0) sp_online_ram is read and sprite
--     graphics feed line buffer. Line buffer is then read starting from
--     visible line.
--
--     Sprite data transfer is done at pixel rate : each sprite is 4 bytes data.
--     Visible area allows 64 sprites x 4 data (256 pixels) to be read, only 8
--     sprites (the ones on next line) are transfered.
--
--     Line buffer feed is done at twice pixel rate : 8 sprites x 32 pixels / 2
--     (256/2 = 128 pixels = fly back area length).
--
--     sp_online_ram is 9 bits wide. 9th bits is set during tranfer for actual 
--     sprites data written. 9th bit is reset during fly back area after data
--     are read. So 9th bits are all set to 0s at start of next transfer.
--
--     When feeding line buffer sprites graphic data are written only of no 
--     graphics have been written previouly for that line. Line buffer pixels are
--     set to 0s after each pixel read during visible area. Thus line buffer is 
--     fully cleared at start of next feeding.
--
--     Global screen flip is fully managed at hardware level. This allow to 
--     easily add an external flip screen feature.
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity zaxxon is
port(
 clock_24       : in std_logic;
 reset          : in std_logic;
-- tv15Khz_mode   : in std_logic;
 video_r        : out std_logic_vector(2 downto 0);
 video_g        : out std_logic_vector(2 downto 0);
 video_b        : out std_logic_vector(1 downto 0);
 video_clk      : out std_logic;
 video_csync    : out std_logic;
 video_blankn   : out std_logic;
 video_hs       : out std_logic;
 video_vs       : out std_logic;
 
 audio_out_l    : out std_logic_vector(15 downto 0);
 audio_out_r    : out std_logic_vector(15 downto 0);
  
 coin1          : in std_logic;
 coin2          : in std_logic;
 start1         : in std_logic; 
 start2         : in std_logic; 
 
 left           : in std_logic; 
 right          : in std_logic; 
 up             : in std_logic;
 down           : in std_logic;
 fire           : in std_logic;
 
 left_c         : in std_logic; 
 right_c        : in std_logic; 
 up_c           : in std_logic;
 down_c         : in std_logic;
 fire_c         : in std_logic;

 cocktail       : in std_logic;
 service        : in std_logic;
 flip_screen    : in std_logic;


  
 dbg_cpu_addr : out std_logic_vector(15 downto 0)
 );
end zaxxon;

architecture struct of zaxxon is

 signal reset_n   : std_logic;
 signal clock_vid : std_logic;
 signal clock_vidn: std_logic;
 signal clock_cnt : std_logic_vector(3 downto 0) := "0000";

 signal hcnt    : std_logic_vector(8 downto 0) := (others=>'0'); -- horizontal counter
 signal vcnt    : std_logic_vector(8 downto 0) := (others=>'0'); -- vertical counter
 signal hflip   : std_logic_vector(8 downto 0) := (others=>'0'); -- horizontal counter flip
 signal vflip   : std_logic_vector(8 downto 0) := (others=>'0'); -- vertical counter flip
 signal hflip2  : std_logic_vector(8 downto 0) := (others=>'0'); -- horizontal counter flip
 
 signal hs_cnt, vs_cnt :std_logic_vector(9 downto 0) ;
 signal hsync0, hsync1, hsync2, hsync3, hsync4 : std_logic;
 signal top_frame : std_logic := '0';
 
 signal pix_ena     : std_logic;
 signal cpu_ena     : std_logic;

 signal cpu_addr    : std_logic_vector(15 downto 0);
 signal cpu_di      : std_logic_vector( 7 downto 0);
 signal cpu_do      : std_logic_vector( 7 downto 0);
 signal cpu_wr_n    : std_logic;
 signal cpu_rd_n    : std_logic;
 signal cpu_mreq_n  : std_logic;
 signal cpu_ioreq_n : std_logic;
 signal cpu_irq_n   : std_logic;
 signal cpu_m1_n    : std_logic;
  
 signal cpu_rom_do : std_logic_vector(7 downto 0);
 
 signal wram_we    : std_logic;
 signal wram_do    : std_logic_vector(7 downto 0);

 signal ch_ram_addr: std_logic_vector(9 downto 0);
 signal ch_ram_we  : std_logic;
 signal ch_ram_do  : std_logic_vector(7 downto 0);
 signal ch_ram_do_to_cpu: std_logic_vector(7 downto 0); -- registred ram data for cpu

 signal ch_code         : std_logic_vector(7 downto 0); 
 signal ch_code_r       : std_logic_vector(7 downto 0); 
 signal ch_attr         : std_logic_vector(7 downto 0);

 signal ch_code_line    : std_logic_vector(10 downto 0);
 signal ch_bit_nb       : integer range 0 to 7;
 signal ch_graphx1_do   : std_logic_vector( 7 downto 0);
 signal ch_graphx2_do   : std_logic_vector( 7 downto 0);
 signal ch_vid          : std_logic_vector( 1 downto 0);
 
 signal ch_color_addr   : std_logic_vector(7 downto 0);
 signal ch_color_do     : std_logic_vector(7 downto 0); -- 4 bits only used
 signal palette_addr    : std_logic_vector(7 downto 0);
 signal palette_do      : std_logic_vector(7 downto 0);
 
 signal map_offset_h     : std_logic_vector(11 downto 0);
 signal map_offset_l1    : std_logic_vector( 7 downto 0); 
 signal map_offset_l2    : std_logic_vector( 7 downto 0); 
 
 signal map_addr         : std_logic_vector(13 downto 0);
 signal map1_do          : std_logic_vector( 7 downto 0);
 signal map2_do          : std_logic_vector( 7 downto 0);
 
 signal bg_graphics_addr : std_logic_vector(12 downto 0);
 signal bg_graphics1_do  : std_logic_vector( 7 downto 0);
 signal bg_graphics2_do  : std_logic_vector( 7 downto 0);
 signal bg_graphics3_do  : std_logic_vector( 7 downto 0);
 signal bg_bit_nb        : integer range 0 to 7;
 signal bg_color_a       : std_logic_vector(3 downto 0);
 signal bg_color         : std_logic_vector(3 downto 0);
 signal bg_vid           : std_logic_vector(2 downto 0); 
 signal bg_code_line     : std_logic_vector(9 downto 0);

 signal sp_ram_addr       : std_logic_vector(7 downto 0);
 signal sp_ram_we         : std_logic;
 signal sp_ram_do         : std_logic_vector(7 downto 0);
 signal sp_ram_do_to_cpu        : std_logic_vector(7 downto 0);
 signal sp_ram_do_to_sp_machine : std_logic_vector(7 downto 0);
 
 signal sp_vcnt     : std_logic_vector(7 downto 0);
 signal sp_on_line  : std_logic;

 signal sp_online_ram_we   : std_logic;
 signal sp_online_ram_addr : std_logic_vector(4 downto 0);
 signal sp_online_ram_di   : std_logic_vector(8 downto 0);
 signal sp_online_ram_do   : std_logic_vector(8 downto 0);
  
 signal vflip_r        : std_logic_vector(8 downto 0);
 signal sp_online_vcnt : std_logic_vector(7 downto 0);
 signal sp_line        : std_logic_vector(7 downto 0); 
 signal sp_code        : std_logic_vector(7 downto 0);
 signal sp_color       : std_logic_vector(4 downto 0);
 signal sp_color_r     : std_logic_vector(4 downto 0);

 signal sp_code_line    : std_logic_vector(12 downto 0);
 signal sp_hflip        : std_logic;
 signal sp_vflip        : std_logic;
 
 signal sp_graphics_addr  : std_logic_vector(12 downto 0);
 signal sp_graphics1_do   : std_logic_vector( 7 downto 0); 
 signal sp_graphics2_do   : std_logic_vector( 7 downto 0); 
 signal sp_graphics3_do   : std_logic_vector( 7 downto 0); 

 signal sp_ok              : std_logic;
 signal sp_bit_hpos        : std_logic_vector(7 downto 0);
 signal sp_bit_nb          : integer range 0 to 7;

 signal sp_buffer_ram_addr : std_logic_vector(7 downto 0);
 signal sp_buffer_ram_we   : std_logic;
 signal sp_buffer_ram_di   : std_logic_vector(7 downto 0);
 signal sp_buffer_ram_do   : std_logic_vector(7 downto 0);
 
 signal sp_vid              : std_logic_vector(7 downto 0);

 signal vblkn, vblkn_r : std_logic;
 signal int_on       : std_logic := '0';
 
 signal flip_cpu     : std_logic := '0';
 signal flip         : std_logic := '0';
 signal ch_color_ref : std_logic := '0';
 signal bg_position  : std_logic_vector(10 downto 0) := (others => '0');
 signal bg_color_ref : std_logic := '0';
 signal bg_enable    : std_logic := '0';
 
 signal p1_input  : std_logic_vector(7 downto 0);
 signal p2_input  : std_logic_vector(7 downto 0); 
 signal sw1_input : std_logic_vector(7 downto 0);
 signal sw2_input : std_logic_vector(7 downto 0);
 signal gen_input : std_logic_vector(7 downto 0);
 
 signal coin1_r, coin1_mem, coin1_ena : std_logic := '0';
 signal coin2_r, coin2_mem, coin2_ena : std_logic := '0';
    
begin

clock_vid  <= clock_24;
clock_vidn <= not clock_24;
reset_n    <= not reset;

-- debug 
process (reset, clock_vid)
begin
-- if rising_edge(clock_vid) and cpu_ena ='1' and cpu_mreq_n ='0' then
   --dbg_cpu_addr <=  cpu_addr;
 if rising_edge(clock_vid) then 
   dbg_cpu_addr <= sp_buffer_ram_do & sp_graphics1_do;
 end if;
end process;

-- make enables clock from clock_vid
process (clock_vid, reset)
begin
	if reset='1' then
		clock_cnt <= (others=>'0');
	else 
		if rising_edge(clock_vid) then
			if clock_cnt = "1111" then  -- divide by 16
				clock_cnt <= (others=>'0');
			else
				clock_cnt <= clock_cnt + 1;
			end if;
		end if;
	end if;   		
end process;
--  _   _   _   _   _   _   _   _   _   _   _ 
--   |_| |_| |_| |_| |_| |_| |_| |_| |_| |_| |  clock_vid    24MHz
--      ___     ___     ___     ___     ___
--  ___|   |___|   |___|   |___|   |___|   |__  clock_cnt(0) 12MHz
--          _______         _______         __
--  _______|       |_______|       |_______|    clock_cnt(1)  6MHz
--      ___             ___             ___
--  ___|   |___________|   |___________|   |__  pix_ena       6MHz
--
--  _______ _______________ _______________ __
--  _______|_______________|_______________|__  video
--

pix_ena <= '1' when clock_cnt(1 downto 0) = "01"    else '0'; -- (6MHz)
cpu_ena <= '1' when hcnt(0) = '0' and pix_ena = '1' else '0'; -- (3MHz)

video_clk <= clock_cnt(0);    -- added by somhic

---------------------------------------
-- Video scanner  384x264 @6.083 MHz --
-- display 256x224                   --
--                                   --
-- line  : 63.13us -> 15.84kHz       --
-- frame : 16.67ms -> 60.00Hz        --
---------------------------------------

process (reset, clock_vid)
begin
	if reset='1' then
		hcnt  <= (others=>'0');
		vcnt  <= (others=>'0');
		top_frame <= '0';
	else 
		if rising_edge(clock_vid) then
			if pix_ena = '1' then
		
				-- main horizontal / vertical counters
				hcnt <= hcnt + 1;
				if hcnt = 511 then
					hcnt <= std_logic_vector(to_unsigned(128,9));
				end if;	
					
				if hcnt = 128+8+8 then
					vcnt <= vcnt + 1;
					if vcnt = 263 then
						vcnt <= (others=>'0');
						top_frame <= not top_frame;
					end if;
				end if;
				
				-- set syncs position 
				if hcnt = 170 then              -- tune screen H position here
					hs_cnt <= (others => '0');
					if (vcnt = 248) then         -- tune screen V position here
						vs_cnt <= (others => '0');
					else
						vs_cnt <= vs_cnt +1;
					end if;
					
				else 
					hs_cnt <= hs_cnt + 1;
				end if;
				
				-- blanking
				video_blankn <= '0';				
				if (hcnt >= 256+9-5 or hcnt < 128+9-5) and
					 vcnt >= 17 and  vcnt < 240 then video_blankn <= '1';end if;
				
				-- build syncs pattern (composite)
				if    hs_cnt =  0 then hsync0 <= '0';
				elsif hs_cnt = 29 then hsync0 <= '1';
				end if;

				if    hs_cnt =      0  then hsync1 <= '0';
				elsif hs_cnt =     14  then hsync1 <= '1';
				elsif hs_cnt = 192+ 0  then hsync1 <= '0';
				elsif hs_cnt = 192+14  then hsync1 <= '1';
				end if;
		
				if    hs_cnt =      0  then hsync2 <= '0';
				elsif hs_cnt = 192-29  then hsync2 <= '1';
				elsif hs_cnt = 192     then hsync2 <= '0';
				elsif hs_cnt = 384-29  then hsync2 <= '1';
				end if;

				if    hs_cnt =      0  then hsync3 <= '0';
				elsif hs_cnt =     14  then hsync3 <= '1';
				elsif hs_cnt = 192     then hsync3 <= '0';
				elsif hs_cnt = 384-29  then hsync3 <= '1';
				end if;

				if    hs_cnt =      0  then hsync4 <= '0';
				elsif hs_cnt = 192-29  then hsync4 <= '1';
				elsif hs_cnt = 192     then hsync4 <= '0';
				elsif hs_cnt = 192+14  then hsync4 <= '1';
				end if;
						
				if     vs_cnt =  1 then video_csync <= hsync1;
				elsif  vs_cnt =  2 then video_csync <= hsync1;
				elsif  vs_cnt =  3 then video_csync <= hsync1;
				elsif  vs_cnt =  4 and top_frame = '1' then video_csync <= hsync3;
				elsif  vs_cnt =  4 and top_frame = '0' then video_csync <= hsync1;
				elsif  vs_cnt =  5 then video_csync <= hsync2;
				elsif  vs_cnt =  6 then video_csync <= hsync2;
				elsif  vs_cnt =  7 and  top_frame = '1' then video_csync <= hsync4;
				elsif  vs_cnt =  7 and  top_frame = '0' then video_csync <= hsync2;
				elsif  vs_cnt =  8 then video_csync <= hsync1;
				elsif  vs_cnt =  9 then video_csync <= hsync1;
				elsif  vs_cnt = 10 then video_csync <= hsync1;
				elsif  vs_cnt = 11 then video_csync <= hsync0;
				else                    video_csync <= hsync0;
				end if;	
	
				-- added by somhic
				-- external sync outputs

				video_hs <= hsync0;
				
				if    vs_cnt = 0 then video_vs <= '0';
				elsif vs_cnt = 11 then video_vs <= '1';
				end if;
	
			end if;
		end if;
	end if;
end process;

---------------------------------
-- players/dip switches inputs --
---------------------------------
p1_input <= "000" & fire   & down   & up   & left   & right  ;
p2_input <= "000" & fire_c & down_c & up_c & left_c & right_c;
sw1_input <= cocktail&"111"&x"f"; -- cocktail->FF  upright->7F
sw2_input <= x"33"; -- coin a/b 1c_1c
gen_input <= service & coin2_mem & coin1_mem & '0' & start2 & start1 & "00";

------------------------------------------
-- cpu data input with address decoding --
------------------------------------------
cpu_di <= cpu_rom_do       when cpu_mreq_n = '0' and cpu_addr(15 downto 12) < X"6" else -- 0000-5FFF
			 wram_do          when cpu_mreq_n = '0' and cpu_addr(15 downto 12) = x"6" else -- 6000-6FFF
			 ch_ram_do_to_cpu when cpu_mreq_n = '0' and (cpu_addr and x"E000") = x"8000" else -- video ram   8000-83FF + mirroring 1C00
			 sp_ram_do_to_cpu when cpu_mreq_n = '0' and (cpu_addr and x"E000") = x"A000" else -- sprite ram  A000-A0FF + mirroring 1F00
			 p1_input         when cpu_mreq_n = '0' and (cpu_addr and x"E703") = x"C000" else -- player 1    C000      + mirroring 18FC 
			 p2_input         when cpu_mreq_n = '0' and (cpu_addr and x"E703") = x"C001" else -- player 2    C001      + mirroring 18FC 
			 sw1_input        when cpu_mreq_n = '0' and (cpu_addr and x"E703") = x"C002" else -- switch 1    C002      + mirroring 18FC 
			 sw2_input        when cpu_mreq_n = '0' and (cpu_addr and x"E703") = x"C003" else -- switch 2    C003      + mirroring 18FC 
			 gen_input        when cpu_mreq_n = '0' and (cpu_addr and x"E700") = x"C100" else -- general     C100      + mirroring 18FF 
   		 X"FF";
	
------------------------------------------------------------------------
-- Coin registers
------------------------------------------------------------------------
process (clock_vid, coin1_ena, coin2_ena)
begin
	if coin1_ena = '0' then
		coin1_mem <= '0';
	else 
		if rising_edge(clock_vid) then	
			coin1_r <= coin1;
			if coin1 = '1' and coin1_r = '0' then coin1_mem <= coin1_ena; end if;			
		end if;
	end if;
	if coin2_ena = '0' then
		coin2_mem <= '0';
	else 
		if rising_edge(clock_vid) then	
			coin2_r <= coin2;
			if coin2 = '1' and coin2_r = '0' then coin2_mem <= coin2_ena; end if;
		end if;
	end if;
end process;	

------------------------------------------------------------------------
-- Misc registers - interrupt set/enable
------------------------------------------------------------------------
vblkn <= '0' when vcnt < 256 else '1';

process (clock_vid)
begin
	if rising_edge(clock_vid) then
	
		vblkn_r <= vblkn; 
	
		if cpu_mreq_n = '0' and cpu_wr_n = '0' then 
		
			if (cpu_addr and x"E707") = x"C000" then coin1_ena                <= cpu_do(0);          end if; -- C000 + mirroring 18F8
			if (cpu_addr and x"E707") = x"C001" then coin2_ena                <= cpu_do(0);          end if; -- C001 + mirroring 18F8
			if (cpu_addr and x"E707") = x"C006" then flip_cpu                 <= cpu_do(0);      end if; -- C006 + mirroring 18F8
			
			if (cpu_addr and x"E0FF") = x"E0F0" then int_on                   <= cpu_do(0);          end if; -- E0F0 + mirroring 1F00
			if (cpu_addr and x"E0FF") = x"E0F1" then ch_color_ref             <= cpu_do(0);          end if; -- E0F1 + mirroring 1F00
			if (cpu_addr and x"E0FF") = x"E0F8" then bg_position( 7 downto 0) <= not cpu_do   ;          end if; -- E0F8 + mirroring 1F00
			if (cpu_addr and x"E0FF") = x"E0F9" then bg_position(10 downto 8) <= not cpu_do(2 downto 0); end if; -- E0F9 + mirroring 1F00
			if (cpu_addr and x"E0FF") = x"E0FA" then bg_color_ref             <= cpu_do(0);          end if; -- E0FA + mirroring 1F00
			if (cpu_addr and x"E0FF") = x"E0FB" then bg_enable                <= cpu_do(0);          end if; -- E0FB + mirroring 1F00
	
		end if;
		
		if int_on = '0' then 
			cpu_irq_n <= '1';		
		else
			if vblkn_r = '1' and vblkn = '0' then cpu_irq_n <= '0'; end if;
		end if;	
		
	end if;
end process;

------------------------------------------
-- write enable / ram access from CPU   --
-- mux ch_ram and sp ram addresses      --
-- dmux ch_ram and sp_ram data out      -- 
------------------------------------------
wram_we   <= '1' when cpu_mreq_n = '0' and cpu_wr_n = '0' and cpu_addr(15 downto 12 ) = x"6"   else '0';
ch_ram_we <= '1' when cpu_mreq_n = '0' and cpu_wr_n = '0' and (cpu_addr and x"E000")  = x"8000" and hcnt(0) = '1' else '0';
sp_ram_we <= '1' when cpu_mreq_n = '0' and cpu_wr_n = '0' and (cpu_addr and x"E000")  = x"A000" and hcnt(0) = '1' else '0';

flip <= flip_cpu xor flip_screen;
hflip <= hcnt when flip = '0' else not hcnt;
vflip <= vcnt when flip = '0' else not vcnt;

ch_ram_addr <= cpu_addr(9 downto 0) when hcnt(0) = '1' else vflip(7 downto 3) & hflip(7 downto 3);
sp_ram_addr <= cpu_addr(7 downto 0) when hcnt(0) = '1' else '0'& hcnt(7 downto 1);

process (clock_vid)
begin
	if rising_edge(clock_vid) then
		if hcnt(0) = '1' then
			ch_ram_do_to_cpu <= ch_ram_do;
			sp_ram_do_to_cpu <= sp_ram_do;
		else
			sp_ram_do_to_sp_machine <= sp_ram_do;		
		end if;
	end if;
end process;

----------------------
--- sprite machine ---
----------------------
--
-- transfert sprites data from sp_ram to sp_online_ram
--
sp_vcnt          <= sp_ram_do_to_sp_machine + ("111" & not(flip)  & flip  & flip  & flip  & '1') + vflip(7 downto 0) + 1; 

sp_online_ram_we <= '1' when hcnt(8) = '1' and sp_on_line = '1' and hcnt(0) ='0' and sp_online_ram_addr < "11111" else 
						  '1' when hcnt(8) = '0' and hcnt(3) = '1' else '0';

sp_online_ram_di <= '1' & sp_ram_do_to_sp_machine when hcnt(8) = '1' else '0'&x"00";

process (clock_vid)
begin
	if rising_edge(clock_vid) then

		if hcnt(8) = '1' then
			if hcnt(2 downto 0) = "000" then
				if sp_vcnt(7 downto 5) = "111" then 
					sp_on_line <= '1';
				else
					sp_on_line <= '0';
				end if;
			end if;
		else
			sp_on_line <= '0';		
		end if;
		
		if hcnt(8) = '1' then
		
			-- during line display seek for sprite on line and transfert them to sp_online_ram
			if hcnt = 256 then sp_online_ram_addr <= (others => '0'); end if;			
			
			if pix_ena = '1' and sp_on_line = '1' and hcnt(0) = '0' and sp_online_ram_addr < "11111" then 
	
				sp_online_ram_addr <= sp_online_ram_addr + 1;
				
			end if;
				
			-- during line fly back read sp_online_ram				
		else
			sp_online_ram_addr <= hcnt(6 downto 4) & hcnt(2 downto 1);
		end if;
		
	end if;
end process;	

--
-- read sprite data from sp_online_ram and feed sprite line buffer with sprite graphics data
--

sp_online_vcnt <= sp_online_ram_do(7 downto 0) + ("111" & not(flip)  & flip  & flip  & flip  & '1') + vflip_r(7 downto 0) + 1; 

sp_code_line <= (sp_code(5 downto 0)) & 
					 (sp_line(4 downto 3) xor (sp_code(7) & sp_code(7))) &
					 ("00"                xor (sp_code(6) & sp_code(6))) &
					 (sp_line(2 downto 0) xor (sp_code(7) & sp_code(7) & sp_code(7)));
			
sp_buffer_ram_addr <= sp_bit_hpos when flip = '1' and hcnt(8) = '1' else not sp_bit_hpos;

sp_buffer_ram_di <= x"00" when hcnt(8) = '1' else
							sp_color_r & sp_graphics3_do(sp_bit_nb) &
							sp_graphics2_do(sp_bit_nb) & sp_graphics1_do(sp_bit_nb);

sp_buffer_ram_we <= pix_ena when hcnt(8) = '1' else
						  sp_ok and clock_cnt(0) when sp_buffer_ram_do(2 downto 0) = "000" else '0';

process (clock_vid)
begin
	if rising_edge(clock_vid) then
	
		if pix_ena = '0' then 
			sp_vid <= sp_buffer_ram_do;
		end if;
	
		if hcnt = 128 then vflip_r <= vflip; end if; 
		
		if hcnt(8)='0' then 
		
			if clock_cnt(0) = '1' then 
				if sp_hflip = '1' then sp_bit_nb <= sp_bit_nb + 1; end if;
				if sp_hflip = '0' then sp_bit_nb <= sp_bit_nb - 1; end if;
				
				sp_bit_hpos <= sp_bit_hpos + 1;			
			end if;
			
			if pix_ena = '1' then 
			
			if hcnt(3 downto 0) = "0000" then sp_line  <= sp_online_vcnt; end if;
			if hcnt(3 downto 0) = "0010" then sp_code  <= sp_online_ram_do(7 downto 0); end if;
			if hcnt(3 downto 0) = "0100" then sp_color <= sp_online_ram_do(4 downto 0); end if;
			if hcnt(3 downto 0) = "0110" then sp_bit_hpos <= sp_online_ram_do(7 downto 0) + ("111" & not(flip)  & flip  & flip  & flip  & '1') +1; end if;
			
			if hcnt(3 downto 0) = "0110" then
				sp_graphics_addr <= sp_code_line;
				sp_ok <= sp_online_ram_do(8);
				sp_hflip <= sp_code(6);
				sp_vflip <= sp_code(7);
				if sp_code(6) = '1' then sp_bit_nb <= 0; else sp_bit_nb <= 7; end if;
				sp_color_r <= sp_color;
			end if;
			if hcnt(3 downto 0) = "1010" then
				sp_graphics_addr(4 downto 3) <= "01" xor (sp_hflip & sp_hflip);
			end if;
			if hcnt(3 downto 0) = "1110" then
				sp_graphics_addr(4 downto 3) <= "10" xor (sp_hflip & sp_hflip);
			end if;
			if hcnt(3 downto 0) = "0010" then
				sp_graphics_addr(4 downto 3) <= "11" xor (sp_hflip & sp_hflip);
			end if;

			end if;
			
		else
		
			if flip = '1' then 
				sp_bit_hpos <= hcnt(7 downto 0) - 5; -- tune sprite position w.r.t. background
			else
				sp_bit_hpos <= hcnt(7 downto 0) - 2; -- tune sprite position w.r.t. background
			end if;
			
		end if;
		
	end if;
end process;

--------------------
--- char machine ---
--------------------
ch_code_line <= ch_code & vflip(2 downto 0);

process (clock_vid)
begin
	if rising_edge(clock_vid) then

		if pix_ena = '1' then
		
			if hcnt(2 downto 0) = "010" then
				ch_code       <= ch_ram_do;
				ch_color_addr <= vflip(7 downto 5) & hflip(7 downto 3);
				
				if flip = '1' then ch_bit_nb <= 0; else ch_bit_nb <= 7; end if;
			else
			
				if flip  = '1' then 
					ch_bit_nb <= ch_bit_nb + 1;
				else
					ch_bit_nb <= ch_bit_nb - 1;			
				end if;
				
			end if;
			
		end if;

	end if;
end process;

ch_vid    <= ch_graphx2_do(ch_bit_nb) & ch_graphx1_do(ch_bit_nb);
	
--------------------------
--- background machine ---
--------------------------
map_offset_h <= (bg_position & '1') + (x"0" & vflip(7 downto 0)) + 1;

-- count from "00"->"FF" and then continue with "00"->"7F" instead of "80"->"FF"
hflip2 <= hflip xor (not(hcnt(8)) & "0000000") when flip = '1' else hflip; 

map_offset_l1 <= not('0' & vflip(7 downto 1)) + (hflip2(7 downto 3) & "111") + 1;
map_offset_l2 <= map_offset_l1 + ('0' & not(flip) & flip & flip & flip & "000");

map_addr <=  map_offset_h(11 downto 3) & map_offset_l2(7 downto 3);

bg_graphics_addr(2 downto 0) <= map_offset_h(2 downto 0);

process (clock_vid)
begin
	if rising_edge(clock_vid) then

		if pix_ena = '1' then
		
			if hcnt(2 downto 0) = "011" then  -- 4H^
				bg_code_line(9 downto 0) <= map2_do(1 downto 0) & map1_do;
				bg_color_a <= map2_do(7 downto 4);
			end if;

			if (not(vflip(3 downto 1)) + hflip(2 downto 0)) = "011" then 
				bg_graphics_addr(12 downto 3) <= bg_code_line;
				bg_color  <= bg_color_a;
				
				if flip  = '1' then bg_bit_nb <= 0;	else bg_bit_nb <= 7; end if;
			else
				if flip  = '1' then 
					bg_bit_nb <= bg_bit_nb + 1;
				else
					bg_bit_nb <= bg_bit_nb - 1;			
				end if;
			end if;
			
		end if;

	end if;
end process;
	
bg_vid <= bg_graphics3_do(bg_bit_nb) & bg_graphics2_do(bg_bit_nb) & bg_graphics1_do(bg_bit_nb) 
	when bg_enable = '1' else "000";

--------------------------------------
-- mux char/background/sprite video --
--------------------------------------
process (clock_vid)
begin
	if rising_edge(clock_vid) then

		if pix_ena = '1' then
		
			palette_addr <= bg_color_ref & bg_color & bg_vid;
			
			if sp_vid(2 downto 0) /= "000" then
				palette_addr <= sp_vid;
 			end if;
			
			if ch_vid /= "00" then
				palette_addr <= ch_color_ref & ch_color_do(3 downto 0) & '0' & ch_vid;
 			end if;			
		
			video_r <= palette_do(2 downto 0);		
			video_g <= palette_do(5 downto 3);		
			video_b <= palette_do(7 downto 6);		
		
		end if;

	end if;
end process;

------------------------------
-- components & sound board --
------------------------------

-- microprocessor Z80
cpu : entity work.T80se
generic map(Mode => 0, T2Write => 1, IOWait => 1)
port map(
  RESET_n => reset_n,
  CLK_n   => clock_vid,
  CLKEN   => cpu_ena,
  WAIT_n  => '1',
  INT_n   => cpu_irq_n,
  NMI_n   => '1', --cpu_nmi_n,
  BUSRQ_n => '1',
  M1_n    => cpu_m1_n,
  MREQ_n  => cpu_mreq_n,
  IORQ_n  => cpu_ioreq_n,
  RD_n    => cpu_rd_n,
  WR_n    => cpu_wr_n,
  RFSH_n  => open,
  HALT_n  => open,
  BUSAK_n => open,
  A       => cpu_addr,
  DI      => cpu_di,
  DO      => cpu_do
);

-- cpu program ROM 0x0000-0x5FFF
rom_cpu : entity work.zaxxon_cpu
port map(
 clk  => clock_vidn,
 addr => cpu_addr(14 downto 0),
 data => cpu_rom_do
);

-- working RAM   0x6000-0x6FFF
wram : entity work.gen_ram
generic map( dWidth => 8, aWidth => 12)
port map(
 clk  => clock_vidn,
 we   => wram_we,
 addr => cpu_addr(11 downto 0),
 d    => cpu_do,
 q    => wram_do
);

-- video RAM   0x8000-0x83FF + mirroring adresses
video_ram : entity work.gen_ram
generic map( dWidth => 8, aWidth => 10)
port map(
 clk  => clock_vidn,
 we   => ch_ram_we,
 addr => ch_ram_addr,
 d    => cpu_do,
 q    => ch_ram_do
);

-- sprite RAM  0xA000-0xA0FF + mirroring adresses
sprites_ram : entity work.gen_ram
--sprites_ram_test : entity work.sp_ram_test
generic map( dWidth => 8, aWidth => 8)
port map(
 clk  => clock_vidn,
 we   => sp_ram_we,
-- we   => '0',
 addr => sp_ram_addr,
 d    => cpu_do,
 q    => sp_ram_do
);

-- sprite online RAM
sprites_online_ram : entity work.gen_ram
generic map( dWidth => 9, aWidth => 5)
port map(
 clk  => clock_vidn,
 we   => sp_online_ram_we,
 addr => sp_online_ram_addr,
 d    => sp_online_ram_di,
 q    => sp_online_ram_do
);

-- sprite line buffer
sprlinebuf : entity work.gen_ram
generic map( dWidth => 8, aWidth => 8)
port map(
 clk  => clock_vidn,
 we   => sp_buffer_ram_we,
 addr => sp_buffer_ram_addr,
 d    => sp_buffer_ram_di,
 q    => sp_buffer_ram_do
);

-- char graphics ROM 1
bg_graphics_1 : entity work.zaxxon_char_bits_1
port map(
 clk  => clock_vidn,
 addr => ch_code_line,
 data => ch_graphx1_do
);

-- char graphics ROM 2
bg_graphics_2 : entity work.zaxxon_char_bits_2
port map(
 clk  => clock_vidn,
 addr => ch_code_line,
 data => ch_graphx2_do
);
-- map tile ROM 1
map_tile_1 : entity work.zaxxon_map_1
port map(
 clk  => clock_vidn,
 addr => map_addr,
 data => map1_do
);

-- map tile ROM 2
map_tile_2 : entity work.zaxxon_map_2
port map(
 clk  => clock_vidn,
 addr => map_addr,
 data => map2_do
);

-- background graphics ROM 1
bg_graphics_bits_1 : entity work.zaxxon_bg_bits_1
port map(
 clk  => clock_vidn,
 addr => bg_graphics_addr,
 data => bg_graphics1_do
);

-- background graphics ROM 2
bg_graphics_bits_2 : entity work.zaxxon_bg_bits_2
port map(
 clk  => clock_vidn,
 addr => bg_graphics_addr,
 data => bg_graphics2_do
);

-- background graphics ROM 3
bg_graphics_bits_3 : entity work.zaxxon_bg_bits_3
port map(
 clk  => clock_vidn,
 addr => bg_graphics_addr,
 data => bg_graphics3_do
);

-- sprite graphics ROM 1
sp_graphics_bits_1 : entity work.zaxxon_sp_bits_1
port map(
 clk  => clock_vidn,
 addr => sp_graphics_addr,
 data => sp_graphics1_do
);

-- sprite graphics ROM 2
sp_graphics_bits_2 : entity work.zaxxon_sp_bits_2
port map(
 clk  => clock_vidn,
 addr => sp_graphics_addr,
 data => sp_graphics2_do
);

-- sprite graphics ROM 3
sp_graphics_bits_3 : entity work.zaxxon_sp_bits_3
port map(
 clk  => clock_vidn,
 addr => sp_graphics_addr,
 data => sp_graphics3_do
);


--zaxxon_sound_board 
-- sound_board : entity work.tron_sound_board
-- port map(
-- clock_40    => clock_40,
-- reset       => reset,

-- main_cpu_addr => cpu_addr(7 downto 0),

-- ssio_iowe => ssio_iowe,
-- ssio_di   => cpu_do,
-- ssio_do   => ssio_do,

-- input_0 => input_0,
-- input_1 => input_1,
-- input_2 => input_2,
-- input_3 => input_3,
-- input_4 => input_4,

-- separate_audio => separate_audio,
-- audio_out_l    => audio_out_l,
-- audio_out_r    => audio_out_r,

-- dbg_cpu_addr => open --dbg_cpu_addr
-- );

-- char color
char_color: entity work.zaxxon_char_color
port map(
 clk  => clock_vidn,
 addr => ch_color_addr,
 data => ch_color_do
);
 
-- palette
palette : entity work.zaxxon_palette
port map(
 clk  => clock_vidn,
 addr => palette_addr,
 data => palette_do
);

end struct;
