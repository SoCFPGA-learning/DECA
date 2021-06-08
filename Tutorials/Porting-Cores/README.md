# Porting cores to DECA board

## Target cores

* [Neptuno FPGA](https://github.com/neptuno-fpga/) 
* DE10-Lite
* [Multicore2](https://gitlab.com/victor.trucco/Multicore_Bitstreams) 
* Mist
* Mister

### Neptuno FPGA

Porting from [Neptuno FPGA](https://github.com/neptuno-fpga/) platform is pretty easy:

* Change FPGA target to Arrow DECA Max10
* Adapt FPGA pinout in .qsf file.  [Check this template.](https://github.com/SoCFPGA-learning/DECA/blob/main/Projects/DECA_Neptuno_board_test/Deca/tld_test_placa_deca_neptuno.qsf)
* No need to adapt clocks
* Adapt Video & Audio  (see below)
* Most cores use 32 MB SDRAM, the same kind of memory used by Mister ([see hack to connect it to DECA board)](https://github.com/SoCFPGA-learning/DECA/tree/main/Projects/sdram_mister_deca)
* Add pins to control SD card level shifter (see below)



### Audio

To be defined.

### Video. HDMI

To be defined.

### Video. Using an VGA adapter

Using an VGA adapter (333)  https://www.waveshare.com/vga-ps2-board.htm

* [VGA conversion from 666 to 333](vga666-333.md)

### SD card 

* Apart from the 4 SPI pins used in most cores to control SD card (miso, mosi, clk, cs), in Deca board you need to add extra pins in the .qsf file to deal with the control of the SD level shifter. [Check this template (MicroSD section). ](https://github.com/SoCFPGA-learning/DECA/blob/main/Projects/DECA_Neptuno_board_test/Deca/tld_test_placa_deca_neptuno.qsf)

* In the top HDL file add those pins as ports of the top module 

```
  output	SD_SEL,
  output	SD_CMD_DIR,
  output	SD_D0_DIR,
  output	SD_D123_DIR,
```

* In the top module code add these assignments to use the SDcard as a normal SPI SD card

  ```
    // MicroSD Card 
    assign SD_SEL = 1'b0;   //0 = 3.3V at sdcard		
    assign SD_CMD_DIR = 1'b1;  // MOSI FPGA output	
    assign SD_D0_DIR = 1'b0;   // MISO FPGA input	
    assign SD_D123_DIR = 1'b1; // CS FPGA output	
    // 
  ```

  