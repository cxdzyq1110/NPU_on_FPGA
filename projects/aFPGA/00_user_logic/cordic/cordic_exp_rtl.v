// 这个模块用于实现exp()指数运算
// 还是基于cordic算法
// Mark: 2018/6/3: 发现存在上溢/下溢的bug！
module cordic_exp_rtl
#(parameter	DATA_WIDTH = 32,    // 数据位宽
  parameter	FRAC_WIDTH = 16,	// 小数部分
  parameter	EPSILON = 16,		// 收敛阈值
  parameter ITERATION = 8,  	// 迭代次数
  parameter ROM_LATENCY = 2,	// rom的IP核读取需要延时
  parameter	DATA_UNIT = {{(DATA_WIDTH-FRAC_WIDTH-1){1'B0}}, 1'B1, {FRAC_WIDTH{1'B0}}}, // 固定的单位1 
  parameter	DATA_ZERO = {DATA_WIDTH{1'B0}},	// 固定的0值
  parameter	DATA_LOF = (FRAC_WIDTH*11)<<(FRAC_WIDTH-4),	// 下溢 ==> 直接返回0  e^-11 ==> 2^-16, 
  parameter	DATA_UOF = ((DATA_WIDTH-FRAC_WIDTH-1)*11)<<(FRAC_WIDTH-4)	// 上溢 ==> 直接返回(2**31-1)  e^10.39 ==> 2^15, 
)
(
	input	wire								sys_clk, sys_rst_n,
	input	wire	signed	[DATA_WIDTH-1:0]	src_x,
	
	output	reg		signed	[DATA_WIDTH-1:0]	rho
);

	// 存储Kn的系数表，使用Python脚本来生成相应的数值
	wire	[DATA_WIDTH-1:0]	Kn_THETAn_address;
	wire	[DATA_WIDTH-1:0]	Kn;
	wire	[DATA_WIDTH-1:0]	THETAn;
	cordic_factor_exp_rom_ip 	exp_cordic_rom_ip_core	(.address(Kn_THETAn_address),.clock(sys_clk),.q({Kn, THETAn}));
	 //////////////////////////////////

	// 因为要写成流水线型的CORDIC运算
	// 所以需要建立一个巨大的reg阵列
	reg		signed 	[DATA_WIDTH-1:0]	Xn	[0:ITERATION-1];	// 因为是流水线，所以需要不断地“移位”迭代输入的x(小数部分)
	reg		signed 	[DATA_WIDTH-1:0]	In	[0:ITERATION-1];	// 因为是流水线，所以需要不断地“移位”迭代输入的x(整数部分)
	reg		signed 	[DATA_WIDTH-1:0]	Zn	[0:ITERATION-1];
	reg									LOFn[0:ITERATION-1];	// 下溢
	reg									UOFn[0:ITERATION+2];	// 上溢
	// 迭代次数，因为Zn是可能中途收敛的，需要标注什么时候收敛了
	reg				[DATA_WIDTH-1:0]	Nn	[0:ITERATION+1];	// 一个程序的bug，这里的Nn应该继续传递
	// 还要记录旋转的角度
	reg		signed 	[DATA_WIDTH-1:0]	Tn	[0:ITERATION-1];
	reg		signed 	[DATA_WIDTH-1:0]	T0n	[0:ITERATION-1];	// 这是要从ROM里面加载的
	reg		signed 	[DATA_WIDTH-1:0]	K0n	[0:ITERATION-1];	// 这是要从ROM里面加载的
	// 
	reg		[4:0]	cstate;	// 状态计数器
	parameter		IDLE = 0;	// 闲置状态
	parameter		LOAD = 1;	// 加载ROM中的数据
	parameter		COMP = 2;	// 正常的工作/运算阶段
	reg		[DATA_WIDTH-1:0]	timer_in_state;	// 每个阶段的计数器
	reg		[DATA_WIDTH-1:0]	rom_address;	// 读取ROM的地址计数器
	// cordic 迭代运算 + 数据输入&1/4象限校正处理
	always @(posedge sys_clk)
		// 初始化
		if(!sys_rst_n)
			init_system_task;
		// 否则就是正常的迭代计算
		else
		begin
			case(cstate)
				IDLE:		prepare_load_task;
				LOAD:		execute_load_task;
				COMP:		execute_comp_task;	
				default:	init_system_task;
			endcase
		end
///////////////////////////////
// 下面是具体的task的描述
integer	n;
// 首先是系统初始化的描述
task init_system_task;
begin
	cstate <= IDLE;	// 首先切换到闲置状态
	// 然后复位所有的寄存器
	for(n=0; n<ITERATION; n=n+1)
	begin
		Xn[n] <= DATA_ZERO;
		Zn[n] <= DATA_ZERO;
		Nn[n] <= DATA_ZERO;
		Tn[n] <= DATA_ZERO;
		//
		LOFn[n] <= 0;
		UOFn[n] <= 0;
	end
	// 计数器复位
	timer_in_state <= DATA_ZERO;
	// 读取rom的地址计数器清零
	rom_address <= 0;
end
endtask
////////////////////
// 然后是IDLE阶段，不直接进入load阶段，
// 主要是因为rom的读取是有latency时间的
task prepare_load_task;
begin	
	// 如果等待够了就要跳出，进入rom数据加载阶段
	if(timer_in_state>=(ROM_LATENCY-1))
	begin
		cstate <= LOAD;
		// 计数器复位
		timer_in_state <= DATA_ZERO;
	end
	// 否则，就要继续加载ROM数据
	else
	begin
		timer_in_state <= timer_in_state+1;
	end
	// rom读取不要停
	rom_address <= rom_address+1;
end
endtask
// 然后是LOAD阶段，执行load指令
task execute_load_task;
begin	
	// 加载够了，就要跳出，可以开始计算了
	if(timer_in_state>=(ITERATION))
	begin
		cstate <= COMP;
		// 计数器复位
		timer_in_state <= DATA_ZERO;
	end
	else
	begin
		// 否则，加载rom里面的数据
		T0n[timer_in_state] <= THETAn;
		K0n[timer_in_state] <= Kn;
		rom_address <= rom_address+1;
		timer_in_state <= timer_in_state+1;
	end
end
endtask
// 现在是重头戏，就是整个coedic迭代过程了
task execute_comp_task;
begin
	// 首先是输入数据
	// 分割数据的整数 - 小数部分
	Xn[0] <= {{(DATA_WIDTH-FRAC_WIDTH){1'B0}}, src_x[FRAC_WIDTH-1:0]};
	In[0] <= (src_x >>> FRAC_WIDTH);
	// 上溢/下溢判别
	LOFn[0] <= src_x < (-DATA_LOF);
	UOFn[0] <= src_x >= (DATA_UOF);
	// 初始化Z = 1
	Zn[0] <= DATA_UNIT;
	// 然后N = 0
	Nn[0] <= DATA_ZERO;
	// T=0
	Tn[0] <= DATA_ZERO;
	// 然后是cordic迭代的过程，这里使用for循环，方便写程序，注意综合结果
	for(n=ITERATION-1; n>=1; n=n-1)
	begin
		// 输入 X & I 需要不断地移位下去
		Xn[n] <= Xn[n-1];
		In[n] <= In[n-1];
		// 如果Tn[n-1]>Xn[n-1]，那么顺时针旋转
		if(Tn[n-1]>(Xn[n-1]+EPSILON))
		begin
			Zn[n] <= Zn[n-1] - (Zn[n-1]>>>(n));
			Nn[n] <= Nn[n-1] + 1;	// 继续迭代，迭代次数+1
			Tn[n] <= Tn[n-1] - T0n[n-1];	// 修改角度值
		end
		// 如果Tn[n-1]<Xn[n-1]，那么逆时针旋转
		else if(Xn[n-1]>(Tn[n-1]+EPSILON))
		begin
			Zn[n] <= Zn[n-1] + (Zn[n-1]>>>(n));
			Nn[n] <= Nn[n-1] + 1;	// 继续迭代，迭代次数+1
			Tn[n] <= Tn[n-1] + T0n[n-1];	// 修改角度值
		end
		// 否则就说明收敛了，停止迭代过程
		else
		begin
			Zn[n] <= Zn[n-1];
			Nn[n] <= Nn[n-1];
			Tn[n] <= Tn[n-1];
		end
		//
		LOFn[n] <= LOFn[n-1];
		UOFn[n] <= UOFn[n-1];
	end
	// Nn还在传递
	Nn[ITERATION] <= Nn[ITERATION-1];
	Nn[ITERATION+1] <= Nn[ITERATION];
	// 上溢指标还在传递
	UOFn[ITERATION] <= UOFn[ITERATION-1];
	UOFn[ITERATION+1] <= UOFn[ITERATION];
	UOFn[ITERATION+2] <= UOFn[ITERATION+1];
end
endtask
	//////////////////////////////////////////////////
	// 最后，考虑到rom的ip核读取，需要给出ROM的读取地址
	assign	Kn_THETAn_address = rom_address;
	// 由于在Kn[]里面寻址 + 输出校正的乘法运算，十分消耗资源，影响时序
	// 所以这里先把各个数据都寄存一下，那么后面的就只是乘法影响时序了
	reg		[DATA_WIDTH-1:0]	Kn_res [0:1];	// 事实证明，这个K0n还不如直接变成ram！
	reg		[DATA_WIDTH-1:0]	Zn_res [0:1];
	reg		[DATA_WIDTH-1:0]	Xn_res [0:1];
	reg		[DATA_WIDTH-1:0]	In_res [0:1];
	always @(posedge sys_clk)
	begin
		Kn_res[0] <= K0n[Nn[ITERATION-1]-1];
		Zn_res[0] <= LOFn[ITERATION-1]? DATA_ZERO : UOFn[ITERATION-1]? {1'B0, {(DATA_WIDTH-1){1'B1}}} : Zn[ITERATION-1];	// 增加上溢/下溢指示
		Xn_res[0] <= Xn[ITERATION-1];
		In_res[0] <= In[ITERATION-1];
		// 为了时序也是拼了
		Kn_res[1] <= Kn_res[0];
		Zn_res[1] <= Zn_res[0];
		Xn_res[1] <= Xn_res[0];
		In_res[1] <= In_res[0];
	end
	// 然后是校正rho，需要Kn系数
	// 注意到这里的Kn都是0~1的系数，所以我们存的时候，尽管是32bit的signed变量，实际中用到了(FRAC_WIDTH)-bit
	// 因此，最后输出的时候，需要做一些判断的
	reg		[2*DATA_WIDTH-1:0]	rho_reg [0:1];	// 这是校正向量模输出的时候的“暂存变量”，是64-bit的，最后要截掉LSB
	reg		[DATA_WIDTH-1:0]	x_reg [0:1];		// 输入向量的移位缓存，为了能够和输出rho进行比对
	// [0] 是没有整数部分时候的数据值， [1]是有整数部分以后的数据值
	wire	[DATA_WIDTH-1:0]	int_part_exp_val;	// 整数部分的 exp 运算结果数据值
	reg		[DATA_WIDTH-1:0]	x;			
	always @(posedge sys_clk)
	begin
		// 如果没有向上溢出
		if(UOFn[ITERATION+1]==0)
		begin
			if(Nn[ITERATION+1]==0)
				rho_reg[0] <= Zn_res[1]*DATA_UNIT;			
			else
				rho_reg[0] <= Zn_res[1]*Kn_res[1];	// 注意！ 这里是时序非常差的地方，要想办法调整
		end
		// 如果向上溢出
		else 
			rho_reg[0] <= {1'B0, {(2*DATA_WIDTH-1){1'B1}}};
		// 
		x_reg[0] <= Xn_res[1]|(In_res[1]<<<FRAC_WIDTH);
		////////
		// 加入整数部分的校正
		x_reg[1] <= x_reg[0];
		// 如果没有向上溢出
		if(UOFn[ITERATION+2]==0)
			rho_reg[1] <= rho_reg[0][2*DATA_WIDTH-1:FRAC_WIDTH]*int_part_exp_val;
		else
			rho_reg[1] <= (1<<(DATA_WIDTH+FRAC_WIDTH-1))-1;
		////////
		rho <= rho_reg[1][DATA_WIDTH+FRAC_WIDTH-1:FRAC_WIDTH];
		x <= x_reg[1];
	end
	// 从ROM里面读出整数部分的指数运算结果	
	cordic_int_part_exp_rom_ip	int_part_mdl(.address(In_res[0]+128), .clock(sys_clk), .q(int_part_exp_val));
endmodule
