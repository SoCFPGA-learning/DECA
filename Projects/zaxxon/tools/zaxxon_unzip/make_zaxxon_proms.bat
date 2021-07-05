copy /B zaxxon_rom3d.u27 + zaxxon_rom2d.u28 + zaxxon_rom1d.u29 zaxxon_cpu.bin
make_vhdl_prom zaxxon_cpu.bin zaxxon_cpu.vhd

make_vhdl_prom zaxxon_rom14.u68 zaxxon_char_bits_1.vhd
make_vhdl_prom zaxxon_rom15.u69 zaxxon_char_bits_2.vhd

make_vhdl_prom zaxxon_rom6.u113 zaxxon_bg_bits_1.vhd
make_vhdl_prom zaxxon_rom5.u112 zaxxon_bg_bits_2.vhd
make_vhdl_prom zaxxon_rom4.u111 zaxxon_bg_bits_3.vhd

make_vhdl_prom zaxxon_rom11.u77 zaxxon_sp_bits_1.vhd
make_vhdl_prom zaxxon_rom12.u78 zaxxon_sp_bits_2.vhd
make_vhdl_prom zaxxon_rom13.u79 zaxxon_sp_bits_3.vhd

copy /B zaxxon_rom8.u91  + zaxxon_rom7.u90 zaxxon_map_1.bin
copy /B zaxxon_rom10.u93 + zaxxon_rom9.u92 zaxxon_map_2.bin

make_vhdl_prom zaxxon_map_1.bin zaxxon_map_1.vhd
make_vhdl_prom zaxxon_map_2.bin zaxxon_map_2.vhd

rem zaxxon.u98 = mro16.u76
make_vhdl_prom mro16.u76 zaxxon_palette.vhd

make_vhdl_prom zaxxon.u72 zaxxon_char_color.vhd

rem zaxxon_rom3d.u27  CRC 6e2b4a30
rem zaxxon_rom2d.u28  CRC 1c9ea398
rem zaxxon_rom1d.u29  CRC 1c123ef9
rem zaxxon_rom14.u68  CRC 07bf8c52
rem zaxxon_rom15.u69  CRC c215edcb
rem zaxxon_rom6.u113  CRC 6e07bb68
rem zaxxon_rom5.u112  CRC 0a5bce6a
rem zaxxon_rom4.u111  CRC a5bf1465
rem zaxxon_rom11.u77  CRC eaf0dd4b
rem zaxxon_rom12.u78  CRC 1c5369c7
rem zaxxon_rom13.u79  CRC ab4e8a9a
rem zaxxon_rom8.u91   CRC 28d65063
rem zaxxon_rom7.u90   CRC 6284c200
rem zaxxon_rom10.u93  CRC a95e61fd
rem zaxxon_rom9.u92   CRC 7e42691f
rem mro16.u76         CRC 6cc6695b (zaxxon.u98)
rem zaxxon.u72        CRC deaa21f7
