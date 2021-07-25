# Using DECA's integrated TLV320AIC3254 Audio DAC

The DECA offers high-quality 24-bit audio via the Texas Instruments TLV320AIC3254 audio
CODEC (Encoder/Decoder). This chip on DECA supports, line-in, and line-out ports. One of line-in
inputs is both connected to the FPGA ADC and the audio CODEC ADC, it allows user to
implement audio applications via the MAX 10 build-in ADC. The operational amplifier OPA1612 is
used to make impedance match for the two fanouts from one line-in input. The connection of the
audio circuitry to the FPGA is shown in Figure 3-18, and the associated pin assignment to the
FPGA is listed in Table 3-10. (extract from DECA user manual)

![deca-audio-pins](images/deca-audio-pins.png)

### Resources

* [TLV320AIC3254_datasheet.pdf](datasheets/TLV320AIC3254_datasheet.pdf) 
* [slaa408a_Reference_Guide.pdf](datasheets/slaa408a_Reference_Guide.pdf) 
* [slaa404c_App_Report.pdf](datasheets/slaa404c_App_Report.pdf) 
* [HEX file format](https://www.intel.com/content/www/us/en/programmable/quartushelp/13.0/mergedProjects/reference/glossary/def_hexfile.htm)

### Register configurations

Rename your desired configuration to LOOP.hex.

* I2S serial data routed to line out connector (LOL/R)  
  * [LOOP.LineOut.v1.hex](LOOP.LineOut.v1.hex) ([commented](LOOP.LineOut.v1.explained.txt))
  * [LOOP.LineOut.v2.hex](LOOP.LineOut.v2.hex) ([commented](LOOP.LineOut.v2.explained.txt))
* I2S serial data routed to line out connector (LOL/R)  & EAR pin through MAX10 ADC
  * [LOOP.ear.hex](LOOP.ear.hex)
* Line In routed to Line out connector
  * [LOOP.DECAAUDIO.hex](LOOP.DECAAUDIO.hex) ([commented](LOOP.DECAAUDIO.explained.txt)) 

### Adapting cores with I2S output to work with Audio CODEC

The following implementation uses SPI communication (Max10 master, AIC3254 slave).

The original code comes from "adc_mic" example from [Terasic's Max10 plus board resource CD](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&CategoryNo=218&No=1223&PartNo=4) (It can also be found in this [fm-transmitter project](https://github.com/natanvotre/fm-transmitter/tree/master/src)).

**Add following files to a folder named "audio" inside Quartus project folder**

* [AUDIO_SPI_CTL_RD.v](https://github.com/SoCFPGA-learning/DECA/blob/main/Projects/zx48/deca/AUDIO_SPI_CTL_RD.v) sends configuration registers and its data to the AIC3254

* [SPI_RAM.v](https://github.com/SoCFPGA-learning/DECA/blob/main/Projects/zx48/deca/SPI_RAM.v) loads configuration file "LOOP.hex" to RAM
* [LOOP.hex](LOOP.hex) contains all the register number and data associated for configuring the Audio CODEC. This one uses I2S serial data bus routed to the line out connector (LOL/R). See Register configurations for other examples.

**Modify QSF file**

* Add Verilog files:

```
set_global_assignment -name audio/VERILOG_FILE AUDIO_SPI_CTL_RD.v
set_global_assignment -name audio/VERILOG_FILE SPI_RAM.v
```

* Replace the I2S Pins from the original core with the DECA ones:

  | DECA Pin | Audio CODEC correspondence | Template pin name |
  | -------- | -------------------------- | ----------------- |
  | PIN_P18  | AUDIO_DOUT_MFP2            | ear               |
  | PIN_P14  | AUDIO_MCLK                 | i2sMck            |
  | PIN_R15  | AUDIO_WCLK                 | i2sLr             |
  | PIN_P15  | AUDIO_DIN_MFP1             | i2sD              |
  | PIN_R14  | AUDIO_BCLK                 | i2sSck            |

* Add additional PIN assignments for the rest of AUDIO CODEC pins. Check audio section in this [template.](https://github.com/SoCFPGA-learning/DECA/blob/main/Projects/zx48/deca/zx48.qsf)

**Adapt Top project file**

(following excerpts are extracted from this [example](https://github.com/SoCFPGA-learning/DECA/blob/main/Projects/zx48/deca/zx48.sv))

Add missing ports to top module (you should already have the I2S (+ ear if available) ports):

```verilog
	// Audio DAC DECA
	inout wire 	AUDIO_GPIO_MFP5,
	input wire 	AUDIO_MISO_MFP4,
	inout wire 	AUDIO_RESET_n,
	output wire AUDIO_SCLK_MFP3,
	output wire AUDIO_SCL_SS_n,
	inout wire 	AUDIO_SDA_MOSI,
	output wire AUDIO_SPI_SELECT,
```

In the module code add and adapt this code with your own "reset" signal and a 50 MHz clock (it might work with other frequencies as well):

```verilog
//--RESET DELAY ---  
   reg RESET_DELAY_n;
   reg   [31:0]  DELAY_CNT;   

	always @(negedge reset ) begin 
	if ( reset )  begin 
			RESET_DELAY_n <= 0;
			DELAY_CNT   <= 0;
		end 
	else  begin 
			if ( DELAY_CNT < 32'hfffff  )  
				DELAY_CNT <= DELAY_CNT+1; 
			else 
				RESET_DELAY_n <= 1;
		end
	end
	
// The previous code was in the original Terasic example. I tested without it and it also works. In case you don't want previous block of code just insert the following line:
// assign RESET_DELAY_n = ~reset;


	// Audio DAC DECA Output assignments
    assign AUDIO_GPIO_MFP5  = 1;  // GPIO
    assign AUDIO_SPI_SELECT = 1;  // SPI mode
    assign AUDIO_RESET_n    = RESET_DELAY_n;    

    // AUDIO CODEC SPI CONFIG
    // I2S mode; fs = 48khz; MCLK = 24.567MhZ x 2
    AUDIO_SPI_CTL_RD u1 (
        .iRESET_n(RESET_DELAY_n), 
        .iCLK_50(clock50),	//50Mhz clock
        .oCS_n(AUDIO_SCL_SS_n),   //SPI interface mode chip-select signal
        .oSCLK(AUDIO_SCLK_MFP3),  //SPI serial clock
        .oDIN(AUDIO_SDA_MOSI),    //SPI Serial data output
        .iDOUT(AUDIO_MISO_MFP4)   //SPI serial data input
    );
    
```

The original core already had an I2S module instantiated. You just need to provide to it the I2S signals that output to Deca's Audio Codec (i2sMck, i2sSck, i2sLr, i2sD):

```verilog
i2s I2S
(
	.clock  (clock  ),
	.ldata  (ldata  ),
	.rdata  (rdata  ),
	.mck    (i2sMck ),
	.sck    (i2sSck ),
	.lr     (i2sLr  ),
	.d      (i2sD   )
);
```



### Adapting cores with PWM audio to I2S

If your original core does not have I2S output but just PWM audio, you will have to look at the sound module of the core and get the sample data and adapt it to a 16 bit signal.  

Follows and example in VHDL. The original audio signal was 11 bit long.

```vhdl
-- DECA AUDIO CODEC I2S DATA
i2sMck <= clock_14;
i2sSck <= I2S_SCLK;    --  894,7 kHz  = LRclk * 2 * 16
i2sLr  <= I2S_LRCLK;   --   27,96 kHz
i2sD   <= tx_data;

-- I2S interface audio
-- audio data : 16bits left channel + 16bits right channel 
sample_data <= "00" & audio & "000" & "00" & audio & "000";  
tx_data <= sample_data_reg(audio_bit_cnt) when audio_out = '1' else '0';
 
process(I2S_SCLK)
begin
	if rising_edge(I2S_SCLK) then
		if I2S_LRCLK  = '1' then			
			audio_bit_cnt <= 31;
			sample_data_reg <= sample_data;
			audio_out <= '1';
		else
			if audio_bit_cnt = 0 then
				audio_out <= '0';				
			else
				audio_bit_cnt <= audio_bit_cnt -1;
			end if;
		end if;
  end if;
end process;

```

