//-------------------------------------------------------------------------------------------------
module cpu
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       pe,
	input  wire       ne,
	input  wire       reset,
	output wire       rfsh,
	output wire       mreq,
	output wire       iorq,
	input  wire       nmi,
	input  wire       mi,
	output wire       m1,
	output wire       rd,
	output wire       wr,
	input  wire[ 7:0] d,
	output wire[ 7:0] q,
	output wire[15:0] a
);
//-------------------------------------------------------------------------------------------------
T80pa Cpu
(
	.CLK    (clock  ),
	.CEN_p  (pe     ),
	.CEN_n  (ne     ),
	.RESET_n(reset  ),
	.BUSRQ_n(1'b1   ),
	.WAIT_n (1'b1   ),
	.BUSAK_n(       ),
	.HALT_n (       ),
	.RFSH_n (rfsh   ),
	.MREQ_n (mreq   ),
	.IORQ_n (iorq   ),
	.NMI_n  (nmi    ),
	.INT_n  (mi     ),
	.M1_n   (m1     ),
	.RD_n   (rd     ),
	.WR_n   (wr     ),
	.DI     (d      ),
	.DO     (q      ),
	.A      (a      ),
	.OUT0   (1'b0   ),
	.REG    (       ),
	.DIRSet (1'b0   ),
	.DIR    (212'd0 )
);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
