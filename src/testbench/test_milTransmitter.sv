`timescale 10 ns/ 1 ns

module test_milTransmitter();
	bit rst, clk, ioClk; 
	bit enable, line, busy, request;
	
	import milStd1553::*;
	
	IPushMil push();
	IPushMilHelper pushHelper(clk, push);
	IMilStd mil();
	
	milTransmitter t(rst, clk, ioClk, enable, push, mil, busy, request);
	
	initial begin
		rst = 1; enable = 1;
		@(posedge clk);
		@(posedge clk);
		rst = 0;
		
		pushHelper.doPush(WCOMMAND, 16'h02A1);
		pushHelper.doPush(WDATA, 16'h02A1);
		
		
	end
	
	always #1 clk = !clk;
	always #100 ioClk = !ioClk;	
	
endmodule