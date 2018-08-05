`timescale 10 ns / 10 ns
module tb_npu2;
	
	reg			CLOCK_50;
	reg	[3:0]	KEY;
	
	always #1	CLOCK_50 <= ~CLOCK_50;
	//////////////////////////////////////////////////////////////////////
	////////////////////////////
	wire	[19:0]		SRAM_ADDR;
	wire	[15:0]		SRAM_DQ;
	wire				SRAM_LB_N,SRAM_UB_N;
	wire				SRAM_WE_N,SRAM_OE_N;
	wire				SRAM_CE_N;
	reg		[17:0]		SW;
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
	// 将CNN每条指令的运算结果写入到文本文件中，进行观察
	//
	integer		fp_npu;
	always @(posedge top_inst.npu_inst_fsm_inst.clk)
		if(top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.ddr_write_req && top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.ddr_write_ready)
			//$fwrite(fp_npu, "%08H, %08H\n", top_inst.npu_inst_fsm_inst.ddr_write_addr, top_inst.npu_inst_fsm_inst.ddr_write_data);
			$fwrite(fp_npu, "%d\n", top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.ddr_write_data_signed);
	// 针对卷积中存在的问题，需要将数据导出
	/*
	integer		fp_conv;
	integer		i, j;
	integer		sum, pts;
	always @(posedge top_inst.npu_inst_fsm_inst.clk)
		if(top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.u0_npu_conv_rtl.field_q_en)
		begin
			$fwrite(fp_conv, "----------------------- * * * -----------------------\n");
			for(i=0; i<top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.u0_npu_conv_rtl.Km; i=i+1)
			begin
				for(j=0; j<top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.u0_npu_conv_rtl.Kn; j=j+1)
					$fwrite(fp_conv, "%d ", top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.u0_npu_conv_rtl.field_q[i*top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.u0_npu_conv_rtl.Kn+j]);
				$fwrite(fp_conv, "\n");
			end
			$fwrite(fp_conv, "---- convolution kernel ----\n");
			for(i=0; i<top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.u0_npu_conv_rtl.Km; i=i+1)
			begin
				for(j=0; j<top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.u0_npu_conv_rtl.Kn; j=j+1)
					$fwrite(fp_conv, "%d ", top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.u0_npu_conv_rtl.kernel_q[i*top_inst.npu_inst_fsm_inst.npu_inst_excutor_inst.u0_npu_conv_rtl.Kn+j]);
				$fwrite(fp_conv, "\n");
			end
		end
	
	*/
	/////////////////////////////////////
	integer			fpp;
	reg 	[8:0]	M;//12;
	reg 	[8:0]	N;//32;
	reg 	[31:0]	MODE;//0;
	reg 	[31:0]	AddImm;//1000;
	reg 	[8:0]	MAT_M;//3;
	reg 	[8:0]	MAT_N;//5;
	reg 	[8:0]	MAT_P;//7;
	reg 	[4:0]	Km;//4;
	reg 	[4:0]	Kn;//1;
	reg 	[4:0]	Pm;//2;
	reg 	[4:0]	Pn;//2;
	
	reg		[5:0]	cnt;
	
	task 	restart;
	begin
				top_inst.npu_inst_join_inst.npu_inst = 1;
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
	end
	endtask
	task 	compute;
	begin
				top_inst.npu_inst_join_inst.npu_inst = 0;
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
		#2		top_inst.npu_inst_join_inst.npu_inst = 2;
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
				cnt = cnt + 1;
	end
	endtask
	
	
	initial
	begin
	
		#0			CLOCK_50 = 0; KEY = 0; top_inst.npu_inst_join_inst.npu_inst_en = 0; cnt = 0; SW = 18'H00028;
					$readmemh("../10_python/npu/source_sram_dq.list", sram_sim_inst.ram_dq);
					fpp = $fopen("../10_python/npu/npu_verification_para.list", "r");
		#10			$fscanf(fpp, "%d", M); $display("%d ", M);
		#10			$fscanf(fpp, "%d", N); $display("%d ", N);
		#10			$fscanf(fpp, "%d", AddImm);
		#10			$fscanf(fpp, "%d", MAT_M);
		#10			$fscanf(fpp, "%d", MAT_N);
		#10			$fscanf(fpp, "%d", MAT_P);
		#10			$fscanf(fpp, "%d", Km);
		#10			$fscanf(fpp, "%d", Kn);
		#10			$fscanf(fpp, "%d", Pm);
		#10			$fscanf(fpp, "%d", Pn);
		#10			$fscanf(fpp, "%d", MODE);
		//
		#1000		KEY = 1;
		//#10000000	KEY = 1;
		/**/
		// 测试CNN指令解析器执行卷积函数 -- conv
		#200	restart;
		#2		top_inst.npu_inst_join_inst.npu_inst = {4'H7, 32'H01_0000, 32'H03_0000, 32'H08_0000, M, N, Km, Kn};
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
				fp_npu = $fopen("npu_result-conv.txt", "w");
				//fp_conv = $fopen("./conv_tmp.txt", "w");
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
		#2		compute;
		// 等待指令执行完成
		#2		while(!top_inst.npu_inst_fsm_inst.npu_inst_ready)
				#1	KEY = 1;
		#2		$fclose(fp_npu); //$fclose(fp_conv);
		/**/
		// 测试CNN指令执行的正确性 -- add
		#200	restart;
		#2		top_inst.npu_inst_join_inst.npu_inst = {4'H0, 32'H01_0000, 32'H02_0000, 32'H08_0000, M, N, 10'H000};
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
				fp_npu = $fopen("npu_result-add.txt", "w");
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
		#2		compute;
		// 等待指令执行完成
		#2		while(!top_inst.npu_inst_fsm_inst.npu_inst_ready)
				#1	KEY = 1;
		#2		$fclose(fp_npu);
				
		// 测试CNN指令解析器执行立即数 -- addi
		#200	restart;
		#2		top_inst.npu_inst_join_inst.npu_inst = {4'H1, 32'H01_0000, AddImm, 32'H08_0000, M, N, 10'H000};
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
				fp_npu = $fopen("npu_result-addi.txt", "w");
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
		#2		compute;
		// 等待指令执行完成
		#2		while(!top_inst.npu_inst_fsm_inst.npu_inst_ready)
				#1	KEY = 1;
		#2		$fclose(fp_npu);
		/**/
		
		
		// 测试CNN指令解析器执行激活函数 -- tanh
		#200	restart;
		#2		top_inst.npu_inst_join_inst.npu_inst = {4'HB, 32'H06_0000, 32'H00_0000, 32'H08_0000, M, N, 10'H000};
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
				fp_npu = $fopen("npu_result-tanh.txt", "w");
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
		#2		compute;
		// 等待指令执行完成
		#2		while(!top_inst.npu_inst_fsm_inst.npu_inst_ready)
				#1	KEY = 1;
		#2		$fclose(fp_npu);
		
		// 测试CNN指令解析器执行函数 -- dot
		#200	restart;
		#2		top_inst.npu_inst_join_inst.npu_inst = {4'H6, 32'H01_0000, 32'H02_0000, 32'H08_0000, M, N, 10'H000};
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
				fp_npu = $fopen("npu_result-dot.txt", "w");
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
		#2		compute;
		// 等待指令执行完成
		#2		while(!top_inst.npu_inst_fsm_inst.npu_inst_ready)
				#1	KEY = 1;
		#2		$fclose(fp_npu);
				
				
		
		// 测试CNN指令解析器执行池化函数 -- pool
		#200	restart;
		#2		top_inst.npu_inst_join_inst.npu_inst = {4'H8, 32'H01_0000, MODE, 32'H08_0000, M, N, Pm, Pn};
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
				fp_npu = $fopen("npu_result-pool.txt", "w");
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
		#2		compute;
		// 等待指令执行完成
		#2		while(!top_inst.npu_inst_fsm_inst.npu_inst_ready)
				#1	KEY = 1;
		#2		$fclose(fp_npu);
			
		// 测试CNN指令解析器执行矩阵乘法函数 -- mult
		#200	restart;
		#2		top_inst.npu_inst_join_inst.npu_inst = {4'H4, 32'H04_0000, 32'H05_0000, 32'H08_0000, MAT_M, MAT_N, MAT_P, 1'H0};
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
				fp_npu = $fopen("npu_result-mult.txt", "w");
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
		#2		compute;
		// 等待指令执行完成
		#2		while(!top_inst.npu_inst_fsm_inst.npu_inst_ready)
				#1	KEY = 1;
		#2		$fclose(fp_npu);
				
		// 测试CNN指令解析器执行矩阵转置函数 -- tran
		#200	restart;
		#2		top_inst.npu_inst_join_inst.npu_inst = {4'HD, 32'H01_0000, 32'H00_0000, 32'H08_0000, M, N, 10'H000};
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
				fp_npu = $fopen("npu_result-tran.txt", "w");
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
		#2		compute;
		// 等待指令执行完成
		#2		while(!top_inst.npu_inst_fsm_inst.npu_inst_ready)
				#1	KEY = 1;
		#2		$fclose(fp_npu);
		// 测试CNN指令解析器执行灰度变换函数 -- gray
		#200	restart;
		#2		top_inst.npu_inst_join_inst.npu_inst = {4'HC, 32'H07_0000, 32'H00_0000, 32'H08_0000, M, N, 10'H000};
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
				fp_npu = $fopen("npu_result-gray.txt", "w");
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
		#2		compute;
		// 等待指令执行完成
		#2		while(!top_inst.npu_inst_fsm_inst.npu_inst_ready)
				#1	KEY = 1;
		#2		$fclose(fp_npu);
			
		// 测试CNN指令解析器执行matrix+scalar函数 -- adds
		#200	restart;
		#2		top_inst.npu_inst_join_inst.npu_inst = {4'HE, 32'H01_0000, 32'H06_0000, 32'H08_0000, M, N, 10'H000};
				top_inst.npu_inst_join_inst.npu_inst_en = 1;
				fp_npu = $fopen("npu_result-adds.txt", "w");
		#2		top_inst.npu_inst_join_inst.npu_inst_en = 0;
		#2		compute;
		// 等待指令执行完成
		#2		while(!top_inst.npu_inst_fsm_inst.npu_inst_ready)
				#1	KEY = 1;
		#2		$fclose(fp_npu);
			
		/**/		
				
		
		/// 结束
		#200	$fclose(fpp); $finish;
				
	end
							
endmodule