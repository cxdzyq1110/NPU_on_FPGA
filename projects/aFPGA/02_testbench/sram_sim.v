module sram_sim
(
	// SRAM
	input	[19:0]	SRAM_ADDR,
	inout   [15:0]  SRAM_DQ,
	//		SRAM CONTROL SIGNAL
    input	        SRAM_CE_N,
    input           SRAM_LB_N, SRAM_UB_N,
    input           SRAM_WE_N, SRAM_OE_N
);

	reg		[15:0]	ram_dq	[0:1048576];
	//
	always @(*)
	begin
		if(!SRAM_LB_N & !SRAM_WE_N)
			ram_dq[SRAM_ADDR][7:0] <= SRAM_DQ[7:0];
		if(!SRAM_UB_N & !SRAM_WE_N)
			ram_dq[SRAM_ADDR][15:8] <= SRAM_DQ[15:8];
	end
	//
	assign		SRAM_DQ = (!SRAM_OE_N)? ram_dq[SRAM_ADDR] : 16'HZZZZ;
	
endmodule