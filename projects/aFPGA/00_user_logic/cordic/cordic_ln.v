//----------------------------------------------------------------------------------------------------------
//	FILE: 		cordic_ln.v
// 	AUTHOR:		Xudong Chen
// 	
//	ABSTRACT:	behavior of the rtl module of ln() function based on CORDIC, pipelined
// 	KEYWORDS:	fpga, CORDIC, ln()
// 
// 	MODIFICATION HISTORY:
//	$Log$
//			Xudong Chen		18/5/6		original, implement ln(r) = p*ln(2) + ln(t), 
//										and for numerical stability, 1/4 < t < 1/2
//			Xudong Chen		18/5/19		对于零输入，要有下限标记								
//-----------------------------------------------------------------------------------------------------------

module cordic_ln
#(	parameter	DATA_WIDTH = 32,    // 数据位宽
	parameter 	FRAC_WIDTH = 16,
	parameter	EPSILON = 3,		// 收敛阈值
	parameter 	ITERATION = 8,  // 迭代次数
	parameter 	ROM_LATENCY = 2,	// rom的IP核读取需要延时
	parameter	DATA_ZERO = {DATA_WIDTH{1'B0}},	// 固定的0值
	parameter	DATA_UNIT = {{(DATA_WIDTH-1){1'B0}}, 1'B1, {FRAC_WIDTH{1'B0}}},	// 固定的1值
	parameter	LN_2 = 32'D45426,	// ln(2)定点化
	parameter	LN_EPS = -2362156	// 近零（np.log(np.finfo(float).eps)*2**16）
)
(
	input	wire								sys_clk, sys_rst_n,
	input	wire	signed	[DATA_WIDTH-1:0]	r,
	output	reg		signed	[DATA_WIDTH-1:0]	ln_r
);
	
	// 存储Kn的系数表，使用Python脚本来生成相应的数值
	wire	[DATA_WIDTH-1:0]	Kn_THETAn_address;
	wire	[DATA_WIDTH-1:0]	Kn;
	wire	[DATA_WIDTH-1:0]	THETAn;
	cordic_factor_exp_rom_ip 	exp_cordic_rom_ip_core	(.address(Kn_THETAn_address),.clock(sys_clk),.q({Kn, THETAn}));
	//////////////////////////////////
	// tanh^-1(a) = 1/2 * ln^-1((1+a)/(1-a)), and if we let 1+a/1-a = b,
	// then we have: tanh^-1((b-1)/(b+1)) = 1/2 * ln(b)
	// 因为要写成流水线型的CORDIC运算
	// 所以需要建立一个巨大的reg阵列
	reg		signed 	[DATA_WIDTH-1:0]	Xn	[0:ITERATION-1];	// 归一化以后的数值，减去1
	reg		signed 	[DATA_WIDTH-1:0]	Yn	[0:ITERATION-1];	// 归一化以后的数值，加上1
	reg		signed 	[DATA_WIDTH-1:0]	Pn	[0:ITERATION-1];	// 左移/右移，归一化模块输入到[1/2, 1]
	reg									LOFn[0:ITERATION];	// 零输入的标记
	// 迭代次数，因为Zn是可能中途收敛的，需要标注什么时候收敛了
	reg				[DATA_WIDTH-1:0]	Nn	[0:ITERATION+1];	// 一个程序的bug，这里的Nn应该继续传递
	// 还要记录旋转的角度
	reg		signed 	[DATA_WIDTH-1:0]	Tn	[0:ITERATION-1];
	reg		signed 	[DATA_WIDTH-1:0]	T0n	[0:ITERATION-1];	// 这是要从ROM里面加载的
	reg		signed 	[DATA_WIDTH-1:0]	K0n	[0:ITERATION-1];	// 这是要从ROM里面加载的
	// 
	reg		[4:0]				cstate;		// 状态计数器
	parameter					IDLE = 0;	// 闲置状态
	parameter					LOAD = 1;	// 加载ROM中的数据
	parameter					COMP = 2;	// 正常的工作/运算阶段
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
		Pn[n] <= DATA_ZERO;
		Nn[n] <= DATA_ZERO;
		Tn[n] <= DATA_ZERO;
		LOFn[n] <= 0;
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
// 现在是重头戏，就是整个cordic迭代过程了
reg		[DATA_WIDTH-1:0]	rx;
always @(posedge sys_clk)
	rx <= r[DATA_WIDTH-1]? (~r+1) : r;
task execute_comp_task;
begin
	// 首先是输入数据
	// 使用casex语句，用面积换时序
	casex(rx)
		32'B1XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 17;
			Xn[0] <= (rx>>>17) + DATA_UNIT;
			Yn[0] <= (rx>>>17) - DATA_UNIT;
		end
		32'B01XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 16;
			Xn[0] <= (rx>>>16) + DATA_UNIT;
			Yn[0] <= (rx>>>16) - DATA_UNIT;
		end
		32'B001XXXXXXXXXXXXXXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 15;
			Xn[0] <= (rx>>>15) + DATA_UNIT;
			Yn[0] <= (rx>>>15) - DATA_UNIT;
		end
		32'B0001XXXXXXXXXXXXXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 14;
			Xn[0] <= (rx>>>14) + DATA_UNIT;
			Yn[0] <= (rx>>>14) - DATA_UNIT;
		end
		32'B00001XXXXXXXXXXXXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 13;
			Xn[0] <= (rx>>>13) + DATA_UNIT;
			Yn[0] <= (rx>>>13) - DATA_UNIT;
		end
		32'B000001XXXXXXXXXXXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 12;
			Xn[0] <= (rx>>>12) + DATA_UNIT;
			Yn[0] <= (rx>>>12) - DATA_UNIT;
		end
		32'B0000001XXXXXXXXXXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 11;
			Xn[0] <= (rx>>>11) + DATA_UNIT;
			Yn[0] <= (rx>>>11) - DATA_UNIT;
		end
		32'B00000001XXXXXXXXXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 10;
			Xn[0] <= (rx>>>10) + DATA_UNIT;
			Yn[0] <= (rx>>>10) - DATA_UNIT;
		end
		32'B000000001XXXXXXXXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 9;
			Xn[0] <= (rx>>>9) + DATA_UNIT;
			Yn[0] <= (rx>>>9) - DATA_UNIT;
		end
		32'B0000000001XXXXXXXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 8;
			Xn[0] <= (rx>>>8) + DATA_UNIT;
			Yn[0] <= (rx>>>8) - DATA_UNIT;
		end
		32'B00000000001XXXXXXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 7;
			Xn[0] <= (rx>>>7) + DATA_UNIT;
			Yn[0] <= (rx>>>7) - DATA_UNIT;
		end
		32'B000000000001XXXXXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 6;
			Xn[0] <= (rx>>>6) + DATA_UNIT;
			Yn[0] <= (rx>>>6) - DATA_UNIT;
		end
		32'B0000000000001XXXXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 5;
			Xn[0] <= (rx>>>5) + DATA_UNIT;
			Yn[0] <= (rx>>>5) - DATA_UNIT;
		end
		32'B00000000000001XXXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 4;
			Xn[0] <= (rx>>>4) + DATA_UNIT;
			Yn[0] <= (rx>>>4) - DATA_UNIT;
		end
		32'B000000000000001XXXXXXXXXXXXXXXXX : begin
			Pn[0] <= 3;
			Xn[0] <= (rx>>>3) + DATA_UNIT;
			Yn[0] <= (rx>>>3) - DATA_UNIT;
		end
		32'B0000000000000001XXXXXXXXXXXXXXXX : begin
			Pn[0] <= 2;
			Xn[0] <= (rx>>>2) + DATA_UNIT;
			Yn[0] <= (rx>>>2) - DATA_UNIT;
		end
		32'B00000000000000001XXXXXXXXXXXXXXX : begin
			Pn[0] <= 1;
			Xn[0] <= (rx>>>1) + DATA_UNIT;
			Yn[0] <= (rx>>>1) - DATA_UNIT;
		end
		32'B000000000000000001XXXXXXXXXXXXXX : begin
			Pn[0] <= 0;
			Xn[0] <= rx + DATA_UNIT;
			Yn[0] <= rx - DATA_UNIT;
		end
		32'B0000000000000000001XXXXXXXXXXXXX : begin
			Pn[0] <= -1;
			Xn[0] <= (rx<<<1) + DATA_UNIT;
			Yn[0] <= (rx<<<1) - DATA_UNIT;
		end
		32'B00000000000000000001XXXXXXXXXXXX : begin
			Pn[0] <= -2;
			Xn[0] <= (rx<<<2) + DATA_UNIT;
			Yn[0] <= (rx<<<2) - DATA_UNIT;
		end
		32'B000000000000000000001XXXXXXXXXXX : begin
			Pn[0] <= -3;
			Xn[0] <= (rx<<<3) + DATA_UNIT;
			Yn[0] <= (rx<<<3) - DATA_UNIT;
		end
		32'B0000000000000000000001XXXXXXXXXX : begin
			Pn[0] <= -4;
			Xn[0] <= (rx<<<4) + DATA_UNIT;
			Yn[0] <= (rx<<<4) - DATA_UNIT;
		end
		32'B00000000000000000000001XXXXXXXXX : begin
			Pn[0] <= -5;
			Xn[0] <= (rx<<<5) + DATA_UNIT;
			Yn[0] <= (rx<<<5) - DATA_UNIT;
		end
		32'B000000000000000000000001XXXXXXXX : begin
			Pn[0] <= -6;
			Xn[0] <= (rx<<<6) + DATA_UNIT;
			Yn[0] <= (rx<<<6) - DATA_UNIT;
		end
		32'B0000000000000000000000001XXXXXXX : begin
			Pn[0] <= -7;
			Xn[0] <= (rx<<<7) + DATA_UNIT;
			Yn[0] <= (rx<<<7) - DATA_UNIT;
		end
		32'B00000000000000000000000001XXXXXX : begin
			Pn[0] <= -8;
			Xn[0] <= (rx<<<8) + DATA_UNIT;
			Yn[0] <= (rx<<<8) - DATA_UNIT;
		end
		32'B000000000000000000000000001XXXXX : begin
			Pn[0] <= -9;
			Xn[0] <= (rx<<<9) + DATA_UNIT;
			Yn[0] <= (rx<<<9) - DATA_UNIT;
		end
		32'B0000000000000000000000000001XXXX : begin
			Pn[0] <= -10;
			Xn[0] <= (rx<<<10) + DATA_UNIT;
			Yn[0] <= (rx<<<10) - DATA_UNIT;
		end
		32'B00000000000000000000000000001XXX : begin
			Pn[0] <= -11;
			Xn[0] <= (rx<<<11) + DATA_UNIT;
			Yn[0] <= (rx<<<11) - DATA_UNIT;
		end
		32'B000000000000000000000000000001XX : begin
			Pn[0] <= -12;
			Xn[0] <= (rx<<<12) + DATA_UNIT;
			Yn[0] <= (rx<<<12) - DATA_UNIT;
		end
		32'B0000000000000000000000000000001X : begin
			Pn[0] <= -13;
			Xn[0] <= (rx<<<13) + DATA_UNIT;
			Yn[0] <= (rx<<<13) - DATA_UNIT;
		end
		32'B00000000000000000000000000000001 : begin
			Pn[0] <= -14;
			Xn[0] <= (rx<<<14) + DATA_UNIT;
			Yn[0] <= (rx<<<14) - DATA_UNIT;
		end
		default: begin
			Pn[0] <= 0;
			Xn[0] <= + DATA_UNIT;
			Yn[0] <= - DATA_UNIT;
		end


	endcase
	//////////////////////////////////
	// 下溢指示?
	LOFn[0] <= (rx==0);
	// 然后N = 0
	Nn[0] <= DATA_ZERO;
	// T=0
	Tn[0] <= DATA_ZERO;
	// 然后是cordic迭代的过程，这里使用for循环，方便写程序，注意综合结果
	for(n=ITERATION-1; n>=1; n=n-1)
	begin
		// 移位情况 Pn 需要不断地移位下去
		Pn[n] <= Pn[n-1];
		LOFn[n] <= LOFn[n-1];
		// 如果Yn[n-1]>0，那么顺时针旋转
		if(Yn[n-1]>EPSILON)
		begin
			Xn[n] <= Xn[n-1] - (Yn[n-1]>>>(n));
			Yn[n] <= Yn[n-1] - (Xn[n-1]>>>(n));
			Nn[n] <= Nn[n-1] + 1;	// 继续迭代，迭代次数+1
			Tn[n] <= Tn[n-1] + T0n[n-1];	// 修改角度值
		end
		// 如果Yn[n-1]<0，那么逆时针旋转
		else if(Yn[n-1]<-EPSILON)
		begin
			Xn[n] <= Xn[n-1] + (Yn[n-1]>>>(n));
			Yn[n] <= Yn[n-1] + (Xn[n-1]>>>(n));
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
	end
	LOFn[ITERATION] <= LOFn[ITERATION-1];
end
endtask
	
	// 最后，考虑到rom的ip核读取，需要给出ROM的读取地址
	assign	Kn_THETAn_address = rom_address;
	// 最后输出
	reg		signed 	[2*DATA_WIDTH-1:0]	bias;// = (Pn[ITERATION-1] * LN_2);
	reg		signed 	[DATA_WIDTH-1:0]	theta;
	always @(posedge sys_clk)
	begin
		bias <= (Pn[ITERATION-1] * LN_2);
		theta <= Tn[ITERATION-1] * 2;
		ln_r <= LOFn[ITERATION]? LN_EPS : (theta + bias);	// 这里对于ln(0)进行了定义 
	end	
	// 为了调试
	wire	signed	[31:0]	P0 = Pn[0];
	wire	signed	[31:0]	X0 = Xn[0];
	wire	signed	[31:0]	Y0 = Yn[0];
	wire	signed	[31:0]	Pf = Pn[ITERATION-1];
	wire	signed	[31:0]	Xf = Xn[ITERATION-1];
	wire	signed	[31:0]	Yf = Yn[ITERATION-1];
	
endmodule