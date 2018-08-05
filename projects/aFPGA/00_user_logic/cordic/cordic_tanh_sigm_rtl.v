// 这个模块用于实现tanh()双曲正切运算
// 还是基于cordic算法
module cordic_tanh_sigm_rtl
#(parameter	DATA_WIDTH = 32,    // 数据位宽
  parameter	FRAC_WIDTH = 16,	// 小数部分
  parameter	EPSILON = 16,		// 收敛阈值
  parameter ITERATION = 8,  	// 迭代次数
  parameter ROM_LATENCY = 2,	// rom的IP核读取需要延时
  parameter	DATA_UNIT = {{(DATA_WIDTH-FRAC_WIDTH-1){1'B0}}, 1'B1, {FRAC_WIDTH{1'B0}}}, // 固定的单位1 
  parameter	DATA_ZERO = {DATA_WIDTH{1'B0}}	// 固定的0值
)
(
	input	wire	sys_clk, sys_rst_n,
	input	wire	[DATA_WIDTH-1:0]	src_x,
	
	output	wire	[DATA_WIDTH-1:0]	rho,
	input	wire	[1:0]	algorithm			// 10--tanh, 01--sigmoid
);
	// 需要一个记忆器
	reg		[1:0]	algorithm_reg	[0:ITERATION+4];
	integer			n;
	always @(posedge sys_clk)
		if(!sys_rst_n)
		begin
			for(n=0; n<ITERATION+5; n=n+1)
				algorithm_reg[n] <= 2'B00;
		end
		else
		begin
			for(n=ITERATION+4; n>=1; n=n-1)
				algorithm_reg[n] <= algorithm_reg[n-1];
			
			algorithm_reg[0] <= algorithm;
		end
			
	// 首先要有exp(2x)指数运算的结果
	wire	[31:0]		rho_exp;
	wire	[31:0]		src_x_exp = (algorithm==2'B10)? {src_x[DATA_WIDTH-2:0], 1'B0} : 
									(algorithm==2'B01)? {src_x[DATA_WIDTH-1:0]} : 
									0;
	cordic_exp_rtl		cordic_exp_mdl(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.src_x(src_x_exp), .rho(rho_exp));
	// 然后是除法运算2/(exp(2x)+1)
	wire	[31:0]		rho_div;
	wire	[35:0]		numer_div = (algorithm_reg[ITERATION+4]==2'B10)? {DATA_UNIT, 1'B0} : 
									(algorithm_reg[ITERATION+4]==2'B01)? {DATA_UNIT} : 
									0;
	fixed_sdiv			fixed_sdiv_inst(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.denom((rho_exp+DATA_UNIT)),.numer(numer_div),.quotient(rho_div));
	// 最后输出1-2/(exp(2x)+1)
	assign				rho = DATA_UNIT-rho_div[DATA_WIDTH-1:0];
	
endmodule
