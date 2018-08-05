`timescale 10 ns / 10 ns
module tb_cnn;
	
	reg			CLOCK_50;
	reg	[3:0]	KEY;
	reg	[17:0]	SW;
	
	always #1	CLOCK_50 <= ~CLOCK_50;
	//////////////////////////////////////////////////////////////////////
	////////////////////////////
	wire	[19:0]		SRAM_ADDR;
	wire	[15:0]		SRAM_DQ;
	wire				SRAM_LB_N,SRAM_UB_N;
	wire				SRAM_WE_N,SRAM_OE_N;
	wire				SRAM_CE_N;
	// top module
	top					top_inst(
							.CLOCK_50(CLOCK_50),
							.KEY(KEY),
							.SW(SW),
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
	
	/////////////////////////////////////
	reg		[127:0]		npu_inst	[0:1023];
	integer				npu_inst_addr;
	
	// 同时记录所有的DDR写入过程
	integer				fp;
	always @(posedge top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.clk)
		if(top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.npu_inst_en)
			$fwrite(fp, "\n");
		else if(top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.ddr_write_data_valid)
			$fwrite(fp, "%d\n", top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.ddr_write_data_signed);
	
	initial
	begin
	
		#0		CLOCK_50 = 0; KEY = 0; top_inst.npu_inst_join_inst.npu_inst_en = 0; npu_inst_addr = 0;
				SW = 18'H00028;	// TEST_MODE
		// 关于CNN的代码
		#100	$readmemh("../../python/keras_cnn/isa-npu/sim_source/sp-5.list", sram_sim_inst.ram_dq);
				$readmemh("../../python/keras_cnn/isa-npu/sim_source/fpga-inst.list", npu_inst);
				fp = $fopen("cnn-result-data_under_test.txt", "w");
		#1000	KEY = 15; 
		// 等待CNN参数配置完成
		#1000	KEY = 9;
		#4		KEY = 15;
		#4		while(!top_inst.cnn_paras_ready)
				#1	KEY = 15;
		/*
        // 复位系统
        #4      top_inst.npu_inst_join_inst.npu_inst = 1;
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
		// 发射指令
		#4		for(npu_inst_addr=0; npu_inst_addr<1024; npu_inst_addr=npu_inst_addr+1)
				begin
					#4		top_inst.npu_inst_join_inst.npu_inst = npu_inst[npu_inst_addr];
							top_inst.npu_inst_join_inst.npu_inst_en = 1;
					#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
				end
		*/
        // 启动计算
        #4      top_inst.npu_inst_join_inst.npu_inst = 2;
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
		// 等待指令执行完成
		#4		while(top_inst.npu_inst_fsm_inst.npu_inst_ready)
				#1	KEY = 15;
		#4		while(!top_inst.npu_inst_fsm_inst.npu_inst_ready)
				#1	KEY = 15;
		#1000	$fclose(fp);		
		
		/// 结束
		#40000	$stop;
	end
							
endmodule