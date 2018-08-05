//----------------------------------------------------------------------------------------------------------
//	FILE: 		npu_inst_excutor.v
// 	AUTHOR:		Xudong Chen
// 	
//	ABSTRACT:	behavior of the rtl module of ISA-NPU
// 	KEYWORDS:	fpga, ISA, NPU
// 
// 	MODIFICATION HISTORY:
//	$Log$
//			Xudong Chen		18/3/9		original, 验证了CONV指令的正确性，增加TRAN函数
//										CNN模块的资源占用如下:ALM：3631.8 / M10K：19 / DSP：46 / Fmax：54.67 MHz
//										Cyclone V series, SoC FPGA
//			Xudong Chen		18/3/10		为了证明CNN指令集架构计算的正确性，写了相应的python/matlab代码
//			Xudong Chen		18/3/13		修正了CNN的指令集架构，使得运算结果回写DDR的时候速度提升100%
//										CNN模块的资源占用如下:ALM：3487.9 / M10K：25 / DSP：42 / Fmax：71.21 MHz
//			Xudong Chen		18/5/16		$1的FIFO输出到$3的输入时序不佳（估计是通过某个组合逻辑直连了，这里修正一下）
//										使用自己写的流水线除法器，并在Cyclone IV系列芯片上实现
//										LE：16.4 K	/ M9K：18 / DSP：110 / Fmax：> 50 Mhz
//			Xudong Chen		18/5/24		将CNN改成了NPU，更接近这个模块的本质
//			Xudong			18/7/16		把内部的ram/fifo使用自己的module进行替换
//			Xudong			18/7/26		将卷积运算通过module单独例化
//-----------------------------------------------------------------------------------------------------------
// CNN指令集架构的解析器
module npu_inst_excutor
#(parameter	DATA_WIDTH = 32,    // 数据位宽
  parameter	FRAC_WIDTH = 16,	// 小数部分
  parameter RAM_LATENCY = 2,	// ram的IP核读取需要延时
  parameter MAC_LATENCY = 2,	// ram的IP核读取需要延时
  parameter	DIV_LATENCY = 50,	// 除法器的延时
  parameter	DMI_LATENCY = 2,	// 除法器的延时
  parameter	DATA_UNIT = {{(DATA_WIDTH-FRAC_WIDTH-1){1'B0}}, 1'B1, {FRAC_WIDTH{1'B0}}}, // 固定的单位1 
  parameter	DATA_ZERO = {DATA_WIDTH{1'B0}},	// 固定的0值
  parameter	INST_WIDTH = 128	// 指令的长度
)
(
	input	wire						clk, rst_n,	// 时钟和复位信号
	input	wire	[INST_WIDTH-1:0]	npu_inst,	// CNN的指令
	input	wire						npu_inst_en,	// 指令使能标志
	output	reg							npu_inst_ready,	// 指令执行完成标志
	output	reg		[DATA_WIDTH-1:0]	npu_inst_time,	// 计量指令执行时间
	// DDR接口
	output	wire						DDR_WRITE_CLK,
	output	wire	[DATA_WIDTH-1:0]	DDR_WRITE_ADDR,
	output	wire	[DATA_WIDTH-1:0]	DDR_WRITE_DATA,
	output	wire						DDR_WRITE_REQ,
	input	wire						DDR_WRITE_READY,
	output	wire						DDR_READ_CLK,
	output	wire	[DATA_WIDTH-1:0]	DDR_READ_ADDR,
	output	wire						DDR_READ_REQ,
	input	wire						DDR_READ_READY,
	input	wire	[DATA_WIDTH-1:0]	DDR_READ_DATA,
	input	wire						DDR_READ_DATA_VALID
);
	
	// ddr的读写接口
	reg		[31:0]	ddr_read_addr;
	reg				ddr_read_req;
	wire			ddr_read_ready;
	wire	[31:0]	ddr_read_data;
	wire			ddr_read_data_valid;
	reg		[31:0]	ddr_write_addr;
	wire			ddr_write_req;
	wire			ddr_write_ready;
	wire	[31:0]	ddr_write_data;
	///////////
	assign			DDR_WRITE_CLK = clk;
	assign			DDR_WRITE_ADDR = ddr_write_addr;
	assign			DDR_WRITE_DATA = ddr_write_data;
	assign			DDR_WRITE_REQ = ddr_write_req;
	assign			ddr_write_ready = DDR_WRITE_READY;
	
	wire			ddr_write_data_valid = ddr_write_ready && ddr_write_req;	// 表示一次数据成功写入
	//
	assign			DDR_READ_CLK = clk;
	assign			DDR_READ_ADDR = ddr_read_addr;
	assign			DDR_READ_REQ = ddr_read_req;
	assign			ddr_read_ready = DDR_READ_READY;
	assign			ddr_read_data = DDR_READ_DATA;
	assign			ddr_read_data_valid = DDR_READ_DATA_VALID;
	
	//
	reg		[31:0]	ddr_write_row;	// 计量DDR回写时候的行计数
	reg		[31:0]	ddr_write_col;	// 计量DDR回写时候的列计数
	
	///////////////
	
/* CNN指令集架构的指令表

	[127:124][123:92][91:60][59:28][27:0]
		OP 		$1		$2		$3		MNPK
		指令名	地址	地址	地址	参数
ADD		0		$1		$2		$3		M/N/0/0		==> $3 = $1+$2
ADDi	1		$1		i		$3		M/N/0/0		==> $3 = $1+i
SUB		2		$1		$2		$3		M/N/0/0		==> $3 = $1-$2
SUBi	3		$1		i		$3		M/N/0/0		==> $3 = $1-i
MULT	4		$1		$2		$3		M/N/P/0		==> $3 = $1x$2
MULTi	5		$1		i		$3		M/N/0/0		==> $3 = $1xi
DOT		6		$1		$2		$3		M/N/0/0		==> $3 = $1.$2
CONV	7		$1		$2		$3		M/N/Km/Kn	==> $3 = $1*$2
POOL	8		$1		mode	$3		M/N/Pm/Pn	==> $3 = pooling($1)	// mode = max/mean
SIGM	9		$1		xx		$3		M/N/0/0		==> $3 = sigmoid($1)
RELU	10		$1		xx		$3		M/N/0/0		==> $3 = ReLU($1)
TANH	11		$1		xx		$3		M/N/0/0		==> $3 = tanh($1)
GRAY	12		$1		xx		$3		M/N/0/0		==> $3 = gray($1)	// RGB565-->灰度图
TRAN	13		$1		xx		$3		M/N/0/0		==> $3 = tran($1)	// 
ADDs	14		$1		$2		$3		M/N/0/0		==> $3 = $1 + $2 x ones(M, N)	// 进行矩阵matrix和标量scalar的加法
SUBs	15		$1		$2		$3		M/N/0/0		==> $3 = $1 - $2 x ones(M, N)	// 进行矩阵matrix和标量scalar的减法
*/
	parameter		ADD = 0;		// 加法
	parameter		ADDi = 1;		// 立即数加法
	parameter		SUB = 2;		// 减法
	parameter		SUBi = 3;		// 立即数减法
	parameter		MULT = 4;		// 乘法
	parameter		MULTi = 5;		// 立即数乘法
	parameter		DOT = 6;		// 矩阵点乘
	parameter		CONV = 7;		// 2D卷积
	parameter		POOL = 8;		// 2D池化
	parameter		SIGM = 9;		// sigmoid函数
	parameter		RELU = 10;		// ReLU函数
	parameter		TANH = 11;		// tanh函数
	parameter		GRAY = 12;		// RGB--灰度图转换
	parameter		TRAN = 13;		// 转置
	parameter		ADDs = 14;		// 矩阵+标量
	parameter		SUBs = 15;		// 矩阵-标量

	reg		[3:0]	OP;	// 指令名
	reg		[31:0]	Dollar1;	// 参数1
	reg		[31:0]	Dollar2;	// 参数2
	reg		[31:0]	Dollar3;	// 参数3
	reg		[8:0]	M;	// 参数1的行尺寸
	reg		[8:0]	N;	// 参数1的列尺寸	/ 参数2的行尺寸
	reg		[8:0]	P;	// 参数2的列尺寸
	reg		[4:0]	Km, Kn;	// 卷积核的行列尺寸
	reg		[4:0]	Pm, Pn;	// 池化核的行列尺寸
	reg		[127:0]	OP_EN;	// 一长串OP使能链
	//
	reg		[31:0]	IMM;	// 立即数
	reg		[31:0]	MODE;	// POOL池化的模式：平均[0] / maxpool[1]
	reg		signed	[31:0]	SCALAR;	// 读取到的$2标量
	// 加载CNN的指令
	always @(posedge clk)
	begin
		OP_EN <= {OP_EN[126:0], npu_inst_en};
		if(npu_inst_en)
		begin
			OP <= npu_inst[127:124];
			Dollar1 <= npu_inst[123:92];
			Dollar2 <= npu_inst[91:60];
			Dollar3 <= npu_inst[59:28];
			M <= npu_inst[27:19];
			N <= npu_inst[18:10];
			P <= npu_inst[9:1];
			Km <= npu_inst[9:5];
			Kn <= npu_inst[4:0];
			Pm <= npu_inst[9:5];
			Pn <= npu_inst[4:0];
			IMM <= npu_inst[91:60];
			MODE <= npu_inst[91:60];	
		end
	end
	
	// 三段数据缓存	// 之所以要缓存下$1/$2一行的数据，是考虑到DDR的读写（连续地址可以burst，很快）
	// 之所以要缓存  $3的数据，是因为DDR的写入有延时
	wire	[31:0]		npu_scfifo_Dollar1_q;
	wire				npu_scfifo_Dollar1_rdreq;
	wire				npu_scfifo_Dollar1_rdempty;
	wire	[8:0]		npu_scfifo_Dollar1_rdusedw;
	wire	[31:0]		npu_scfifo_Dollar1_data;
	wire				npu_scfifo_Dollar1_wrreq;
	wire	[31:0]		npu_scfifo_Dollar2_q;
	reg					npu_scfifo_Dollar2_rdreq;
	wire				npu_scfifo_Dollar2_rdempty;
	wire	[8:0]		npu_scfifo_Dollar2_rdusedw;
	wire	[31:0]		npu_scfifo_Dollar2_data;
	wire				npu_scfifo_Dollar2_wrreq;
	wire	[31:0]		npu_scfifo_Dollar3_q;
	wire				npu_scfifo_Dollar3_rdreq;
	wire				npu_scfifo_Dollar3_rdempty;
	wire	[8:0]		npu_scfifo_Dollar3_rdusedw;
	// $1的FIFO输出到$3的输入时序不佳（估计是通过某个组合逻辑直连了，这里修正一下）
	// 使用寄存器打断一下链路
	reg		[31:0]		npu_scfifo_Dollar3_data;
	reg					npu_scfifo_Dollar3_wrreq;
	sc_fifo				#(
							.LOG2N(9),
							.DATA_WIDTH(DATA_WIDTH)
						)
						npu_scfifo_Dollar1(
							.aclr(!rst_n),
							.clock(clk),
							.data(npu_scfifo_Dollar1_data),
							.rdreq(npu_scfifo_Dollar1_rdreq),
							.wrreq(npu_scfifo_Dollar1_wrreq),
							.empty(npu_scfifo_Dollar1_rdempty),
							.full(),
							.q(npu_scfifo_Dollar1_q),
							.usedw(npu_scfifo_Dollar1_rdusedw)
						);
	sc_fifo				#(
							.LOG2N(9),
							.DATA_WIDTH(DATA_WIDTH)
						)
						npu_scfifo_Dollar2(
							.aclr(!rst_n),
							.clock(clk),
							.data(npu_scfifo_Dollar2_data),
							.rdreq(npu_scfifo_Dollar2_rdreq),
							.wrreq(npu_scfifo_Dollar2_wrreq),
							.empty(npu_scfifo_Dollar2_rdempty),
							.full(),
							.q(npu_scfifo_Dollar2_q),
							.usedw(npu_scfifo_Dollar2_rdusedw)
						);
	sc_fifo				#(
							.LOG2N(9),
							.DATA_WIDTH(DATA_WIDTH)
						)
						npu_scfifo_Dollar3(
							.aclr(!rst_n),
							.clock(clk),
							.data(npu_scfifo_Dollar3_data),
							.rdreq(npu_scfifo_Dollar3_rdreq),
							.wrreq(npu_scfifo_Dollar3_wrreq),
							.empty(npu_scfifo_Dollar3_rdempty),
							.full(),
							.q(npu_scfifo_Dollar3_q),
							.usedw(npu_scfifo_Dollar3_rdusedw)
						);
						
	//////////////////////////////////////////////////////////////////////////////////					
	// 使用FSM控制CNN的计算
	reg		[5:0]	cstate;
	reg		[5:0]	substate;
	reg		[5:0]	delay;
	reg		[31:0]	GPC0;	// 通用计数器 -- general proposal counter
	reg		[31:0]	GPC1;	// 通用计数器 -- general proposal counter
	reg		[31:0]	GPC2;	// 通用计数器 -- general proposal counter
	reg		[31:0]	GPC3;	// 通用计数器 -- general proposal counter
	reg		[31:0]	GPC4;	// 通用计数器 -- general proposal counter
	reg		[31:0]	GPC5;	// 通用计数器 -- general proposal counter
	parameter		IDLE = 0;	// 空闲状态
	parameter		ExADD = 1;	// 执行加法
	parameter		ExADDi = 2;	// 执行立即数加法
	parameter		ExSUB = 3;	// 执行减法
	parameter		ExSUBi = 4;	// 执行立即数减法
	parameter		ExMulti = 5;	// 执行立即数乘法
	parameter		ExMult = 6;	// 执行矩阵乘法
	parameter		ExDOT = 7;	// 执行矩阵点乘运算
	parameter		ExConv = 8;	// 执行卷机操作
	parameter		ExPool = 9;	// 执行池化pooling操作
	parameter		ExReLU = 11;	// 执行ReLU激活函数
	parameter		ExSigmoid = 10;	// 执行sigmoid激活函数
	parameter		ExTanh = 12;	// 执行tanh激活函数
	parameter		ExTran = 14;	// 执行矩阵转置函数
	parameter		ExGray = 13;	// 执行灰度图转换函数
	parameter		ExADDs = 15;	// 执行矩阵+标量的函数
	parameter		ExSUBs = 16;	// 执行矩阵-标量的函数
	always @(posedge clk)
		if(!rst_n)
			reset_system_task;
		else
		begin
			case(cstate)
				// 闲置状态
				IDLE: begin
					idle_task;
				end
				
				// 加法
				ExADD: begin
					ex_add_sub_task;
				end
				
				// 减法
				ExSUB: begin
					ex_add_sub_task;
				end
				
				// 加上立即数
				ExADDi: begin
					ex_add_sub_imm_task;
				end
				
				// 减去立即数
				ExSUBi: begin
					ex_add_sub_imm_task;
				end
				
				// 执行ReLU激活函数
				ExReLU: begin
					ex_add_sub_imm_task;	// 可以参照立即数加减算法
				end
				
				
				// 执行sigmoid激活函数
				ExSigmoid: begin
					ex_add_sub_imm_task;	// 可以参照立即数加减算法
				end
				
				
				// 执行tanh激活函数
				ExTanh: begin
					ex_add_sub_imm_task;	// 可以参照立即数加减算法
				end
				
				// 执行矩阵点乘运算
				ExDOT: begin
					ex_add_sub_task;	// 可以参考加减法的运算
				end
				
				// 执行立即数乘法
				ExMulti: begin
					ex_add_sub_imm_task;	// 可以参照立即数加减算法
				end
				
				// 执行矩阵2-D卷积运算(注意是3x3的valid卷积！)
				ExConv: begin
					ex_conv_task;	// 执行卷积操作
				end
				
				// 执行矩阵的pooling池化运算（注意是2x2的pooling）
				ExPool: begin
					ex_pool_task;	// 执行pooling池化操作
				end
				
				// 执行矩阵乘法运算
				ExMult: begin
					ex_mult_task;	// 执行矩阵的乘法运算
				end
				
				// 执行矩阵转置函数
				ExTran: begin
					ex_tran_task;	// 执行转置
				end
				
				// 执行RGB565转换成灰度图的运算
				ExGray: begin
					ex_add_sub_imm_task;	// 可以参照立即数加减算法
				end
					
				// 执行矩阵±标量的函数
				ExADDs: begin
					ex_add_sub_scalar_task;	//
				end
				
				// 执行矩阵-标量的函数
				ExSUBs: begin
					ex_add_sub_scalar_task;	//
				end
				
				//
				default: begin
					reset_system_task;
				end
			endcase
			
		end
////////////////////////////////////////////////
// 执行各种操作
	// 激活函数 的计算
	wire		[31:0]			ddr_read_data_rho;	// 经过激活函数的变换
	reg			[127:0]			ddr_read_data_valid_shifter;	// 需要较大的寄存器链
	// 2018-04-05: 查出来一个bug，如果不在接收到npu_inst_shifter的时候将ddr_read_data_valid_shifter复位，可能会有问题！
	always @(posedge clk)
		if(npu_inst_en)
			ddr_read_data_valid_shifter <= 0;
		else
			ddr_read_data_valid_shifter <= {ddr_read_data_valid_shifter[126:0], ddr_read_data_valid};
	// 例化激活函数的计算器
	cordic_tanh_sigm_rtl		cordic_tanh_sigm_rtl_inst(
									.sys_clk(clk),
									.sys_rst_n(rst_n),
									.src_x(ddr_read_data),
									.rho(ddr_read_data_rho),
									.algorithm({(OP==TANH), (OP==SIGM)})
								);

	wire	signed	[31:0]		dot_a = (cstate==ExMulti)? IMM : npu_scfifo_Dollar1_q;
	wire	signed	[31:0]		dot_b = ddr_read_data;
	wire	signed	[63:0]		dot_c = dot_a * dot_b;
	// 路由联通
	//////////////////////////////////////////////////////////////////////////////////
	// 首先是要缓存矩阵乘法中，$1的一行向量
	wire	[31:0]		npu_ram_inst_4_q;
	wire				npu_ram_inst_4_wren;
	wire	[31:0]		npu_ram_inst_4_data;
	reg		[8:0]		npu_ram_inst_4_wraddress;
	reg		[8:0]		npu_ram_inst_4_rdaddress;
	dpram_2p			#(
							.LOG2N(9),
							.DATA_WIDTH(DATA_WIDTH)
						)
						npu_ram_256pts_inst_4(
							.wrclock(clk),
							.rdclock(clk),
							.data(npu_ram_inst_4_data),
							.rdaddr(npu_ram_inst_4_rdaddress),
							.wraddr(npu_ram_inst_4_wraddress),
							.wrreq(npu_ram_inst_4_wren),
							.rdreq(1),
							.q(npu_ram_inst_4_q)
						);
	// 将$1里面的一行数据写入到RAM进行缓存
	always @(posedge clk)
		if(cstate==ExMult && substate==0)
			npu_ram_inst_4_wraddress <= 0;
		else if(cstate==ExMult && substate<=2 && ddr_read_data_valid)
			npu_ram_inst_4_wraddress <= npu_ram_inst_4_wraddress + 1;	// 地址加1
	
	assign	npu_ram_inst_4_wren = (cstate==ExMult && substate<=2 && ddr_read_data_valid);
	assign	npu_ram_inst_4_data = ddr_read_data;
	
	// 然后是向量的MAC操作
	always @(posedge clk)
		if(cstate==ExMult && substate<=2)
			npu_ram_inst_4_rdaddress <= 0;
		else if(cstate==ExMult && substate>=3)
		begin
			if(ddr_read_data_valid)
				if(npu_ram_inst_4_rdaddress>=(N-1))
					npu_ram_inst_4_rdaddress <= 0;
				else
					npu_ram_inst_4_rdaddress <= npu_ram_inst_4_rdaddress + 1;
		end
		
	// 需要将ddr_read_data打两排
	reg		[31:0]		ddr_read_data_prev	[0:5];
	integer		l;
	always @(posedge clk)
	begin
		for(l=0; l<5; l=l+1)
			ddr_read_data_prev[l+1] <= ddr_read_data_prev[l];
		ddr_read_data_prev[0] <= ddr_read_data;
	end
	
	// 计算现在MAC有多少元素了
	reg		[31:0]				vec_mac_elem_cnt;
	always @(posedge clk)
		if(cstate==ExMult && (substate<=2 || substate==8))
			vec_mac_elem_cnt <= 0;
		else if(ddr_read_data_valid_shifter[1])
			vec_mac_elem_cnt <= (vec_mac_elem_cnt>=(N-1))? 0 : vec_mac_elem_cnt + 1;
			
	// 然后是MAC操作，实现向量乘法
	// 2018-03-09：查出bug，发现是因为MAC操作少加了一组！
	wire	signed		[31:0]	vec_mac_a = ddr_read_data_prev[1];
	wire	signed		[31:0]	vec_mac_b = npu_ram_inst_4_q;
	wire	signed		[63:0]	vec_mac_c = vec_mac_a*vec_mac_b;
	reg		signed		[31:0]	vec_mac_result;
	reg							vec_mac_result_en;
	always @(posedge clk)
		if(cstate==ExMult && (substate<=2 || substate==8))
			vec_mac_result <= 0;
		else if(ddr_read_data_valid_shifter[1] && vec_mac_elem_cnt>0)
			vec_mac_result <= vec_mac_result + vec_mac_c[DATA_WIDTH+FRAC_WIDTH-1:FRAC_WIDTH];
		else if(ddr_read_data_valid_shifter[1] && vec_mac_elem_cnt==0)
			vec_mac_result <= vec_mac_c[DATA_WIDTH+FRAC_WIDTH-1:FRAC_WIDTH];
	
	always @(posedge clk)
		vec_mac_result_en <= (cstate==ExMult && substate>=3 && substate<8) && (ddr_read_data_valid_shifter[1] && vec_mac_elem_cnt==(N-1));
	
	// 补充： 灰度图转换操作
	reg		[7:0]	RGB888_R;
	reg		[7:0]	RGB888_G;
	reg		[7:0]	RGB888_B;
	always @(posedge clk)
	begin
		RGB888_R <= {ddr_read_data[15:11], 3'B000};
		RGB888_G <= {ddr_read_data[10:5], 2'B00};
		RGB888_B <= {ddr_read_data[4:0], 3'B000};
	end
	// RGB to YUV
	reg		[16:0]	YUV422_Y_reg;// = 66*RGB888_R + 129 * RGB888_G + 25*RGB888_B;
	reg		[16:0]	YUV422_Cb_reg;// = -38*RGB888_R - 74*RGB888_G + 112*RGB888_B;
	reg		[16:0]	YUV422_Cr_reg;// = 112*RGB888_R - 94*RGB888_G - 18*RGB888_B;
	// set_multicycle_path -- 理论上，两个时钟计算一次即可
	// 不过，在芯片 5CSEBA6U23I7 上面，似乎不必太在意，因为65MHz时钟比较慢(Fmax=81.63MHz)
	// 或者可以打一拍看看，将MAC运算拆分为 * / + 两步进行 ==> 171.79MHz
	reg		[16:0]	RGB888_R_66;
	reg		[16:0]	RGB888_R_38;
	reg		[16:0]	RGB888_R_112;
	reg		[16:0]	RGB888_G_129;
	reg		[16:0]	RGB888_G_74;
	reg		[16:0]	RGB888_G_94;
	reg		[16:0]	RGB888_B_25;
	reg		[16:0]	RGB888_B_112;
	reg		[16:0]	RGB888_B_18;
	reg		[8:0]	YUV422_Y;
	reg		[8:0]	YUV422_Cb;
	reg		[8:0]	YUV422_Cr;
	always @(posedge clk)
	begin
		RGB888_R_66 <= 9'D66*RGB888_R;
		RGB888_R_38 <= 9'D38*RGB888_R;
		RGB888_R_112 <= 9'D112*RGB888_R;
		RGB888_G_129 <= 9'D129*RGB888_G;
		RGB888_G_74 <= 9'D74*RGB888_G;
		RGB888_G_94 <= 9'D94*RGB888_G;
		RGB888_B_25 <= 9'D25*RGB888_B;
		RGB888_B_112 <= 9'D112*RGB888_B;
		RGB888_B_18 <= 9'D18*RGB888_B;
		
		YUV422_Y_reg <= RGB888_R_66 + RGB888_G_129 + RGB888_B_25;
		YUV422_Cb_reg <= - RGB888_R_38 - RGB888_G_74 + RGB888_B_112;
		YUV422_Cr_reg <= RGB888_R_112 - RGB888_G_94 - RGB888_B_18;
		
		// 加上偏移量
		YUV422_Y <= (YUV422_Y_reg>>>8) + 16;	// 16~235
		YUV422_Cb <= (YUV422_Cb_reg>>>8) + 128;	// 16~240
		YUV422_Cr <= (YUV422_Cr_reg>>>8) + 128;	// 16~240
			
	end
	
	wire	[7:0]	YUV422_Y_valid = (YUV422_Y<16)? 16 : (YUV422_Y>235)? 235 : YUV422_Y;
	wire	[7:0]	YUV422_Cb_valid = (YUV422_Cb<16)? 16 : (YUV422_Cb>240)? 240 : YUV422_Cb;
	wire	[7:0]	YUV422_Cr_valid = (YUV422_Cr<16)? 16 : (YUV422_Cr>240)? 240 : YUV422_Cr;
	///////////////
	// 例化卷积模块
	wire	signed	[DATA_WIDTH-1:0]	conv_write_data;
	wire								conv_write_data_valid;
	wire								conv_read_data_valid = (((cstate==ExConv && substate>=2 && substate<7) || (cstate==ExPool)) && ddr_read_data_valid);
	wire								kerl_read_data_valid = ((cstate==ExConv && substate<2) && ddr_read_data_valid);
	// 
	reg				[DATA_WIDTH-1:0]	kernel_m;
	reg				[DATA_WIDTH-1:0]	kernel_n;
	reg				[DATA_WIDTH-1:0]	width;
	reg									arith_type;
	reg									pool_type;
	wire			[DATA_WIDTH-1:0]	pool_opt_col;
	always @ ( posedge clk )
	begin
		if ( OP == CONV )
		begin
			kernel_m 		<= Km;
			kernel_n 		<= Kn;
			arith_type 		<= 1'B0;
			pool_type 		<= 1'B0;
		end
		else if ( OP == POOL )
		begin
			kernel_m 		<= Pm;
			kernel_n 		<= Pn;
			arith_type 		<= 1'B1;
			pool_type 		<= MODE;
		end
		else
		begin
			arith_type 		<= 1'B0;
			pool_type 		<= 1'B0;
		end
		
		width <= N;
	end
	npu_conv_rtl	
	#(
		.Km					( 5 					),
		.Kn					( 5		 				)
	) 	u0_npu_conv_rtl
	(
		.clk				( clk					), 
		.rst				( OP_EN[2]				),
		// 
		.kernel_clr			( OP_EN[2]				),
		.kernel_m			( kernel_m				),
		.kernel_n			( kernel_n				),
		.kernel_data		( ddr_read_data			),
		.kernel_data_valid	( kerl_read_data_valid 	),
		//
		.width				( width					),
		.read_data			( ddr_read_data			),
		.read_data_valid	( conv_read_data_valid	),
		//
		.write_data			( conv_write_data		),
		.write_data_valid	( conv_write_data_valid	),
		//
		.arith_type			( arith_type			),
		.pool_type			( pool_type				),
		//
		.pool_opt_col		( pool_opt_col 			)
	);
	
	/////////// 输出的FIFO操作
	// 2018-05-16: $1的FIFO输出到$3的输入时序不佳（估计是通过某个组合逻辑直连了，这里修正一下）
	assign			npu_scfifo_Dollar1_data = ddr_read_data;
	assign			npu_scfifo_Dollar1_wrreq = ddr_read_data_valid && 
														(	(cstate==ExADD && substate<=2) ||
															(cstate==ExSUB && substate<=2) ||
															(cstate==ExDOT && substate<=2) 
														);
	assign			npu_scfifo_Dollar1_rdreq = ddr_read_data_valid && 
														(	(cstate==ExADD && substate>=3) ||
															(cstate==ExSUB && substate>=3) ||
															(cstate==ExDOT && substate>=3)
														);
	// 使用寄存器打断一下链路
	always @(posedge clk)
	begin
		npu_scfifo_Dollar3_data 				<= 	(cstate==ExADD)? (npu_scfifo_Dollar1_q + ddr_read_data) : 
														(cstate==ExSUB)? (npu_scfifo_Dollar1_q - ddr_read_data) : 
														(cstate==ExDOT)? (dot_c[DATA_WIDTH+FRAC_WIDTH-1:FRAC_WIDTH]) : 
														(cstate==ExADDi)? (ddr_read_data + IMM) : 
														(cstate==ExSUBi)? (ddr_read_data - IMM) : 
														(cstate==ExADDs)? (ddr_read_data + SCALAR) : 
														(cstate==ExSUBs)? (ddr_read_data - SCALAR) : 
														(cstate==ExMult)? vec_mac_result : 
														(cstate==ExConv)? conv_write_data : 
														(cstate==ExPool)? conv_write_data : 
														(cstate==ExTran)? ddr_read_data : 
														(cstate==ExGray)? ({{DATA_WIDTH{1'B0}}, YUV422_Y_valid, {FRAC_WIDTH{1'B0}}}) : 
														(cstate==ExMulti)? (dot_c[DATA_WIDTH+FRAC_WIDTH-1:FRAC_WIDTH]) : 
														(cstate==ExReLU)? (ddr_read_data[31]? 32'H0000_0000 : ddr_read_data) : 
														(cstate==ExSigmoid)? ddr_read_data_rho : 
														(cstate==ExTanh)? ddr_read_data_rho : 
														32'H0000_0000;
		npu_scfifo_Dollar3_wrreq 				<= 	(
															ddr_read_data_valid && 
															(	(cstate==ExADD && substate>=3) ||
																(cstate==ExSUB && substate>=3) ||
																(cstate==ExDOT && substate>=3) ||
																(cstate==ExSUBi) || 
																(cstate==ExADDi) ||
																(cstate==ExMulti) ||
																(cstate==ExTran) ||
																(cstate==ExReLU) ||
																(cstate==ExADDs && substate<3) ||
																(cstate==ExSUBs && substate<3)
															)
														) ||
														(
															ddr_read_data_valid_shifter[38] && 
															(	(cstate==ExSigmoid) ||
																(cstate==ExTanh) 
															)
														) ||
														(
															( cstate==ExConv && conv_write_data_valid ) ||
															( cstate==ExPool && conv_write_data_valid)
														) ||
														(
															ddr_read_data_valid_shifter[2] && 
															(	cstate==ExMult && vec_mac_result_en
															)
														) ||
														(
															ddr_read_data_valid_shifter[3] && 
															(	cstate==ExGray	 	
															)
														);
														
	end													
	
////////////////////////
// 各种gtak
// 首先	是系统复位的task
task reset_system_task;
begin
	cstate <= IDLE;
	substate <= 0;	// 为了让指令执行更加正确，需要在外部FSM里面嵌入子FSM
	npu_inst_ready <= 1;	// 可以接受指令
	// 撤销DDR读取使能信号
	ddr_read_req <= 0;
	// 撤销DDR写入信号
	//ddr_write_req <= 0;
	// $1/$2/$3三个FIFO的读取信号
	//npu_scfifo_Dollar3_rdreq <= 0;
end
endtask

// 空闲状态下的task
task idle_task;
begin
	// 根据指令的OP字段选择跳转逻辑
	if(OP_EN[0])
	begin
		case(OP)
			ADD: begin
				cstate <= ExADD;	//	 执行加法操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
			
			SUB: begin
				cstate <= ExSUB;	//	 执行减法操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
			
			ADDi: begin
				cstate <= ExADDi;	//	 执行立即数加法操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
			
			SUBi: begin
				cstate <= ExSUBi;	//	 执行立即数减法操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
			
			RELU: begin
				cstate <= ExReLU;	//	 执行RELU操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
			
			SIGM: begin
				cstate <= ExSigmoid;	//	 执行sigmoid操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
			
			TANH: begin
				cstate <= ExTanh;	//	 执行tanh操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
			
			DOT: begin
				cstate <= ExDOT;	//	 执行矩阵点乘操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
			
			MULTi: begin
				cstate <= ExMulti;	//	 执行矩阵立即数乘法操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
			
			CONV: begin
				cstate <= ExConv;	//	 执行矩阵2D valid卷积操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
			
			POOL: begin
				cstate <= ExPool;	//	 执行矩阵2D valid卷积操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				GPC5 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
				
			MULT: begin
				cstate <= ExMult;	//	 执行矩阵乘法操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
				
			TRAN: begin
				cstate <= ExTran;	//	 执行矩阵转置操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
			
			GRAY: begin
				cstate <= ExGray;	//	 执行RGB565/灰度图转换操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
			
			ADDs: begin
				cstate <= ExADDs;	//	 执行矩阵+标量操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
			
			SUBs: begin
				cstate <= ExSUBs;	//	 执行矩阵-标量操作
				substate <= 0;
				GPC0 <= 0;
				GPC1 <= 0;
				npu_inst_ready <= 0;	// not ready了
			end
			
			default: begin
				reset_system_task;
			end
		
		endcase
	end
end
endtask

// 执行加/减法操作
task ex_add_sub_task;
begin
	case(substate)
		0: begin
			// 如果完成了ADD， 那么跳出
			if(GPC0>=M)
				reset_system_task;
			// 否则就要每行每行的执行
			else
			begin
				GPC1 <= 0;
				GPC2 <= 0;
				substate <= 1;
				ddr_read_addr <= Dollar1 + (GPC0*N);	// 生成$1的读取地址
				ddr_read_req <= 1;
			end
		end
		
		1: begin
			// 如果$1的一行数据读取完成，就要开始读取$2
			if(GPC1>=(N-1) && ddr_read_ready)
			begin
				GPC1 <= 0;
				substate <= 2;
				ddr_read_req <= 0;	// 撤销DDR读取指令
			end
			// 否则就是要继续读取$1的当前行
			else
			begin
				if(ddr_read_ready)
				begin
					GPC1 <= GPC1 + 1;
					ddr_read_addr <= ddr_read_addr + 1;
					ddr_read_req <= 1;
				end
			end
		end
		
		// 等待$1-fifo里面有满满一行的数据
		2: begin
			if(npu_scfifo_Dollar1_rdusedw>=N)
			begin
				substate <= 3;
				ddr_read_addr <= Dollar2 + (GPC0*N);	// 生成$2的读取地址
				ddr_read_req <= 1;
			end
		end
		
		// 实现$2的一行数据读取
		3: begin
			if(GPC1>=(N-1) && ddr_read_ready)
			begin
				GPC1 <= 0;
				GPC2 <= 0;
				substate <= 4;
				ddr_read_req <= 0;	// 撤销DDR读取指令
				// 生成DDR回写地址
				//ddr_write_addr <= Dollar3 + (GPC0*N);	// $3的回写地址
			end
			// 否则就是要继续读取$2的当前行
			else
			begin
				if(ddr_read_ready)
				begin
					GPC1 <= GPC1 + 1;
					ddr_read_addr <= ddr_read_addr + 1;
					ddr_read_req <= 1;
				end
			end
		end
		
		// 回写$3的数据，将N列的数据全部写入即可
		4: begin
			if(ddr_write_data_valid && ddr_write_col>=(N-1))
			begin
				substate <= 0;
				GPC0 <= GPC0 + 1;
				GPC1 <= 0;
				GPC2 <= 0;
			end
		end
		
		// 
		default: begin
			reset_system_task;
		end
	endcase
end
endtask

// 执行立即数加减法操作
task ex_add_sub_imm_task;
begin
	case(substate)
		0: begin
			// 如果完成了ADD， 那么跳出
			if(GPC0>=M)
				reset_system_task;
			// 否则就要每行每行的执行
			else
			begin
				GPC1 <= 0;
				GPC2 <= 0;
				substate <= 1;
				ddr_read_addr <= Dollar1 + (GPC0*N);	// 生成$1的读取地址
				ddr_read_req <= 1;
			end
		end
		
		1: begin
			// 如果$1的一行数据读取完成，就要开始输出$3
			if(GPC1>=(N-1) && ddr_read_ready)
			begin
				GPC1 <= 0;
				substate <= 2;
				ddr_read_req <= 0;	// 撤销DDR读取指令
				// 生成DDR回写地址
				//ddr_write_addr <= Dollar3 + (GPC0*N);	// $3的回写地址
			end
			// 否则就是要继续读取$1的当前行
			else
			begin
				if(ddr_read_ready)
				begin
					GPC1 <= GPC1 + 1;
					ddr_read_addr <= ddr_read_addr + 1;
					ddr_read_req <= 1;
				end
			end
		end
		
		
		// 回写$3的数据，将N列的数据全部写入即可
		2: begin
			if(ddr_write_data_valid && ddr_write_col>=(N-1))
			begin
				substate <= 0;
				GPC0 <= GPC0 + 1;
				GPC1 <= 0;
				GPC2 <= 0;
			end
		end
		
		// 
		default: begin
			reset_system_task;
		end
	endcase
end
endtask

////////////////////////////////////////////
// 2D-valid卷积操作
task ex_conv_task;
begin
	case(substate)
		// 首先读取卷积核
		0: begin
			// 如果读取完成，就要开始图像的读取 & 卷积
			if(GPC0>=(Km*Kn))
			begin
				GPC0 <= 0; 
				substate <= 7;
				delay <= 0;
				ddr_read_req <= 0;
			end
			// 否则就要持续度去卷积核
			else
			begin
				substate <= 1;
				ddr_read_addr <= Dollar2 + GPC0;	// 生成$2（卷积核参数）的读取地址
				ddr_read_req <= 1;
			end
		end
		
		1: begin
			if(ddr_read_ready)
				ddr_read_req <= 0;
			if(ddr_read_data_valid)
			begin
				GPC0 <= GPC0 + 1;
				substate <= 0;		// 回到0状态，要在发动一次kernel读取
			end
		end
		
		// 注意，这里需要延时一会儿！
		// 因为后面的卷积计算的时候参考了rdata_valid[6]，所以一定要有delay一下才行！
		7: begin
			if(delay>=8)
				substate <= 2;
			else
				delay <= delay + 1;
		end
		
		
		// 开始读取图像
		2: begin
			// 如果完成了卷积计算， 那么跳出
			if(GPC0>=M)
				reset_system_task;
			// 否则就要每行每行的执行
			else
			begin
				GPC1 <= 0;
				GPC2 <= 0;
				substate <= 3;
				ddr_read_addr <= Dollar1 + (GPC0*N);	// 生成$1的读取地址
				ddr_read_req <= 1;
			end
		end
		
		3: begin
			// 如果$1的Km行数据读取完成，就要开始输出$3
			// 而且已经读了Km行了
			if(GPC1>=(N-1) && ddr_read_ready)
			begin
				GPC1 <= 0;
				GPC0 <= GPC0 + 1;	// 读取行加1
				ddr_read_addr <= ddr_read_addr + 1;	//  读取地址加1
				if(GPC0>=(Km-1))
				begin
					substate <= 4;
					ddr_read_req <= 0;	// 撤销DDR读取指令
					// 生成DDR回写地址
					//ddr_write_addr <= Dollar3 + ((GPC0-Km+1)*(N-Kn+1));	// $3的回写地址
					GPC2 <= 0;	// GPC2置零
				end
			end
			// 否则就是要继续读取$1的当前行
			else
			begin
				if(ddr_read_ready)
				begin
					GPC1 <= GPC1 + 1;
					ddr_read_addr <= ddr_read_addr + 1;
					ddr_read_req <= 1;
				end
			end
		end
		
		
		// 回写$3的数据，将N列的数据全部写入即可
		4: begin
			if(ddr_write_data_valid && ddr_write_col>=(N-Kn))
			begin
				substate <= 2;
				GPC1 <= 0;
				GPC2 <= 0;
			end
		end
		
		// 
		default: begin
			reset_system_task;
		end
	endcase
	
	
end
endtask

///////////////////////////////////////////////
// 池化操作
task ex_pool_task;
begin
	case(substate)
		// 开始读取图像
		0: begin
			// 如果完成了卷积计算， 那么跳出
			if(GPC0>=M)
				reset_system_task;
			// 否则就要每行每行的执行
			else
			begin
				GPC1 <= 0;
				GPC2 <= 0;
				substate <= 1;
				ddr_read_addr <= Dollar1 + (GPC0*N);	// 生成$1的读取地址
				ddr_read_req <= 1;
			end
		end
		
		1: begin
			// 如果$1的行数据读取完成，就要开始输出$3
			if(GPC1>=(N-1) && ddr_read_ready)
			begin
				GPC1 <= 0;
				GPC0 <= GPC0 + 1;	// 读取行加1
				GPC5 <= GPC5 + 1;	// 读取行加1
				ddr_read_addr <= ddr_read_addr + 1;	//  读取地址加1
				if(GPC0>=(M-1)&& GPC5<(Pm-1))	// 
					reset_system_task;
				else if(GPC5>=(Pm-1))	// 
				begin
					substate <= 2;
					ddr_read_req <= 0;	// 撤销DDR读取指令
					// 生成DDR回写地址
					//ddr_write_addr <= Dollar3 + ((GPC0>>>1)*(N>>>1));	// $3的回写地址
					GPC2 <= 0;	// GPC2置零
				end
			end
			// 否则就是要继续读取$1的当前行
			else
			begin
				if(ddr_read_ready)
				begin
					GPC1 <= GPC1 + 1;
					ddr_read_addr <= ddr_read_addr + 1;
					ddr_read_req <= 1;
				end
			end
		end
		
		// 回写$3的数据，将N列的数据全部写入即可
		2: begin
			if(ddr_write_data_valid && ddr_write_col>=(pool_opt_col-1))
			begin
				substate <= 0;
				GPC1 <= 0;
				GPC2 <= 0;
				GPC5 <= 0;
			end
		end
		// 
		default: begin
			reset_system_task;
		end
	endcase
end
endtask

///////////////////////////////////////////////////////////////
// 矩阵乘法运算
task ex_mult_task;
begin
	case(substate)
		0: begin
			// 如果完成了MULT， 那么跳出
			if(GPC0>=M)
				reset_system_task;
			// 否则就要每行每行的执行
			else
			begin
				GPC1 <= 0;
				GPC2 <= 0;
				substate <= 1;
				ddr_read_addr <= Dollar1 + (GPC0*N);	// 生成$1的读取地址
				ddr_read_req <= 1;
			end
		end
		
		1: begin
			// 如果$1的一行数据读取完成，就要开始读取$2
			if(GPC1>=(N-1) && ddr_read_ready)
			begin
				GPC1 <= 0;
				substate <= 2;
				delay <= 0;
				ddr_read_req <= 0;	// 撤销DDR读取指令
			end
			// 否则就是要继续读取$1的当前行
			else
			begin
				if(ddr_read_ready)
				begin
					GPC1 <= GPC1 + 1;
					ddr_read_addr <= ddr_read_addr + 1;
					ddr_read_req <= 1;
				end
			end
		end
		
		// 等待$1-fifo里面有满满一行的数据
		2: begin
			if(npu_ram_inst_4_wraddress>=N)
			begin
				//  开始循环读取$2的每一列数据(进入8状态，进行短暂的停顿，为了防止出现bug)
				substate <= 8;
				delay <= 0;
				GPC2 <= 0;
				ddr_read_req <= 0;
			end
		end
		
		//
		8: begin
			if(delay>=5)
				substate <= 3;
			else
				delay <= delay + 1;
		end
		
		// 读取$2的每一列数据
		3: begin
			if(GPC2>=P)
			begin
				substate <= 5;		// 如果每一列都读取完毕，那么就要开始C行向量传输
				GPC0 <= GPC0 + 1;
				GPC4 <= 0;	// 用来统计发送的C向量长度
			end
			// 否则启动一列数据的读取
			else
			begin
				ddr_read_addr <= Dollar2 + GPC2;
				substate <= 4;
				GPC3 <= 0;
				ddr_read_req <= 1;
			end
		end
		
		// 持续读取
		4: begin
			if(ddr_read_ready)
			begin
				if(GPC3>=(N-1))
				begin
					substate <= 3;
					GPC2 <= GPC2 + 1;
					ddr_read_req <= 0;	// 这里关闭ddr读取使能很关键！
				end
				else
				begin
					GPC3 <= GPC3 + 1;
					ddr_read_addr <= ddr_read_addr + P;
					ddr_read_req <= 1;
				end
			end
		end
		
		// 回写$3的数据，将N列的数据全部写入即可
		5: begin
			if(ddr_write_data_valid && ddr_write_col>=(P-1))
			begin
				substate <= 0;
			end
		end
		
		// 
		default: begin
			reset_system_task;
		end
	endcase
end
endtask
////////////////////////////////////////////////////////////////////////////////////

// 执行矩阵转置操作
task ex_tran_task;
begin
	case(substate)
		0: begin
			// 如果完成了ADD， 那么跳出
			if(GPC0>=N)
				reset_system_task;
			// 否则就要每列每列的进行读取
			else
			begin
				GPC1 <= 0;
				GPC2 <= 0;
				substate <= 1;
				ddr_read_addr <= Dollar1 + GPC0;	// 生成$1的读取地址
				ddr_read_req <= 1;
			end
		end
		
		1: begin
			// 如果$1的一列数据读取完成，就要开始输出$3
			if(GPC1>=(M-1) && ddr_read_ready)
			begin
				GPC1 <= 0;
				substate <= 2;
				ddr_read_req <= 0;	// 撤销DDR读取指令
				// 生成DDR回写地址
				//ddr_write_addr <= Dollar3 + (GPC0);	// $3的回写地址
			end
			// 否则就是要继续读取$1的当前行
			else
			begin
				if(ddr_read_ready)
				begin
					GPC1 <= GPC1 + 1;
					ddr_read_addr <= ddr_read_addr + N;	// 因为读取的时候是按列读取的
					ddr_read_req <= 1;
				end
			end
		end
		
		
		// 回写$3的数据，将N列的数据全部写入即可（因为是转置，所以一定要注意！）
		2: begin
			if(ddr_write_data_valid && ddr_write_col>=(M-1))
			begin
				substate <= 0;
				GPC0 <= GPC0 + 1;
				GPC1 <= 0;
				GPC2 <= 0;
			end
		end
		// 
		default: begin
			reset_system_task;
		end
	endcase
end
endtask

// 执行矩阵和标量的加减法操作
task ex_add_sub_scalar_task;
begin
	case(substate)
		0: begin
			// 如果完成了ADD， 那么跳出
			if(GPC0>=M)
				reset_system_task;
			// 否则就要每行每行的执行
			else
			begin
				GPC1 <= 0;
				GPC2 <= 0;
				substate <= 3;
				ddr_read_addr <= Dollar2 ;	// 生成$2的读取地址
				ddr_read_req <= 1;
			end
		end
		// 等待$2的读取请求完成
		3: begin
			if(ddr_read_ready)
			begin
				ddr_read_req <= 0;
				substate <= 4;
			end
		end
		// 等待$2的数据读取出来
		4: begin
			if(ddr_read_data_valid)
			begin
				SCALAR <= ddr_read_data;	// 读取到的标量
				ddr_read_addr <= Dollar1 + (GPC0*N);	// 生成$1的读取地址
				ddr_read_req <= 1;
				substate <= 1;
			end
		end
		
		1: begin
			// 如果$1的一行数据读取完成，就要开始输出$3
			if(GPC1>=(N-1) && ddr_read_ready)
			begin
				GPC1 <= 0;
				substate <= 2;
				ddr_read_req <= 0;	// 撤销DDR读取指令
				// 生成DDR回写地址
				//ddr_write_addr <= Dollar3 + (GPC0*N);	// $3的回写地址
			end
			// 否则就是要继续读取$1的当前行
			else
			begin
				if(ddr_read_ready)
				begin
					GPC1 <= GPC1 + 1;
					ddr_read_addr <= ddr_read_addr + 1;
					ddr_read_req <= 1;
				end
			end
		end
		
		
		// 回写$3的数据，将N列的数据全部写入即可
		2: begin
			if(ddr_write_data_valid && ddr_write_col>=(N-1))
			begin
				substate <= 0;
				GPC0 <= GPC0 + 1;
				GPC1 <= 0;
				GPC2 <= 0;
			end
		end
		
		// 
		default: begin
			reset_system_task;
		end
	endcase

end
endtask
/////////////////////////////////////////////////////////////////////////////////////

	// 接入DDR接口
	assign			ddr_write_data = npu_scfifo_Dollar3_q;
	assign			ddr_write_req = !npu_scfifo_Dollar3_rdempty;
	assign			npu_scfifo_Dollar3_rdreq = ddr_write_data_valid;
	always @(posedge clk)
		if(OP_EN[0])
		begin
			ddr_write_col <= 0;
			ddr_write_row <= 0;
		end
		else
		begin
			if(OP==ADD || OP==SUB || OP==ADDi || OP==SUBi || OP==MULTi || OP==DOT || OP==SIGM || OP==RELU || OP==TANH || OP==GRAY || OP==ADDs || OP==SUBs)
			begin
				if(ddr_write_data_valid)
				begin
					if(ddr_write_col>=(N-1))
					begin
						ddr_write_col <= 0;
						ddr_write_row <= ddr_write_row + 1;
					end
					else
						ddr_write_col <= ddr_write_col + 1;
				end
			end
			else if(OP==MULT)
			begin
				if(ddr_write_data_valid)
				begin
					if(ddr_write_col>=(P-1))
					begin
						ddr_write_col <= 0;
						ddr_write_row <= ddr_write_row + 1;
					end
					else
						ddr_write_col <= ddr_write_col + 1;
				end
			end
			else if(OP==CONV)
			begin
				if(ddr_write_data_valid)
				begin
					if(ddr_write_col>=(N-Kn))
					begin
						ddr_write_col <= 0;
						ddr_write_row <= ddr_write_row + 1;
					end
					else
						ddr_write_col <= ddr_write_col + 1;
				end
			end
			else if(OP==POOL)
			begin
				if(ddr_write_data_valid)
				begin
					if(ddr_write_col>=(pool_opt_col-1))
					begin
						ddr_write_col <= 0;
						ddr_write_row <= ddr_write_row + 1;
					end
					else
						ddr_write_col <= ddr_write_col + 1;
				end
			end
			else if(OP==TRAN)
			begin
				if(ddr_write_data_valid)
				begin
					if(ddr_write_col>=(M-1))
					begin
						ddr_write_col <= 0;
						ddr_write_row <= ddr_write_row + 1;
					end
					else
						ddr_write_col <= ddr_write_col + 1;
				end
			end
		end
		
	// 生成DDR写入地址
	always @(posedge clk)
	begin
		if(OP_EN[1])
			ddr_write_addr <= Dollar3;
		else if(ddr_write_data_valid)
			ddr_write_addr <= ddr_write_addr + 1;
	end

////////////////////////////////////////////////////////////////////////////////////

	reg		[31:0]		ddr_write_cnt;	// 统计DDR写入的次数
	always @(posedge clk)
		if(npu_inst_ready)
			ddr_write_cnt <= 0;
		else if(ddr_write_req && ddr_write_ready)
			ddr_write_cnt <= ddr_write_cnt + 1;

	wire	signed	[31:0]	ddr_write_data_signed = ddr_write_data;
////////////////////////////////////////////////////////////////////////////////////
// 指令执行时间
	always @(posedge clk)
		if(npu_inst_en)
			npu_inst_time <= 0;
		else if(!npu_inst_ready)
			npu_inst_time <= npu_inst_time + 1;
	
endmodule
	