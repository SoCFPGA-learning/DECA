//-------------------------------------------------------------------------------------------------
module i2s
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire[15:0] ldata,
	input  wire[15:0] rdata,
	output wire       mck,
	output wire       sck,
	output wire       lr,
	output wire       d
);
//-------------------------------------------------------------------------------------------------

reg[9:0] cc;

reg lload;
reg rload;

always @(posedge clock)
begin
	cc <= cc+1'd1;

	lload <= cc >= 10'h00F && cc < 10'h02E;
	rload <= cc >= 10'h20F && cc < 10'h22E;
end

//-------------------------------------------------------------------------------------------------

reg[15:0] sr;
always @(negedge sck) if(lload) sr <= ldata; else if(rload) sr <= rdata; else sr <= { sr[14:0], 1'b0 };

//-------------------------------------------------------------------------------------------------

assign mck = ~cc[ 1]; // DAC master clock (12.5 MHz)
assign sck =  cc[ 4]; // serial data clock (1.56 MHz) also sent to DAC as SCK
assign lr  = ~cc[ 9]; // audio sampling rate (48.8 kHz) also sent to DAC as left/right clock
assign d   =  sr[15]; // serial data to DAC is MSBit of SREG

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
