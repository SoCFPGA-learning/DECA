//-------------------------------------------------------------------------------------------------
module scandoubler
//-------------------------------------------------------------------------------------------------
#
(
	parameter HCW = 9,  // horizontal counter width
	parameter RGBW = 18 // rgb width
)
(
	input  wire           clock,

	input  wire           ice,
	input  wire           ihs,
	input  wire           ivs,
	input  wire[RGBW-1:0] irgb,

	input  wire           oce,
	output reg            ohs,
	output wire           ovs,
	output reg [RGBW-1:0] orgb
);
//-------------------------------------------------------------------------------------------------

reg iHSyncDelayed;
wire iHSyncPosedge = !iHSyncDelayed && ihs;
wire iHSyncNegedge = iHSyncDelayed && !ihs;
always @(posedge clock) if(ice) iHSyncDelayed <= ihs;

reg oHSyncDelayed;
wire oHSyncPosedge = !oHSyncDelayed && ihs;
always @(posedge clock) if(ice) oHSyncDelayed <= ihs;

reg iVSyncDelayed;
wire iVSyncNegedge = iVSyncDelayed && ivs;
always @(posedge clock) if(ice) iVSyncDelayed <= ivs;

//-------------------------------------------------------------------------------------------------

reg[HCW-1:0] iHCount;
always @(posedge clock) if(ice) if(iHSyncNegedge) iHCount <= 1'd0; else iHCount <= iHCount+1'd1;

reg[HCW-1:0] iHSyncBegin;
always @(posedge clock) if(ice) if(iHSyncPosedge) iHSyncBegin <= iHCount;

reg[HCW-1:0] iHSyncEnd;
always @(posedge clock) if(ice) if(iHSyncNegedge) iHSyncEnd <= iHCount;

reg line;
always @(posedge clock) if(ice) if(iVSyncNegedge) line <= 0; else if(iHSyncNegedge) line <= ~line;

//-------------------------------------------------------------------------------------------------

reg[HCW-1:0] oHCount;
always @(posedge clock) if(oce) if(oHSyncPosedge) oHCount <= iHSyncEnd; else if(oHCount == iHSyncEnd) oHCount <= 0; else oHCount <= oHCount+1'd1;

//-------------------------------------------------------------------------------------------------

always @(posedge clock) if(oce) if(oHCount == iHSyncBegin) ohs <= 1'b1; else if(oHCount == iHSyncEnd) ohs <= 1'b0;
assign ovs = ivs;

//-------------------------------------------------------------------------------------------------

// Xilinx: set parameter -infer_ramb8 No in XST to avoid PhysDesignRules:2410 warning

reg[RGBW-1:0] buffer[0:(2*2**HCW)-1]; // 2 lines of 2**HCW pixels of RGBW words

always @(posedge clock) if(ice) buffer[{ line, iHCount }] <= irgb;
always @(posedge clock) if(oce) orgb <= buffer[{ ~line, oHCount }];

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
