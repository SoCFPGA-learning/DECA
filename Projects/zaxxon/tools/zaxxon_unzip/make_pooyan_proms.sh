cat zaxxon_rom3d.u27 zaxxon_rom2d.u28 zaxxon_rom1d.u29 > zaxxon_cpu.bin
./make_vhdl_prom zaxxon_cpu.bin zaxxon_cpu.vhd
./make_vhdl_prom zaxxon_rom14.u68 zaxxon_char_bits_1.vhd
./make_vhdl_prom zaxxon_rom15.u69 zaxxon_char_bits_2.vhd
./make_vhdl_prom zaxxon_rom6.u113 zaxxon_bg_bits_1.vhd
./make_vhdl_prom zaxxon_rom5.u112 zaxxon_bg_bits_2.vhd
./make_vhdl_prom zaxxon_rom4.u111 zaxxon_bg_bits_3.vhd
./make_vhdl_prom zaxxon_rom11.u77 zaxxon_sp_bits_1.vhd
./make_vhdl_prom zaxxon_rom12.u78 zaxxon_sp_bits_2.vhd
./make_vhdl_prom zaxxon_rom13.u79 zaxxon_sp_bits_3.vhd
cat zaxxon_rom8.u91  zaxxon_rom7.u90 > zaxxon_map_1.bin
cat zaxxon_rom10.u93 zaxxon_rom9.u92 > zaxxon_map_2.bin
./make_vhdl_prom zaxxon_map_1.bin zaxxon_map_1.vhd
./make_vhdl_prom zaxxon_map_2.bin zaxxon_map_2.vhd
#zaxxon.u98 = mro16.u76
./make_vhdl_prom mro16.u76 zaxxon_palette.vhd
./make_vhdl_prom zaxxon.u72 zaxxon_char_color.vhd

