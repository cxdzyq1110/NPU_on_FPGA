`timescale 1 ps / 1 ps
module tb_sdiv;
	
	reg			CLOCK100, CLOCK150, CLOCK65, RESET_N;
	
	always #1	CLOCK100 <= ~CLOCK100;
	always #1	CLOCK150 <= ~CLOCK150;
	always #2	CLOCK65 <= ~CLOCK65;
	//////////////////////////////////////////////////////////////////////
	initial
	begin
	
		#0			CLOCK100 = 0; CLOCK150 = 0; CLOCK65 = 0; RESET_N = 0; 
		#100		RESET_N = 1;
		/// 结束
		#200		$stop;
	end
	///////////////////////////////////////////////////////////////////////
	// 测试除法
	wire	signed	[31:0]	quotient;
	fixed_sdiv		fixed_sdiv_inst(.sys_clk(CLOCK100),.sys_rst_n(RESET_N),.numer(32765),.denom(-100),.quotient(quotient));
	
endmodule