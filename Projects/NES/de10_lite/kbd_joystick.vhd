library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.numeric_std.ALL;

entity Kbd_Joystick is
port (
  Clk           : in std_logic;
  KbdInt        : in std_logic;
  KbdScanCode   : in std_logic_vector(7 downto 0);
  JoyHBCPPFRLDU : out std_logic_vector(9 downto 0);
  Keys_HUA      : out std_logic_vector(2 downto 0)
);
end Kbd_Joystick;

architecture Behavioral of Kbd_Joystick is

signal IsReleased : std_logic;

begin 

process(Clk)
begin
  if rising_edge(Clk) then
  
    if KbdInt = '1' then
      if KbdScanCode = "11110000" then IsReleased <= '1'; else IsReleased <= '0'; end if; 
      if KbdScanCode = "01110101" then JoyHBCPPFRLDU(0) <= not(IsReleased); end if; -- up    arrow : 0x75
      if KbdScanCode = "01110010" then JoyHBCPPFRLDU(1) <= not(IsReleased); end if; -- down  arrow : 0x72
      if KbdScanCode = "01101011" then JoyHBCPPFRLDU(2) <= not(IsReleased); end if; -- left  arrow : 0x6B
      if KbdScanCode = "01110100" then JoyHBCPPFRLDU(3) <= not(IsReleased); end if; -- right arrow : 0x74
      if KbdScanCode = "00101001" then JoyHBCPPFRLDU(4) <= not(IsReleased); end if; -- space : 0x29
      if KbdScanCode = "00000101" then JoyHBCPPFRLDU(5) <= not(IsReleased); end if; -- F1 : 0x05
      if KbdScanCode = "00000110" then JoyHBCPPFRLDU(6) <= not(IsReleased); end if; -- F2 : 0x06
      if KbdScanCode = "00000100" then JoyHBCPPFRLDU(7) <= not(IsReleased); end if; -- F3 : 0x04
      if KbdScanCode = "00010100" then JoyHBCPPFRLDU(8) <= not(IsReleased); end if; -- ctrl : 0x14
      if KbdScanCode = "00011101" then JoyHBCPPFRLDU(9) <= not(IsReleased); end if; -- W    : 0x1D
      if KbdScanCode = "00011100" then Keys_HUA(0)      <= not(IsReleased); end if; -- A    : 0x1C
      if KbdScanCode = "00111100" then Keys_HUA(1)      <= not(IsReleased); end if; -- U    : 0x3C			
      if KbdScanCode = "00110011" then Keys_HUA(2)      <= not(IsReleased); end if; -- H    : 0x33			
    end if;
 
  end if;
end process;

end Behavioral;


