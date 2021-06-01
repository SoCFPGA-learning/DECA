//-------------------------------------------------------------------------------------------------
module main
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,   // clock 56 MHz

	input  wire       power,   // signals
	input  wire       reset,
	output wire       rfsh,
	input  wire       nmi,
	output wire       map,

	output wire       blank,   // video
	output wire       hsync,
	output wire       vsync,
	output wire       r,
	output wire       g,
	output wire       b,
	output wire       i,

	input  wire       ear,     // audio
	output wire[11:0] laudio,
	output wire[11:0] raudio,

	input  wire       kstb,    // keyboard
	input  wire       make,
	input  wire[ 7:0] code,

	input  wire[ 7:0] joy1,    // joystick
	input  wire[ 7:0] joy2,

	output wire       cs,      // uSD
	output wire       ck,
	input  wire       miso,
	output wire       mosi,

	output wire       ramRd,   // RAM
	output wire       ramWr,
	output wire[ 7:0] ramD,
	input  wire[ 7:0] ramQ,
	output wire[17:0] ramA
);
//-------------------------------------------------------------------------------------------------

reg[3:0] cc;
always @(negedge clock) if(power) cc <= cc+1'd1;

wire pe7M0 = power & ~cc[0] & ~cc[1] &  cc[2];
wire ne7M0 = power & ~cc[0] & ~cc[1] & ~cc[2];

wire pe3M5 = power & ~cc[0] & ~cc[1] & ~cc[2] &  cc[3];
wire ne3M5 = power & ~cc[0] & ~cc[1] & ~cc[2] & ~cc[3];

//-------------------------------------------------------------------------------------------------

reg mreqt23iorqtw3;
always @(posedge clock) if(pc3M5) mreqt23iorqtw3 <= mreq & ioFE;

reg cpuck;
always @(posedge clock) if(ne7M0) cpuck <= !(cpuck && contend);

wire contend = !(vduCn && cpuck && mreqt23iorqtw3 && ((!a[15] && a[14]) || !ioFE));

wire pc3M5 = pe3M5 & contend;
wire nc3M5 = ne3M5 & contend;

//-------------------------------------------------------------------------------------------------

reg mi = 1'b1;
always @(posedge clock) if(pc3M5) mi <= vduI;

wire[ 7:0] d;
wire[ 7:0] q;
wire[15:0] a;

cpu Cpu
(
	.clock  (clock  ),
	.pe     (pc3M5  ),
	.ne     (nc3M5  ),
	.reset  (reset  ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.nmi    (nmi    ),
	.mi     (mi     ),
	.m1     (m1     ),
	.rd     (rd     ),
	.wr     (wr     ),
	.d      (d      ),
	.q      (q      ),
	.a      (a      )
);

//-------------------------------------------------------------------------------------------------

wire[ 7:0] memQ;
wire[ 7:0] vduQ;
wire[12:0] vduA;

memory Memory
(
	.clock  (clock  ),
	.ce     (pc3M5  ),
	.reset  (reset  ),
	.map    (map    ),
	.rfsh   (rfsh   ),
	.mreq   (mreq   ),
	.iorq   (iorq   ),
	.rd     (rd     ),
	.wr     (wr     ),
	.m1     (m1     ),
	.d      (q      ),
	.q      (memQ   ),
	.a      (a      ),
	.vce    (ne7M0  ),
	.vq     (vduQ   ),
	.va     (vduA   ),
	.ramRd  (ramRd  ),
	.ramWr  (ramWr  ),
	.ramD   (ramD   ),
	.ramQ   (ramQ   ),
	.ramA   (ramA   )
);

//-------------------------------------------------------------------------------------------------

reg mic;
reg speaker;
reg[2:0] border;

always @(posedge clock) if(ne7M0) if(!ioFE && !wr) { speaker, mic, border } <= q[4:0];

//-------------------------------------------------------------------------------------------------

wire[7:0] spdQ;
wire[7:4] spdA = a[7:4];

specdrum Specdrum
(
	.clock  (clock  ),
	.ce     (pe3M5  ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.d      (q      ),
	.q      (spdQ   ),
	.a      (spdA   )
);

//-------------------------------------------------------------------------------------------------

wire[7:0] psgA1;
wire[7:0] psgB1;
wire[7:0] psgC1;

wire[7:0] psgA2;
wire[7:0] psgB2;
wire[7:0] psgC2;

wire[ 7: 0] psgQ;
wire[15:14] psgAh = a[15:14];
wire[ 1: 1] psgAl = a[1];

turbosound Turbosound
(
	.clock  (clock  ),
	.ce     (pe3M5  ),
	.reset  (reset  ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.d      (q      ),
	.ah     (psgAh  ),
	.al     (psgAl  ),
	.q      (psgQ   ),
	.a1     (psgA1  ),
	.b1     (psgB1  ),
	.c1     (psgC1  ),
	.a2     (psgA2  ),
	.b2     (psgB2  ),
	.c2     (psgC2  )
);

//-------------------------------------------------------------------------------------------------

wire[7:0] vduFb;

video Video
(
	.clock  (clock  ),
	.ce     (ne7M0  ),
	.border (border ),
	.blank  (blank  ),
	.hsync  (hsync  ),
	.vsync  (vsync  ),
	.r      (r      ),
	.g      (g      ),
	.b      (b      ),
	.i      (i      ),
	.bi     (vduI   ),
	.cn     (vduCn  ),
	.rd     (vduRd  ),
	.d      (vduQ   ),
	.a      (vduA   )
);

//-------------------------------------------------------------------------------------------------

audio Audio
(
	.speaker(speaker),
	.mic    (mic    ),
	.ear    (ear    ),
	.spd    (spdQ   ),
	.a1     (psgA1  ),
	.b1     (psgB1  ),
	.c1     (psgC1  ),
	.a2     (psgA2  ),
	.b2     (psgB2  ),
	.c2     (psgC2  ),
	.laudio (laudio ),
	.raudio (raudio )
);

//-------------------------------------------------------------------------------------------------

wire[4:0] keyQ;
wire[7:0] keyA = a[15:8];

keyboard Keyboard
(
	.clock  (clock  ),
	.ce     (pe7M0  ),
	.kstb   (kstb   ),
	.make   (make   ),
	.code   (code   ),
	.q      (keyQ   ),
	.a      (keyA   )
);

//-------------------------------------------------------------------------------------------------

wire[7:0] usdQ;
wire[7:0] usdA = a[7:0];

usd uSD
(
	.clock  (clock  ),
	.cep    (pe7M0  ),
	.cen    (ne7M0  ),
	.iorq   (iorq   ),
	.wr     (wr     ),
	.rd     (rd     ),
	.d      (q      ),
	.q      (usdQ   ),
	.a      (usdA   ),
	.cs     (cs     ),
	.ck     (ck     ),
	.miso   (miso   ),
	.mosi   (mosi   )
);

//-------------------------------------------------------------------------------------------------

wire ioFE   = !(!iorq && !a[0]);                   // ula
wire ioEB   = !(!iorq && a[7:0] == 8'hEB);         // usd
wire ioDF   = !(!iorq && !a[5]);                   // kempston

wire ioFFFD = !(!iorq && a[15] && a[14] && !a[1]); // psg

assign d
	= !mreq ? memQ

	: !ioFE ? { 1'b1, ear|speaker, 1'b1, keyQ }
	: !ioEB ? usdQ
	: !ioDF ? joy1|joy2

	: !ioFFFD ? psgQ

	: !iorq & vduRd ? vduQ
	: 8'hFF;

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
