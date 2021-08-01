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
//	- Reset NES
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
// DE10-lite Hardware add-on via GPIO
// 
//----------------------
// Keyboard (5.0V / GND)
//----------------------
//	- ps2_clk : gpio pin 40
//	- ps2_data: gpio pin 39
//
//
//  GPIO 5.0V|------------[ 2k ohm]---|
//                                    |
//  GPIO ps2_data|----|---[120 ohm]---|-------------------- PS/2 KBD DATA
//                    |
//  GPIO GND |---|>|--|--|>|---|GPIO 3.3V
//              bat54s  bat54s               GPIO 5.0V|---- PS/2 KBD 5V.0
//
//                                           GPIO GND |---- PS/2 KBD GND
//  GPIO 5.0V|------------[ 2k ohm]---|
//                                    |
//  GPIO ps2_clk |----|---[120 ohm]---|-------------------- PS/2 KBD CLK
//                    |
//  GPIO GND |---|>|--|--|>|---|GPIO 3.3V
//              bat54s  bat54s                          
//
//
//---------------------
// SD Card (3.3V / GND)
//---------------------
// - sd_cs_n : gpio pin 21
// - sd_sclk : gpio pin 23
// - sd_mosi : gpio pin 22
// - sd_miso : gpio pin 24
//
//
//   GPIO sd_cs_n |--------------------- SD CARD CS_N (DAT3)
//   GPIO sd_sclk |--------------------- SD CARD SCLK
//
//   GPIO sd_mosi |---------------|----- SD CARD MOSI (CMD)
//                                |
//   GPIO 3.3V    |---[4.7k ohm]--|
//
// 
//   GPIO sd_miso |---------------|----- SD CARD MISO (DAT)
//                                |
//   GPIO 3.3V    |---[4.7k ohm]--|
//
//
//   GPIO 3.3V    |--------------------- SD CARD 3.3V
//   GPIO GND     |--------------------- SD CARD GND
//
//-------------
// Audio output
//-------------
// - dac_l   : gpio pin  2
// - dac_r   : gpio pin  4
//
//
//  GPIO dac_l |--------|----[2.7k ohm]------------|---- AUDIO LEFT
//                      |                          |
//                      |                         ---
//  GPIO GND   |---|>|--|--|>|---|GPIO 3.3V       --- 10nF
//                bat54s  bat54s                   |
//                                                 |
//  GPIO GND   |-----------------------------------|                
//
//
//  GPIO dac_r |--------|----[2.7k ohm]------------|---- AUDIO RIGHT
//                      |                          |
//                      |                         ---
//  GPIO GND   |---|>|--|--|>|---|GPIO 3.3V       --- 10nF
//                bat54s  bat54s                   |
//                                                 |
//  GPIO GND   |-----------------------------------|---- AUDIO GND
//
//-------------------------
// GPIO Power supply output
//-------------------------
// - GPIO 5.0V : gpio pin 11
// - GPIO 3.3V : gpio pin 29
// - GPIO GND  : gpio pin 12 and 30
//
// ---------------------------------------------------------------------------

