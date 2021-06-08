# DECA NeptUNO board test core

Ported from https://github.com/neptuno-fpga/board_test

Tested with PS2 & R2R VGA adapter (333)  https://www.waveshare.com/vga-ps2-board.htm

Tested with 32 MB SDRAM board for MiSTer (extra slim) XS_2.2 ([see connections](https://github.com/SoCFPGA-learning/DECA/tree/main/Projects/sdram_mister_deca))

Sound tested with Atlas (J2:1 left ye, J2:3 right gn)

PS2 mouse tested with Atlas (J5:9 MDAT pk, J5:10 MCLK gy, J5:11 GND bk, +5V USB PS) 



#### Includes

 - SDRAM test

 - ~~Addon SRAM test (1024x16)~~

 - SD slot test

 - ~~Joystick 1 & 2 test (2 buttons for now)~~

 - Sigma delta sound test

 - VGA / RGB PAL & NTSC test

 - Keyboard & mouse tests

   

#### Main changes to the core

* Pin definitions
* [VGA 666 to 333](https://github.com/SoCFPGA-learning/DECA/blob/main/Tutorials/Porting-Cores/vga666-333.md)



#### Screen

![screen](screen.png)



Note: SDRAM test is not stable. Sometimes is Ok others gives error.