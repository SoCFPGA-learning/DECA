//-------------------------------------------------------------------------------------------------
module clock
//-------------------------------------------------------------------------------------------------
(
	input  wire i, // 50.000 MHz
	output wire o  // 56.000 MHz
);
//-------------------------------------------------------------------------------------------------

IBUFG IBufg(.I(i), .O(ci));

DCM_SP #
(
	.CLKIN_PERIOD          (20.000),
	.CLKDV_DIVIDE          ( 2.000),
	.CLKFX_DIVIDE          (25    ),
	.CLKFX_MULTIPLY        (28    )
)
Dcm
(
	.RST                   (1'b0),
	.DSSEN                 (1'b0),
	.PSCLK                 (1'b0),
	.PSEN                  (1'b0),
	.PSINCDEC              (1'b0),
	.CLKIN                 (ci),
	.CLKFB                 (fb),
	.CLK0                  (c0),
	.CLK90                 (),
	.CLK180                (),
	.CLK270                (),
	.CLK2X                 (),
	.CLK2X180              (),
	.CLKFX                 (co),
	.CLKFX180              (),
	.CLKDV                 (),
	.PSDONE                (),
	.STATUS                (),
	.LOCKED                ()
);

BUFG BufgFb(.I(c0), .O(fb));
BUFG BufgCo(.I(co), .O(o));

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
