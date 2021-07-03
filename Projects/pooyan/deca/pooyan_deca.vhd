---------------------------------------------------------------------------------
-- DECA Top level for Pooyan by Somhic & Shaeon (27/06/21) adapted 
-- from DE10_lite port by Dar (https://sourceforge.net/projects/darfpga/files/Software%20VHDL/pooyan/)
-- v1 VGA 15 kHz
-- v2 VGA with scandoubler
-- v3 HDMI video  (25.175 Mhz just works on my 'special' monitor, at 1048x224@61)
-- v4 Audio HDMI & Line out
-- v5 HDMI video  (video clock set to 12 MHz for 512x224@61). 
-- v6 Commented VGA and PWM audio.
---------------------------------------------------------------------------------
-- DE10_lite Top level for Pooyan by Dar (darfpga@aol.fr) (29/10/2017)
-- http://darfpga.blogspot.fr
--
-- release rev 02 - (26/04/2020)
--   replace T80 version 247 by version 350: solve arrows collision error
--   fix line count and vblank
--
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
-- Use pooyan_deca.sdc to compile (Timequest constraints)
-- /!\
-- Don't forget to set device configuration mode with memory initialization 
--  (Assignments/Device/Pin options/Configuration mode)
---------------------------------------------------------------------------------
--
-- Board key :
--   0 : reset game
--
-- Keyboard players inputs :
--
--   F3 : Add coin
--   F2 : Start 2 players
--   F1 : Start 1 player
--   SPACE       : Fire  
--   RIGHT arrow : rotate right
--   LEFT  arrow : rotate left
--   UP    arrow : rotate up 
--   DOWN  arrow : rotate down
--
-- Other details : see pooyan.vhd
-- 
---------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

library work;

entity pooyan_deca is
port(
 max10_clk1_50  : in std_logic;

-- ledr           : out std_logic_vector(9 downto 0);

 key            : in std_logic_vector(1 downto 0);

--  vga_r     : out std_logic_vector(2 downto 0);
--  vga_g     : out std_logic_vector(2 downto 0);
--  vga_b     : out std_logic_vector(2 downto 0);
--  vga_hs    : out std_logic;
--  vga_vs    : out std_logic;
 
 ps2clk   : in std_logic;
 ps2dat   : in std_logic;

--  pwm_l    : out std_logic;
--  pwm_r    : out std_logic;

-- HDMI-TX  DECA 
	HDMI_I2C_SCL  : inout std_logic; 		          		
	HDMI_I2C_SDA  : inout std_logic; 		          		
	HDMI_I2S      : inout std_logic_vector(3 downto 0);		     	
	HDMI_LRCLK    : inout std_logic; 		          		
	HDMI_MCLK     : inout std_logic;		          		
	HDMI_SCLK     : inout std_logic; 		          		
	HDMI_TX_CLK   : out	std_logic;	          		
	HDMI_TX_D     : out	std_logic_vector(23 downto 0);	    		
	HDMI_TX_DE    : out std_logic;		          		 
	HDMI_TX_HS    : out	std_logic;	          		
	HDMI_TX_INT   : in  std_logic;		          		
	HDMI_TX_VS    : out std_logic;         

-- AUDIO CODEC  DECA 
  AUDIO_GPIO_MFP5 : inout std_logic;
  AUDIO_MISO_MFP4 : in std_logic;
  AUDIO_RESET_n :  inout std_logic;
  AUDIO_SCLK_MFP3 : out std_logic;
  AUDIO_SCL_SS_n : out std_logic;
  AUDIO_SDA_MOSI : inout std_logic;
  AUDIO_SPI_SELECT : out std_logic;
  i2sMck : out std_logic;
  i2sSck : out std_logic;
  i2sLr : out std_logic;
  i2sD : out std_logic
);
end pooyan_deca;

architecture struct of pooyan_deca is

 signal clock_12  : std_logic;
 signal clock_14  : std_logic;
 signal reset     : std_logic;
 signal clock_6   : std_logic;
  
 signal r         : std_logic_vector(2 downto 0);
 signal g         : std_logic_vector(2 downto 0);
 signal b         : std_logic_vector(1 downto 0);
 signal csync     : std_logic;
 signal blankn    : std_logic;
 signal hsync     : std_logic;   -- mod by somhic
 signal vsync     : std_logic;   -- mod by somhic
 signal audio     : std_logic_vector(10 downto 0);
--  signal pwm_accumulator : std_logic_vector(12 downto 0);

 alias reset_n         : std_logic is key(0);
 alias ps2_clk         : std_logic is ps2clk; 
 alias ps2_dat         : std_logic is ps2dat; 
--  alias pwm_audio_out_l : std_logic is pwm_l;  
--  alias pwm_audio_out_r : std_logic is pwm_r;  
 
 signal kbd_intr      : std_logic;
 signal kbd_scancode  : std_logic_vector(7 downto 0);
 signal joyPCFRLDU : std_logic_vector(7 downto 0);
  
 signal dbg_cpu_addr : std_logic_vector(15 downto 0);

-- video signals   -- mod by somhic
--  signal clock_vga       : std_logic;   
 signal vga_g_i         : std_logic_vector(5 downto 0);   
 signal vga_r_i         : std_logic_vector(5 downto 0);   
 signal vga_b_i         : std_logic_vector(5 downto 0);   
--  signal vga_r_o         : std_logic_vector(5 downto 0);   
--  signal vga_g_o         : std_logic_vector(5 downto 0);   
--  signal vga_b_o         : std_logic_vector(5 downto 0);   

-- signals for I2S output    -- mod by somhic
 signal I2S_SCLK         : std_logic;   
 signal I2S_LRCLK        : std_logic;   
 signal sample_data      : std_logic_vector(31 downto 0); -- audio data : 16bits left channel + 16bits right channel    
 signal tx_data          : std_logic;   
 signal sample_data_reg  : std_logic_vector(31 downto 0);
 signal audio_out        : std_logic := '0';
 signal audio_bit_cnt    : integer range 0 to 31 := 0;

-- component vga_scandoubler is          -- mod by somhic
--    port (
--         clkvideo               : in std_logic;
--         clkvga                 : in std_logic;      -- has to be double of clkvideo
--         enable_scandoubling    : in std_logic;
--         disable_scaneffect     : in std_logic;       
--         ri                : in std_logic_vector( 5 downto 0);
--         gi                : in std_logic_vector( 5 downto 0);
--         bi                : in std_logic_vector( 5 downto 0);
--         hsync_ext_n       : in std_logic;
--         vsync_ext_n       : in std_logic;
--         csync_ext_n       : in std_logic; 
--         ro                : out std_logic_vector( 5 downto 0);
--         go                : out std_logic_vector( 5 downto 0);
--         bo                : out std_logic_vector( 5 downto 0); 
--         hsync             : out std_logic;
--         vsync             : out std_logic
--    );
--    end component;

component I2C_HDMI_Config
    port (
    iCLK : in std_logic;
    iRST_N : in std_logic;
    I2C_SCLK : out std_logic;
    I2C_SDAT : inout std_logic;
    HDMI_TX_INT : in std_logic
  );
end component;

component AUDIO_SPI_CTL_RD
    port (
    iRESET_n : in std_logic;
    iCLK_50 : in std_logic;
    oCS_n : out std_logic;
    oSCLK : out std_logic;
    oDIN : out std_logic;
    iDOUT : in std_logic
  );
end component;

signal RESET_DELAY_n     : std_logic;   

begin

reset <= not reset_n;

-- Clock 12.288MHz for pooyan core, 14.318MHz for sound_board
clocks : entity work.max10_pll_12M_14M
port map(
 inclk0 => max10_clk1_50,
 c0 => clock_12,
 c1 => clock_14,
 locked => open --pll_locked
);

-- Pooyan
pooyan : entity work.pooyan
port map(
 clock_12   => clock_12,
 clock_14   => clock_14,
 reset      => reset,
 
-- tv15Khz_mode => tv15Khz_mode,
 video_r      => r,
 video_g      => g,
 video_b      => b,
 video_csync  => csync,
 video_blankn => blankn,
 video_hs     => hsync,   --mod by somhic
 video_vs     => vsync,   --mod by somhic
 audio_out    => audio,
 
 dip_switch_2 => X"21", -- Sound(8)/Difficulty(7-5)/Bonus(4)/Cocktail(3)/lives(2-1)  --mod by somhic  Shaeon config
-- dip_switch_2 => X"7B", -- Sound(8)/Difficulty(7-5)/Bonus(4)/Cocktail(3)/lives(2-1)  --mod by somhic No Flip screen
-- dip_switch_2 => X"7F", -- Sound(8)/Difficulty(7-5)/Bonus(4)/Cocktail(3)/lives(2-1)
 dip_switch_1 => X"FF", -- Coinage_B / Coinage_A

 start2      => joyPCFRLDU(7),
 start1      => joyPCFRLDU(6),
 coin1       => joyPCFRLDU(5),
 
 fire1       => joyPCFRLDU(4),
 right1      => joyPCFRLDU(3),
 left1       => joyPCFRLDU(2),
 down1       => joyPCFRLDU(1),
 up1         => joyPCFRLDU(0),

 fire2       => joyPCFRLDU(4),
 right2      => joyPCFRLDU(3),
 left2       => joyPCFRLDU(2),
 down2       => joyPCFRLDU(1),
 up2         => joyPCFRLDU(0),

 dbg_cpu_addr => dbg_cpu_addr
);

-- vga scandoubler
-- scandoubler : vga_scandoubler
-- port map(
--   --input
--   clkvideo  => clock_6,
--   clkvga    => clock_12,      -- has to be double of clkvideo
--   enable_scandoubling => '1',
--   disable_scaneffect  => '1',  -- 1 to disable scanlines
--   ri  => vga_r_i,
--   gi  => vga_g_i,
--   bi  => vga_b_i,
--   hsync_ext_n => hsync,
--   vsync_ext_n => vsync,
--   csync_ext_n => csync,
--   --output
--   ro  => vga_r_o,
--   go  => vga_g_o,
--   bo  => vga_b_o,
--   hsync => vga_hs,
--   vsync => vga_vs
-- );

-- adapt video to 6 bits/color only
vga_r_i <= r&"000"  when blankn = '1' else "000000";
vga_g_i <= g&"000"  when blankn = '1' else "000000";
vga_b_i <= b&"0000" when blankn = '1' else "000000";

-- adapt video to 3 bits/color only
-- vga_r <= vga_r_o (5 downto 3);
-- vga_g <= vga_g_o (5 downto 3);
-- vga_b <= vga_b_o (5 downto 3);

-- Clock MHz for video & I2S        -- mod by somhic
clocks2 : entity work.pll    -- check IP components in project navigator
port map(
 inclk0 => max10_clk1_50,
 --c0 => clock_vga,               
 c1 => I2S_SCLK,
 c2 => I2S_LRCLK,
 locked => open --pll_locked
);

-- HDMI CONFIG    -- mod by somhic
I2C_HDMI_Config_inst : I2C_HDMI_Config
  port map (
    iCLK => max10_clk1_50,
    iRST_N => reset_n,
    I2C_SCLK => HDMI_I2C_SCL,
    I2C_SDAT => HDMI_I2C_SDA,
    HDMI_TX_INT => HDMI_TX_INT
  );

--  HDMI VIDEO   -- mod by somhic
HDMI_TX_CLK <= clock_12;    --clock_12 = 512x224@61  /  clock_vga@25.175 Mhz= 1048x224@61 does not work on most monitors
HDMI_TX_DE <= blankn;
HDMI_TX_HS <= hsync;
HDMI_TX_VS <= vsync;
HDMI_TX_D <= vga_r_i&"00"&vga_g_i&"00"&vga_b_i&"00";

--  HDMI AUDIO   -- mod by somhic
HDMI_MCLK <= clock_14;
HDMI_SCLK <= I2S_SCLK;    --  894,7 kHz  = lr*2*16
HDMI_LRCLK <= I2S_LRCLK;   -- 27,96 kHz
HDMI_I2S(0) <= tx_data;

-- I2S interface audio
sample_data <= "00" & audio & "000" & "00" & audio & "000";  -- audio data : 16bits left channel + 16bits right channel 
tx_data <= sample_data_reg(audio_bit_cnt) when audio_out = '1' else '0';
 
-- 3 timing requeriments due to this process
-- Taken from Dar Xevious sgtl5000_dac.vhd
process(I2S_SCLK)
begin
	if rising_edge(I2S_SCLK) then
		if I2S_LRCLK  = '1' then			--0 = Left channel, 1 = Right channel
			audio_bit_cnt <= 31;
			sample_data_reg <= sample_data;
			audio_out <= '1';
		else
			if audio_bit_cnt = 0 then
				audio_out <= '0';				
			else
				audio_bit_cnt <= audio_bit_cnt -1;
			end if;
		end if;
  end if;
end process;


-- DECA AUDIO CODEC

--RESET DELAY ORIGINAL VERILOG CODE 
--WITHOUT THIS CODE AUDIO WORKS FINE, 
--BUT I LEFT IT HERE JUST IN CASE IT IS NEEDED TO BE ADDED (VHDL CONVERSION REQUIRED)
--
-- reg   [31:0]  DELAY_CNT;   
-- assign debugled = RESET_DELAY_n;

-- always @(negedge reset ) begin 
-- if ( reset )  begin 
--     RESET_DELAY_n <= 0;
--     DELAY_CNT   <= 0;
--   end 
-- else  begin 
--     if ( DELAY_CNT < 32'hfffff  )  
--       DELAY_CNT <= DELAY_CNT+1; 
--     else 
--       RESET_DELAY_n <= 1;
--   end
-- end

RESET_DELAY_n <= not reset;

-- Audio DAC DECA Output assignments
AUDIO_GPIO_MFP5  <= '1';  -- GPIO
AUDIO_SPI_SELECT <= '1';  -- SPI mode
AUDIO_RESET_n    <= RESET_DELAY_n;    

-- DECA AUDIO CODEC SPI CONFIG
AUDIO_SPI_CTL_RD_inst : AUDIO_SPI_CTL_RD
  port map (
    iRESET_n => RESET_DELAY_n,
    iCLK_50 => max10_clk1_50,
    oCS_n => AUDIO_SCL_SS_n,
    oSCLK => AUDIO_SCLK_MFP3,
    oDIN => AUDIO_SDA_MOSI,
    iDOUT => AUDIO_MISO_MFP4
  );

-- DECA AUDIO CODEC I2S DATA
i2sMck <= clock_14;
i2sSck <= I2S_SCLK;    --  894,7 kHz  = lr*2*16
i2sLr  <= I2S_LRCLK;   -- 27,96 kHz
i2sD   <= tx_data;


-- get scancode from keyboard
process (reset, clock_12)
begin
	if reset='1' then
		clock_6  <= '0';
	else 
		if rising_edge(clock_12) then
				clock_6  <= not clock_6;
		end if;
	end if;
end process;

keyboard : entity work.io_ps2_keyboard
port map (
  clk       => clock_6, -- synchrounous clock with core
  kbd_clk   => ps2_clk,
  kbd_dat   => ps2_dat,
  interrupt => kbd_intr,
  scancode  => kbd_scancode
);

-- translate scancode to joystick
joystick : entity work.kbd_joystick
port map (
  clk           => clock_6, -- synchrounous clock with core
  kbdint        => kbd_intr,
  kbdscancode   => std_logic_vector(kbd_scancode), 
  joyPCFRLDU => joyPCFRLDU
);

--ledr(8 downto 0) <= joyBCPPFRLDU;

-- pwm sound output
-- process(clock_14)  -- use same clock as pooyan_sound_board
-- begin
--   if rising_edge(clock_14) then
--     pwm_accumulator  <=  std_logic_vector(unsigned('0' & pwm_accumulator(11 downto 0)) + unsigned(audio & "00"));
--   end if;
-- end process;

-- pwm_audio_out_l <= pwm_accumulator(12);
-- pwm_audio_out_r <= pwm_accumulator(12); 

end struct;
