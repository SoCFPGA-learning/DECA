//-------------------------------------------------------------------------------------------------
// ram commands
//-------------------------------------------------------------------------------------------------

task INHIBIT;
begin
	sdramCs  <= 1'b1;
	sdramRas <= 1'b1;
	sdramCas <= 1'b1;
	sdramWe  <= 1'b1;
	sdramDQM <= 2'b11;
	sdramBA  <= 2'b00;
	sdramA   <= 13'h0000;
end
endtask

task NOP;
begin
	sdramCs  <= 1'b0;
	sdramRas <= 1'b1;
	sdramCas <= 1'b1;
	sdramWe  <= 1'b1;
	sdramDQM <= 2'b11;
	sdramBA  <= 2'b00;
	sdramA   <= 13'h0000;
end
endtask

task REFRESH;
begin
	sdramCs  <= 1'b0;
	sdramRas <= 1'b0;
	sdramCas <= 1'b0;
	sdramWe  <= 1'b1;
	sdramDQM <= 2'b11;
	sdramBA  <= 2'b00;
	sdramA   <= 13'h0000;
end
endtask

task PRECHARGE;
input pca;
begin
	sdramCs  <= 1'b0;
	sdramRas <= 1'b0;
	sdramCas <= 1'b1;
	sdramWe  <= 1'b0;
	sdramDQM <= 2'b11;
	sdramBA  <= 2'b00;
	sdramA   <= { 2'b00, pca, 9'b000000000 };
end
endtask

task LMR;
input[12:0] mode;
begin
	sdramCs  <= 1'b0;
	sdramRas <= 1'b0;
	sdramCas <= 1'b0;
	sdramWe  <= 1'b0;
	sdramDQM <= 2'b11;
	sdramBA  <= 2'b00;
	sdramA   <= mode;
end
endtask

task ACTIVE;
input[ 1:0] ba;
input[12:0] a;
begin
	sdramCs  <= 1'b0;
	sdramRas <= 1'b0;
	sdramCas <= 1'b1;
	sdramWe  <= 1'b1;
	sdramDQM <= 2'b11;
	sdramBA  <= ba;
	sdramA   <= a;
end
endtask

task WRITE;
input[ 1:0] dqm;
input[ 1:0] ba;
input[ 8:0] a;
input pca;
begin
	sdramCs  <= 1'b0;
	sdramRas <= 1'b1;
	sdramCas <= 1'b0;
	sdramWe  <= 1'b0;
	sdramDQM <= dqm;
	sdramBA  <= ba;
	sdramA   <= { 2'b00, pca, 1'b0, a };
end
endtask

task READ;
input[ 1:0] dqm;
input[ 1:0] ba;
input[ 8:0] a;
input pca;
begin
	sdramCs  <= 1'b0;
	sdramRas <= 1'b1;
	sdramCas <= 1'b0;
	sdramWe  <= 1'b1;
	sdramDQM <= dqm;
	sdramBA  <= ba;
	sdramA   <= { 2'b00, pca, 1'b0, a };
end
endtask

//-------------------------------------------------------------------------------------------------
