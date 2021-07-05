# Pooyan DECA port 

DECA port for Pooyan by Somhic (27/06/2021) adapted from DE10_lite by Dar https://sourceforge.net/projects/darfpga/files/Software%20VHDL/pooyan/

[Read history of Pooyan Arcade.](https://www.arcade-museum.com/game_detail.php?letter=&game_id=9082)

**It does not require SDRAM.**  It requires a PS2 keyboard.

**Versions**:

- v1 Original VGA 15 kHz version. Does not work in all monitors.
- v2 Added scandoubler. Now should work in any VGA monitor.
- v3 Added HDMI video output as well.
- v4 Added audio by HDMI and Line out jack
- v5 changed HDMI video clock for compatibility
- v6 commented VGA output and PWM audio

**External requeriments:**

* KEYBOARD: It just needs to connect PS2 keyboard to GPIO connector 
  * P9:11 PS2CLK 
  * P9:12 PS2DAT 

**Others:**

* Button KEY0 is a reset button

### STATUS

* Working
* HDMI video output tested on various monitors (25% users could not see video output)

### Keyboard players inputs :

F1 : Add coin
F2 : Start 1 player
F3 : Start 2 players
SPACE       : Fire  
RIGHT arrow : right
LEFT  arrow : left
UP    arrow : up 
DOWN  arrow : down

Other details : see original README.txt / pooyan.vhd

---------------------------------

Compiling for DECA
---------------------------------

 - you would need the original MAME ROM files
 - use tools included to convert ROM files to VHDL (read original README.txt)
 - put the VHDL ROM files (.vhd) into the rtl_dar/proms directory
 - build pooyan_deca
 - program pooyan_deca.sof

You can build the project with ROM image embedded in the sof file.
*DO NOT REDISTRIBUTE THESE FILES*

See original [README.txt](README.txt)
------------------------

