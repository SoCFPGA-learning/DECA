//-------------------------------------------------------------------------------------------------
module video
//-------------------------------------------------------------------------------------------------
(
	input  wire       clock,
	input  wire       ce,

	input  wire[ 2:0] border,
	output wire       blank,
	output wire[ 1:0] sync,
	output wire[23:0] rgb,

	output wire       vrd,
	output wire       vb,
	output wire       vi,
	input  wire[ 7:0] vd,
	output wire[12:0] va

);
//-------------------------------------------------------------------------------------------------

reg[8:0] hCount;
wire hCountReset = hCount >= 447;
always @(posedge clock) if(ce) if(hCountReset) hCount <= 1'd0; else hCount <= hCount+1'd1;

reg[8:0] vCount;
wire vCountReset = vCount >= 311;
always @(posedge clock) if(ce) if(hCountReset) if(vCountReset) vCount <= 1'd0; else vCount <= vCount+1'd1;

reg[4:0] fCount;
always @(posedge clock) if(ce) if(hCountReset) if(vCountReset) fCount <= fCount+5'd1;

//-------------------------------------------------------------------------------------------------

wire hblank = hCount >= 352;
wire vblank = vCount >= 304;

wire hsync = hCount >= 376 && hCount <= 407;
wire vsync = vCount >= 304 && vCount <= 307;

//-------------------------------------------------------------------------------------------------

wire[8:0] hc = hCount >= 32 ? hCount-9'd32 : 9'd416+hCount;
wire[8:0] vc = vCount >= 56 ? vCount-9'd56 : 9'd256+vCount;

//-------------------------------------------------------------------------------------------------

wire dataEnable = hc <= 255 && vc <= 191;

reg videoEnable;
wire videoEnableLoad = hc[3];
always @(posedge clock) if(ce) if(videoEnableLoad) videoEnable <= dataEnable;

//-------------------------------------------------------------------------------------------------

reg[7:0] dataInput;
wire dataInputLoad = (hc[3:0] ==  9 || hc[3:0] == 13) && dataEnable;
always @(posedge clock) if(ce) if(dataInputLoad) dataInput <= vd;

reg[7:0] attrInput;
wire attrInputLoad = (hc[3:0] == 11 || hc[3:0] == 15) && dataEnable;
always @(posedge clock) if(ce) if(attrInputLoad) attrInput <= vd;

reg[7:0] dataOutput;
wire dataOutputLoad = hc[2:0] == 4 && videoEnable;
always @(posedge clock) if(ce) if(dataOutputLoad) dataOutput <= dataInput; else dataOutput <= { dataOutput[6:0], 1'b0 };

reg[7:0] attrOutput;
wire attrOutputLoad = hc[2:0] == 4;
always @(posedge clock) if(ce) if(attrOutputLoad) attrOutput <= { videoEnable ? attrInput[7:3] : { 2'b00, border }, attrInput[2:0] };

//-------------------------------------------------------------------------------------------------

wire dataSelect = dataOutput[7] ^ (fCount[4] & attrOutput[7]);

wire r = dataSelect ? attrOutput[1] : attrOutput[4];
wire g = dataSelect ? attrOutput[2] : attrOutput[5];
wire b = dataSelect ? attrOutput[0] : attrOutput[3];
wire i = attrOutput[6];

reg[23:0] palette[0:15];
initial $readmemh("palette.hex", palette, 0);

//-------------------------------------------------------------------------------------------------

assign vrd = hc[3] && dataEnable;
assign vb = (hc[3] || hc[2]) && dataEnable;
assign vi = !(vc == 248 && hc >= 2 && hc <= 65);
assign va = { !hc[1] ? { vc[7:6], vc[2:0] } : { 3'b110, vc[7:6] }, vc[5:3], hc[7:4], hc[2] };

assign blank = vblank | hblank;
assign sync = { vsync, hsync };
assign rgb = palette[{ i, r, g, b }];

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------
