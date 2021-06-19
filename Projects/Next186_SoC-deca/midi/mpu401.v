module mpu401(
	input clk_cpu,
	input clk_sys,
	input reset,
	input cs,
	input wr,
	input addr, 
	input [7:0] din,
	output [7:0] dout,
	output midi_out
	);

	assign dout = cs ? (addr ? {~rxgo, ~txready, 6'b111111} : 8'hFE ) : 8'hZZ;

	reg [7:0] data = 8'h00; 
	reg [7:0] data_d = 8'h00; 
	reg txgo = 1'b0;
	reg rxgo = 1'b0;
	reg ready = 1'b0;
	wire txready;

	simple_uart midi(
		.clk(clk_sys),
		.reset(~reset),
		.txdata(data),
		.txgo(txgo),
		.txready(txready),
		.rxdata(),
		.rxint(),
		.txint(),
		.clock_divisor(16'h0320), // 25 MHz clock
		.txd(midi_out),
		.rxd(1'b0)
	);

	always @(posedge clk_cpu) begin
		if(cs) begin 
			if (wr) begin
				if (addr == 1'b0) begin				// WRITE DATA
					data_d <= din;
					ready <= 1'b1;
				end
				if (addr == 1'b1) begin				// WRITE COMMAND
					if (din == 8'hFF) begin
					rxgo <= 1'b1;
					end
				end
			end else begin 
				if (addr == 1'b0) begin 			// READ DATA
					rxgo <= 1'b0;
				end 
			end
		end
		else if (txgo == 1'b1) ready <= 1'b0;
	end

	always @(posedge clk_sys) begin
		if (ready == 1'b1) begin
			data <= data_d;
			txgo <= 1'b1;
		end
		else begin
			txgo <= 1'b0;
		end
	end

endmodule
