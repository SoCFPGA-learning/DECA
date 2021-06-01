//-----------------------------------------------------------------------------
//
// Delta-Sigma DAC
//
// $Id: dac.vhd,v 1.1 2006/05/10 20:57:06 arnim Exp $
//
// Refer to Xilinx Application Note XAPP154.
//
// This DAC requires an external RC low-pass filter:
//
//   o 0---XXXXX---+---0 analog audio
//          3k3    |
//                === 4n7
//                 |
//                GND
//
//-----------------------------------------------------------------------------

module dac #
(
	parameter MSBI = 7         // Most significant Bit of DAC input
)
(
	input  wire         clock,
	input  wire         reset,
	input  wire[MSBI:0] d,     // DAC input (excess 2**MSBI)
	output reg          q      // This is the average output that feeds low pass filter
);                             // for optimum performance, ensure that this ff is in IOB

reg[MSBI+2:0] DeltaAdder;      // Output of Delta adder
reg[MSBI+2:0] SigmaAdder;      // Output of Sigma adder
reg[MSBI+2:0] SigmaLatch;      // Latches output of Sigma adder
reg[MSBI+2:0] DeltaB;          // B input of Delta adder

always @(SigmaLatch) DeltaB <= { SigmaLatch[MSBI+2], SigmaLatch[MSBI+2] } << (MSBI+1);
always @(d or DeltaB) DeltaAdder <= d+DeltaB;
always @(DeltaAdder or SigmaLatch) SigmaAdder <= DeltaAdder+SigmaLatch;
always @(posedge clock)
begin
	if(!reset)
	begin
		SigmaLatch <= #1 1'b1 << (MSBI+1);
		q <= #1 1'b0;
	end
	else
	begin
		SigmaLatch <= #1 SigmaAdder;
		q <= #1 SigmaLatch[MSBI+2];
	end
end

endmodule
