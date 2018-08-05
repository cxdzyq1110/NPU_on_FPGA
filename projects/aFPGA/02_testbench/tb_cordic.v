`timescale 1 ps / 1 ps

module tb_cordic;
	
	reg			CLOCK100, CLOCK150, CLOCK65, RESET_N;
	
	always #1	CLOCK100 <= ~CLOCK100;
	always #1	CLOCK150 <= ~CLOCK150;
	always #2	CLOCK65 <= ~CLOCK65;
	///////////////////////////////////////////////////////////////////////
	// 首先 测试模运算
	wire					sys_clk = CLOCK100;
	wire					sys_rst_n = RESET_N;
	reg				[31:0]	mask;
	always @(posedge sys_clk)
		if(!sys_rst_n)
			mask <= 0;
		else if(mask<=200)
			mask <= mask + 1;
	reg		signed 	[63:0]	r_in_;
	reg						r_in_en_;
	always @(posedge sys_clk)
		if(mask<=200)
		begin
			r_in_ <= -65536*256;
			r_in_en_ <= 0;
		end
		else if(r_in_<65536*20000)
		begin
			r_in_ <= r_in_ + 32768;
			r_in_en_ <= 1;
		end
		else
		begin
			r_in_ <= -65536*20000;
			r_in_en_ <= 1;
		end
	
	
	wire	signed	[31:0]	ln_r_out_;	// 观察波形，ln(x)模块是11个clock的pipeline
	cordic_ln				cordic_ln_mdl(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.r(r_in_),.ln_r(ln_r_out_));
	wire	signed	[31:0]	rho;
	wire	signed	[31:0]	phase;	// 观察波形，rotation模块是10个clock的pipeline
	cordic_rot				cordic_rot_mdl(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.src_x(1024),.src_y(r_in_),.rho(rho),.theta(phase));
	// 验证exp指数运算函数
	wire	signed	[31:0]	rho_exp;
	cordic_exp_rtl			cordic_exp_rtl_inst(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.src_x(r_in_),.rho(rho_exp));
	// 验证sigmoid函数
	wire	signed	[31:0]	rho_tanh_sigmoid;
	cordic_tanh_sigm_rtl	cordic_tanh_sigm_rtl(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.src_x(r_in_), .rho(rho_tanh_sigmoid),.algorithm(2'B10));
	
	///////////////////////////////////////////////////////////////////////////
	// 记录
	reg				[15:0]	r_in_en_shifter;
	reg		signed	[31:0]	r_in_shifter	[0:15];
	integer p;
	always @(posedge sys_clk)
	begin
		r_in_en_shifter <= {r_in_en_shifter[14:0], r_in_en_};
		//
		for(p=1; p<16; p=p+1)
			r_in_shifter[p] <= r_in_shifter[p-1];
		r_in_shifter[0] <= r_in_;
	end
	
	wire	signed	[31:0]	r_in_shifter10 = r_in_shifter[10];
		
	integer	fp_ln;
	always @(posedge sys_clk)
		if(r_in_en_shifter[10])
			$fwrite(fp_ln, "%d, %d\n", r_in_shifter[10], ln_r_out_);
	//////////////////////////////////////////////////////////////////////
	initial
	begin
	
		#0			CLOCK100 = 0; CLOCK150 = 0; CLOCK65 = 0; RESET_N = 0; fp_ln = $fopen("./cordic_ln.txt", "w");
		#100		RESET_N = 1;
		/// 结束
		#1500000	$stop; $fclose(fp_ln);
	end
	
endmodule