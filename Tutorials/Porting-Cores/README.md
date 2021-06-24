# Porting cores to DECA board

See below for target cores and porting from Neptuno FPGA platform.

### Audio through Line out 3.5 jack

* Using DECA's integrated TLV320AIC3254 Audio DAC https://github.com/SoCFPGA-learning/DECA/tree/main/Tutorials/Porting-Cores/AudioCODEC

### Video & Audio through HDMI

For HDMI video only check this [commit.](https://github.com/SoCFPGA-learning/DECA/commit/92364bb4a4172e98cee600806a3487ae718511b1)

It should be as easy as initialize the  ADV7513 chip though I2C and thereafter assign video and audio signals to the IO pins between FPGA and ADV7513.

Data enable signal might not be present in your core but should be easy to adapt following this code:

```
assign oVGA_DE    = ((H_Cont >= (H_SYNC+H_BACK)) && (H_Cont < (H_SYNC+H_BACK+H_ACT))) && ((V_Cont >= (V_SYNC+V_BACK)) && (V_Cont < (V_SYNC+V_BACK+V_ACT))) ? 1'b1:1'b0;
```

HDMI audio not tested yet.

Some useful resources:

* HDMI examples from Terasic CD
* ADV7513-Based Video Generators application note https://www.analog.com/media/en/technical-documentation/application-notes/AN-1270.pdf
* Test for video output using the ADV7513 chip on a de10 nano board  https://github.com/nhasbun/de10nano_vgaHdmi_chip.  Includes programing and reference guide for ADV7513 chip.
* HDMI video (ADV7513) https://github.com/chriz2600/DreamcastHDMI/tree/develop/Core/source/adv7513

### Video using an VGA adapter

Using an VGA adapter (333)  https://www.waveshare.com/vga-ps2-board.htm

* [VGA conversion from 666 to 333](VGA333/README.md)

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

  

## Tips

* Search for a module or signal name in the project code folder

  ```sh
  grep -Rl "module_name" ./
  ```

* If a signal uses PLL and wan't to reduce/increase frequency, don't use a direct clock, use PLL. 

* Regenerate all IPs for the Max10 family


## Troubleshooting

* ALTDDIO_OUT  does not work, change it for "Altera GPIO Lite IP Core"

  Direct instantiation of the ALTDDIO_OUT primitive does not seem to work reliably on the chosen FPGA and/or tool chain (MAX 10). The solution is to generate an IP core with the MegaWizard GPIO Lite Intel FPGA IP using a DDR register output.





## Target cores

* [Neptuno FPGA](https://github.com/neptuno-fpga/) 

* [Multicore2+](https://gitlab.com/victor.trucco/Multicore_Bitstreams) 

* DE10-Lite

* Mist

* Mister

  

## Porting from Neptuno FPGA

Porting from [Neptuno FPGA](https://github.com/neptuno-fpga/) platform is pretty easy with an VGA addon:

* Change FPGA target to Arrow DECA Max10
* Adapt FPGA pinout in .qsf file ([check this template)](https://github.com/SoCFPGA-learning/DECA/blob/main/Projects/DECA_Neptuno_board_test/Deca/tld_test_placa_deca_neptuno.qsf)
* No need to adapt clocks
* Adapt Video & Audio  (see above)
* Most cores use 32 MB SDRAM of the same kind of memory used by Mister modules ([see hack to connect it to DECA board)](https://github.com/SoCFPGA-learning/DECA/tree/main/Projects/sdram_mister_deca)
* Add pins to control SD card level shifter (see above)



