# Next186 SoC DECA port

Adapted from Next186 SoC NeptUNO port by DistWave -- https://github.com/neptuno-fpga/Next186_SoC

Original port https://opencores.org/projects/next186_soc_pc

KEY0 is the reset button.

Tested with:

* PS2 & R2R VGA adapter (333)  https://www.waveshare.com/vga-ps2-board.htm

* 32 MB SDRAM MiSTer module (extra slim) XS_2.2 ([see connections](https://github.com/SoCFPGA-learning/DECA/tree/main/Projects/sdram_mister_deca))

Not tested:

* Audio works though line out 3.5 jack connector.

**Status**:

* **It hangs during boot, or just after loading operating system.**

  

Missing features:

* HDMI Audio & Video output

  

