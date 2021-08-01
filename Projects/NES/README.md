# NES - DECA port 

DECA Top level for NES by Somhic (16/07/21) adapted from DE10_lite port by Dar (https://sourceforge.net/projects/darfpga/files/Software%20VHDL/nes/)

**Features:**

* HDMI video output
  * VGA video output is possible through GPIO
* Line out, HDMI audio output
  * PWM audio is possible through GPIO

**Additional hardware required**:

- SDRAM module. Tested with 32 MB SDRAM board for MiSTer (extra slim) XS_2.2 ([see connections](https://github.com/SoCFPGA-learning/DECA/tree/main/Projects/sdram_mister_deca)).
- PS/2 Keyboard connected to GPIO. See connections below

**Versions**:

- see changelog in top level file nes_deca.sv
- This version is 4.8

**Compiling:**

* Load project  in NES/deca/nes_deca.qpf

* sof file already included in NES/deca/output_files/nes_deca.sof

  

**Keyboard connections:**

* It is needed to connect PS2 keyboard to GPIO P9 connector (next to HDMI connector):
  * P9:11 PS2CLK 
  * P9:12 PS2DAT 

**Others:**

* Button KEY0 is a reset button

### STATUS

* Working

* HDMI video outputs special resolution, so does not work in all monitors.

  

### Keyboard control 

- ESC key loads the OSD which controls NES options and load ROMS
- F1    : start

- F2    : select

- space : A

- ctrl  : B

- arrow up, down, left, right : move



### Additional comments

See comments from DAR original port in top level file nes_deca.sv