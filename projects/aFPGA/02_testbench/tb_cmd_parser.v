`timescale 10 ns / 10 ns
module tb_cmd_parser;
	
	reg			CLOCK50;
	reg	[3:0]	KEY;
	
	always #1	CLOCK50 <= ~CLOCK50;
	//
	// 例化top顶层模块
	wire	[19:0]		SRAM_ADDR;
	wire	[15:0]		SRAM_DQ;
	wire				SRAM_LB_N,SRAM_UB_N;
	wire				SRAM_WE_N,SRAM_OE_N;
	wire				SRAM_CE_N;
	// top module
	top					top_inst(
							.CLOCK_50(CLOCK50),
							.KEY(KEY),
							// sram
							.SRAM_ADDR(SRAM_ADDR),
							.SRAM_DQ(SRAM_DQ),
							.SRAM_LB_N(SRAM_LB_N),.SRAM_UB_N(SRAM_UB_N),
							.SRAM_WE_N(SRAM_WE_N),.SRAM_OE_N(SRAM_OE_N),
							.SRAM_CE_N(SRAM_CE_N)
						);
	// ssram
	sram_sim			sram_sim_inst(
							.SRAM_ADDR(SRAM_ADDR),
							.SRAM_DQ(SRAM_DQ),
							.SRAM_LB_N(SRAM_LB_N),.SRAM_UB_N(SRAM_UB_N),
							.SRAM_WE_N(SRAM_WE_N),.SRAM_OE_N(SRAM_OE_N),
							.SRAM_CE_N(SRAM_CE_N)
						);
						
task uart_rx_byte(input [7:0] dat);
begin
	#20	top_inst.uart_wr_inst.uart_rtl_inst.ready_x = 10'H000;
	#2	top_inst.uart_wr_inst.uart_rtl_inst.data_recv = dat;
		top_inst.uart_wr_inst.uart_rtl_inst.ready_x = 10'H3E0;
	#2	top_inst.uart_wr_inst.uart_rtl_inst.ready_x = 10'H000;
	#2	top_inst.uart_wr_inst.uart_rtl_inst.ready_x = 10'H000;
end
endtask

	
	initial
	begin
	
		#0			CLOCK50 = 0; KEY = 0;
		#20			KEY = 1;
					uart_rx_byte(8'H6D); 
					uart_rx_byte(8'H73); 
					uart_rx_byte(8'H64); 
					uart_rx_byte(8'H64); 
					uart_rx_byte(8'H72); 
					uart_rx_byte(8'H00); 
					uart_rx_byte(8'H00); 
					uart_rx_byte(8'H00); 
					uart_rx_byte(8'H01); 
					uart_rx_byte(8'H00); 
					uart_rx_byte(8'H00); 
					uart_rx_byte(8'H00); 
					uart_rx_byte(8'H10); 
					uart_rx_byte(8'H00); 
		/// 结束
		#2000		$stop; 
	end
	
endmodule