# [REPO TO BE DEPRECATED]

# UPDATES WILL BE POSTED HERE https://github.com/DECAfpga



# Zaxxon DECA port 

DECA port for Zaxxon by Somhic (03/07/21) adapted from DE10_lite port by Dar (https://sourceforge.net/projects/darfpga/files/Software%20VHDL/zaxxon/)

[Read history of Zaxxon Arcade.](https://www.arcade-museum.com/game_detail.php?game_id=12757)

**It does not require SDRAM.**  It requires a PS2 keyboard.

**Versions**:

- v1 initial revision
- v2 added video_vs & video_hs in zaxxon.vhd
- v3 HDMI working. Added video_clk output in zaxxon.vhd

**External requeriments:**

* KEYBOARD: It just needs to connect PS2 keyboard to GPIO connector 
  * P9:11 PS2CLK 
  * P9:12 PS2DAT 

**Others:**

* Button KEY0 is a reset button

### STATUS

* Working
* HDMI video output tested on various monitors (25% users could not see video output)

* No audio possible without adding SDRAM due to the way the original ROM was made.

### Keyboard players inputs :

F1 : Add coin
F2 : Start 1 player
F3 : Start 2 players

SPACE       : fire
RIGHT arrow : move right
LEFT  arrow : move left
UP    arrow : move up
DOWN  arrow : move down

F4 : flip screen (additional feature)
F5 : Service mode ?! (not tested)
F7 : uprigth/cocktail mode (required reset)

Other details : see original README.txt / zaxxon.vhd

---------------------------------
Compiling for DECA
---------------------------------

 - You would need the original MAME ROM files
 - Use tools included to convert ROM files to VHDL (read original README.txt)
 - put the VHDL ROM files (.vhd) into the rtl_dar/proms directory
 - build zaxxon_deca
 - program zaxxon_deca.sof

You can build the project with ROM image embedded in the sof file.
*DO NOT REDISTRIBUTE THESE FILES*

See original [README.txt](README.txt)
------------------------

