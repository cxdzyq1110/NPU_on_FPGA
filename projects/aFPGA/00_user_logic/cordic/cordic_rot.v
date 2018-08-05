//----------------------------------------------------------------------------------------------------------
//	FILE: 		cordic_rot.v
// 	AUTHOR:		Xudong Chen
// 	
//	ABSTRACT:	behavior of the rtl module of atan()/modulus() function based on CORDIC, pipelined
// 	KEYWORDS:	fpga, CORDIC, atan()
// 
// 	MODIFICATION HISTORY:
//	$Log$
//			Xudong Chen		18/5/6		original, implement theta = atan(y/x), rho = \sqrt{x^2+y^2}
//										for theta, [-2^30, 2^30] ==> [-pi, +pi]
//-----------------------------------------------------------------------------------------------------------
// 流水线整型cordic旋转模块，能够输出向量的模 & 角度
module cordic_rot
#(parameter	DATA_WIDTH = 32,    // 数据位宽
  parameter	EPSILON = 3,		// 收敛阈值
  parameter ITERATION = 8,  // 迭代次数
  parameter ROM_LATENCY = 2,	// rom的IP核读取需要延时
  parameter	DATA_ZERO = {DATA_WIDTH{1'B0}}	// 固定的0值
)
(
	input	wire	sys_clk, sys_rst_n,
	input	wire	[DATA_WIDTH-1:0]	src_x,
	input	wire	[DATA_WIDTH-1:0]	src_y,
	
	output	reg		[DATA_WIDTH-1:0]	rho,
    output  reg	    [DATA_WIDTH-1:0]    theta
);

	// 存储Kn的系数表，使用Python脚本来生成相应的数值
	wire	[DATA_WIDTH-1:0]	Kn_THETAn_address;
	wire	[DATA_WIDTH-1:0]	Kn;
	wire	[DATA_WIDTH-1:0]	THETAn;
    cordic_factor_Kn_rom_ip 	Kn_rom_ip_core	(.address(Kn_THETAn_address),.clock(sys_clk),.q({Kn, THETAn}));
	//////////////////////////////////
	
	// 因为要写成流水线型的CORDIC运算
	// 所以需要建立一个巨大的reg阵列
	reg		signed 	[DATA_WIDTH-1:0]	Xn	[0:ITERATION-1];
	reg		signed 	[DATA_WIDTH-1:0]	Yn	[0:ITERATION-1];
	reg									Sn	[0:ITERATION-1];//	用来记录是否进行y-轴对称翻转
	// 迭代次数，因为Yn是可能中途收敛的，需要标注什么时候收敛了
	reg				[DATA_WIDTH-1:0]	Nn	[0:ITERATION-1];	
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
		Yn[n] <= DATA_ZERO;
		Nn[n] <= DATA_ZERO;
		Tn[n] <= DATA_ZERO;
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
	// 首先是校正输入数据进入1/4象限
	Xn[0] <= src_x[DATA_WIDTH-1]? (~src_x+1) : src_x;
	Sn[0] <= src_x[DATA_WIDTH-1];
	Yn[0] <= src_y;
	Nn[0] <= DATA_ZERO;
	Tn[0] <= DATA_ZERO;
	// 然后是cordic迭代的过程，这里使用for循环，方便写程序，注意综合结果
	for(n=ITERATION-1; n>=1; n=n-1)
	begin
		// 如果Yn[n-1]>0，那么顺时针旋转
		if(Yn[n-1]>EPSILON)
		begin
			Xn[n] <= Xn[n-1] + (Yn[n-1]>>>(n-1));
			Yn[n] <= Yn[n-1] - (Xn[n-1]>>>(n-1));
			Nn[n] <= Nn[n-1] + 1;	// 继续迭代，迭代次数+1
			Tn[n] <= Tn[n-1] + T0n[n-1];	// 修改角度值
		end
		// 如果Yn[n-1]<0，那么逆时针旋转
		else if(Yn[n-1]<-EPSILON)
		begin
			Xn[n] <= Xn[n-1] - (Yn[n-1]>>>(n-1));
			Yn[n] <= Yn[n-1] + (Xn[n-1]>>>(n-1));
			Nn[n] <= Nn[n-1] + 1;	// 继续迭代，迭代次数+1
			Tn[n] <= Tn[n-1] - T0n[n-1];	// 修改角度值
		end
		// 否则就说明收敛了，停止迭代过程
		else
		begin
			Xn[n] <= Xn[n-1];
			Yn[n] <= Yn[n-1];
			Nn[n] <= Nn[n-1];
			Tn[n] <= Tn[n-1];
		end
		//
		Sn[n] <= Sn[n-1];
	end
end
endtask
	//////////////////////////////////////////////////
	// 最后，考虑到rom的ip核读取，需要给出ROM的读取地址
	assign	Kn_THETAn_address = rom_address;
	// 然后是校正rho，需要Kn系数
	// 注意到这里的Kn都是0~1的系数，所以我们存的时候，尽管是32bit的signed变量，实际中用到了31-bit
	// 因此，最后输出的时候，需要做一些判断的
	reg		[2*DATA_WIDTH-1:0]	rho_reg;	// 这是校正向量模输出的时候的“暂存变量”，是64-bit的，最后要截掉LSB
	reg		[DATA_WIDTH-1:0]	theta_reg;	// 为了同步rho & theta而设置的register
	always @(posedge sys_clk)
	begin
		if(Nn[ITERATION-1]==0)
			rho_reg <= {Xn[ITERATION-1], DATA_ZERO} >>> 1;		// // 这里有一个bug，之前没有意识到，主要是数据放大时候的bit问题			
		else
			rho_reg <= Xn[ITERATION-1]*K0n[Nn[ITERATION-1]-1];	// 注意！ 这里是时序非常差的地方，要想办法调整
		
		// 如果不涉及Y-axis翻转，直接输出角度
		if(Sn[ITERATION-1]==0)
			theta_reg <= Tn[ITERATION-1];
		else
		begin
			if(Tn[ITERATION-1][DATA_WIDTH-1])	// 需要-pi-theta
				theta_reg <= {1'B1, {(DATA_WIDTH-1){1'B0}}} - Tn[ITERATION-1];
			else					// 需要pi-theta
				theta_reg <= {1'B0, {(DATA_WIDTH-1){1'B1}}} - Tn[ITERATION-1];
		end
		////////
		rho <= rho_reg[2*DATA_WIDTH-1:DATA_WIDTH-1];
		theta <= theta_reg;
	end
	
endmodule
