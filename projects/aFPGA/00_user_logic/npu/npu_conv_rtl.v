/*----------------------------------------------------------------------------------------------------*\
	FILE: 		npu_conv_rtl.v
 	AUTHOR:		Xudong Chen
 	
	ABSTRACT:	behavior of the module of npu_conv_rtl
 	KEYWORDS:	fpga, convolution
 
 	MODIFICATION HISTORY:
	$Log$
			Xudong Chen 	18/7/24		original, 在允许的范围内（Km x Kn）任意尺寸卷积运算
							18/7/27		试图增加pooling
							18/7/28		除法器复用，减少逻辑开销，提升Fmax
							18/7/29		修正了ram_q[x]==>field_data[y]端口映射，将任意尺寸卷积支持起来，v1.0确定
							18/8/2		使用function函数，将ATlayer参数，自动计算出来
\*------------------------------------------------------------------------------------------------------*/
module npu_conv_rtl
#(
	parameter	Km = 3,							// 卷积核row
	parameter	Kn = 3,							// 卷积核col
	parameter	Ksz = Km * Kn,					// 卷积核尺寸
	parameter	ATlayer = CeilLog2(Ksz)+1,		// ceil( log2( Ksz ) + 1 )	// 加法树的层数
	parameter	ATsize = 1<<(ATlayer),			// 加法树的规模
	parameter	logW = 9,						// 支持的图像的最大宽度（列数量）
	parameter	ADDR_WIDTH = 9,					// 
	parameter	DATA_WIDTH = 32,    			// 数据位宽
	parameter	FRAC_WIDTH = 16,				// 小数部分
	parameter	DATA_UNIT = {{(DATA_WIDTH-FRAC_WIDTH-1){1'B0}}, 1'B1, {FRAC_WIDTH{1'B0}}}, // 固定的单位1 
	parameter	DATA_ZERO = {DATA_WIDTH{1'B0}},	// 固定的0值
	parameter	DATA_MINF = {1'B1, {(DATA_WIDTH-1){1'B0}}},	// 负无穷
	parameter	DATA_PINF = {1'B0, {(DATA_WIDTH-1){1'B1}}}	// 正无穷
)
(
	clk, 
	rst,
	// 
	kernel_clr,
	kernel_m,
	kernel_n,
	kernel_data,
	kernel_data_valid,
	//
	width,
	read_data,
	read_data_valid,
	//
	write_data,
	write_data_valid,
	// conv/pool
	arith_type,
	pool_type,
	// 输出一行的数据
	pool_opt_col
);

/*-------------------------------------------------------------------*\
	functions
\*-------------------------------------------------------------------*/
function integer CeilLog2;
	input	[31:0]	size;
	integer i;
begin	
	CeilLog2 = 1;
	for ( i = 1; 2 ** i < size; i = i + 1 )
		CeilLog2 = i + 1;
end		
endfunction

/*-------------------------------------------------------------------*\
	I/O signals
\*-------------------------------------------------------------------*/
input	wire						clk, rst;				// 时钟/复位
input	wire						kernel_clr;				// 清空卷积核
input	wire	[ADDR_WIDTH-1:0]	kernel_m;				// 卷积核的横向尺寸
input	wire	[ADDR_WIDTH-1:0]	kernel_n;				// 卷积核的纵向尺寸
input	wire	[DATA_WIDTH-1:0]	kernel_data;			// 读取到的卷积核数据
input	wire						kernel_data_valid;		// 读取卷积核数据有效

input	wire	[DATA_WIDTH-1:0]	width;					// 图像的纵向尺寸
input	wire	[DATA_WIDTH-1:0]	read_data;				// 读取到的数据
input	wire						read_data_valid;		// 读取数据有效
//
output	reg		[DATA_WIDTH-1:0]	write_data;				// 写入的数据
output	reg							write_data_valid;		// 写入数据有效
// 卷积/池化选项
input	wire						arith_type;				// 0-convolution, 1-pooling
input	wire						pool_type;				// 0-mean_pool, 1-max_pool
//
output	reg		[DATA_WIDTH-1:0]	pool_opt_col;
/*-------------------------------------------------------------------*\
	parameters
\*-------------------------------------------------------------------*/
localparam							CONV_TYPE = 1'B0;	
localparam							POOL_TYPE = 1'B1;	
localparam							MEAN_TYPE = 1'B0;
localparam							MAX_TYPE = 1'B1;
/*-------------------------------------------------------------------*\
	signals
\*-------------------------------------------------------------------*/
// 生成卷积核数据地址
reg				[ADDR_WIDTH-1:0]	kernel_row;
reg				[ADDR_WIDTH-1:0]	kernel_col;
reg				[ADDR_WIDTH-1:0]	kernel_addr;			// 卷积核地址
reg				[DATA_WIDTH-1:0]	kernel_datax;			// 读取到的卷积核数据
reg									kernel_data_validx;		// 读取卷积核数据有效
//
reg		signed	[DATA_WIDTH-1:0]	kernel_q	[0:Ksz-1];	// 卷积核里面的数据
//wire	signed	[DATA_WIDTH-1:0]	kernel_qs	[0:Ksz-1];	// 卷积核里面的数据
reg		signed	[DATA_WIDTH-1:0]	field_q		[0:Ksz-1];	// 卷积域里面的数据
//wire	signed	[DATA_WIDTH-1:0]	field_qs	[0:Ksz-1];	// 卷积域里面的数据
reg									field_q_en;					
reg				[DATA_WIDTH-1:0]	field_con_idx[0:Km-1];	// 互联网络
//wire			[DATA_WIDTH-1:0]	field_con_idx_s[0:Km-1];// = field_con_idx[0];
reg		signed	[DATA_WIDTH-1:0]	field_data	[0:Km-1];	// 卷积域里面的数据【源】
//wire	signed	[DATA_WIDTH-1:0]	field_data_s[0:Km-1];	// 卷积域里面的数据【源】
reg									field_data_valid	;	// 数据源有效
// 然后是进行p2p乘法
reg		signed	[DATA_WIDTH-1:0]	field_mult	[0:Ksz-1];	// 点对点乘法	
reg		signed	[2*DATA_WIDTH-1:0]	field_mults	[0:Ksz-1];	// 点对点乘法	
reg									field_zero	[0:Ksz-1];	// 点对点乘法	==0
//wire	signed	[DATA_WIDTH-1:0]	field_mult_s[0:Ksz-1];	// 点对点乘法	
reg									field_mult_en;		
reg									field_mults_en;		
// 求和
reg		signed	[DATA_WIDTH-1:0]	ATnode 	  [0:ATsize-1];	// 加法树	
//wire	signed	[DATA_WIDTH-1:0]	ATnodes	  [0:ATsize-1];	// 加法树	
reg									ATnode_en [0:ATlayer-1];// 加法树节点数据有效使能
//wire								ATnode_ens[0:ATlayer-1];// 加法树节点数据有效使能
// 
reg				[DATA_WIDTH-1:0]	ConvResRow;				// 卷积结果的行计数
reg				[DATA_WIDTH-1:0]	ConvResCol;				// 卷积结果的列计数
reg				[DATA_WIDTH-1:0]	ConvCycRow;				// 卷积结果的行计数(0 ~ kernel_m-1)内循环计数
reg				[DATA_WIDTH-1:0]	ConvCycCol;				// 卷积结果的列计数(0 ~ kernel_n-1)内循环计数
// pooling
reg		signed	[DATA_WIDTH-1:0]	div_numer;				// divider的分子部分
reg		signed	[DATA_WIDTH-1:0]	div_denom;				// divider的分母部分
wire	signed	[DATA_WIDTH-1:0]	div_quotient;			// 商
wire								div_dst_en;				// 除法器输出有效
reg									div_src_en;				// 除法器输入有效
// 输出数据有效
wire								write_data_validx;
wire			[DATA_WIDTH-1:0]	opt_colx;
reg									pool_opt_col_rdy;		// 除法结果
// 这里是shifter taps
reg				[DATA_WIDTH-1:0]	ram_wptr 			;	// 指向正在写入的ram
reg				[DATA_WIDTH-1:0]	ram_wptr_sync [0:1] ;	// 同步
reg									ram_wren_sync [0:1] ;	// 同步
reg				[DATA_WIDTH-1:0]	ram_rptr			;	// 指向正在读取的ram	// ram_wptr同步3个clock
reg									ram_rden			;	// 
reg				[DATA_WIDTH-1:0]	ram_waddr			;	// 写入ram的地址
wire	signed	[DATA_WIDTH-1:0]	ram_data	[0:Km-1];	// 写入ram的数据
wire			[DATA_WIDTH-1:0]	ram_wraddr	[0:Km-1];	// 写入ram的地址
wire								ram_wrreq	[0:Km-1];	// 写入ram的请求
wire	signed	[DATA_WIDTH-1:0]	ram_q		[0:Km-1];	// 读取ram的数据
wire			[DATA_WIDTH-1:0]	ram_rdaddr	[0:Km-1];	// 读取ram的地址
wire								ram_rdreq	[0:Km-1];	// 读取ram的请求
/*-------------------------------------------------------------------*\
	timing
//
	// Ex. width == 45, kernel_m == 3, kernel_n == 3
	clk				:	_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_
	rst				:	___|-----|________________________________________________________________________________________________________________________
	read_data		:	_________________| d0| d1| d2| d3| d4| d5| d6| d7| d8| d9|d10|d11|...|d33|d34|d35|d36|d37|d38|d39|d40|d41|d42|d43|d44|
	read_data_valid	: 	_________________|------------------------------------------------...------------------------------------------------|_____
	
	ram_wptr		:		 |0																												 | 1
	ram_wraddr[0]	:	_____|0  		     | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10| 11|...| 33| 34| 35| 36| 37| 38| 39| 40| 41| 42| 43| 44| 0 
	ram_rdaddr[0]	:	_____|44			 | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10|...| 32| 33| 34| 35| 36| 37| 38| 39| 40| 41| 42| 43| 44
	ram_q[0]		:   _____________|   q44      	 | q0| q1| q2| q3| q4| q5| q6| q7| q8|...|q30|q31|q32|q33|q34|q35|q36|q37|q38|q39|q40|q41|q42|q43|q44
	
	ram_wptr_sync[0]:	_________|0																												 | 1
	ram_wptr_sync[0]:	_____________|0																												 | 1
	ram_rden		: 	_____________________________|------------------------------------------------...------------------------------------------------|_____
	ram_rptr		:	_________________|0																												 | 1
	field_con_idx[0]:	_________________| 1 																											 | 2
	field_con_idx[1]:	_________________| 2 																											 | 3
	field_con_idx[2]:	_________________| 3 																											 | 4
	// 要写入卷积域的数据
	field_data[0]	:   _____________________|q44      	 | q0| q1| q2| q3| q4| q5| q6| q7| q8|...|q30|q31|q32|q33|q34|q35|q36|q37|q38|q39|q40|q41|q42|q43|q44
	field_data_valid: 	_________________________________|------------------------------------------------...------------------------------------------------|_____
	// 卷积域中的数据
	field_q[x]		:   _________________________|q44      	 | q0| q1| q2| q3| q4| q5| q6| q7| q8|...|q30|q31|q32|q33|q34|q35|q36|q37|q38|q39|q40|q41|q42|q43|q44
	field_q_en		: 	_____________________________________|------------------------------------------------...------------------------------------------------|_____
	// 点对点乘法
	field_mults[x]	:   _____________________________|m44      	 | m0| m1| m2| m3| m4| m5| m6| m7| m8|...|m30|m31|m32|m33|m34|m35|m36|m37|m38|m39|m40|m41|m42|m43|m44
	field_mults_en	: 	_________________________________________|------------------------------------------------...------------------------------------------------|_____
	field_mult[x]	:   _________________________________|m44      	 | m0| m1| m2| m3| m4| m5| m6| m7| m8|...|m30|m31|m32|m33|m34|m35|m36|m37|m38|m39|m40|m41|m42|m43|m44
	field_mult_en	: 	_____________________________________________|------------------------------------------------...------------------------------------------------|_____
	// 加法树
	ATnode[#L0]		: 	_________________________________________________| m0| m1| m2| m3| m4| m5| m6| m7| m8|...|m30|m31|m32|m33|m34|m35|m36|m37|m38|m39|m40|m41|m42|m43|m44
	ATnode[#L1]		: 	_____________________________________________________| m0| m1| m2| m3| m4| m5| m6| m7| m8|...|m30|m31|m32|m33|m34|m35|m36|m37|m38|m39|m40|m41|m42|m43|m44
	...
	ATnode[#L4]		: 	_________________________________________________________________| m0| m1| m2| m3| m4| m5| m6| m7| m8|...|m30|m31|m32|m33|m34|m35|m36|m37|m38|m39|m40|m41|m42|m43|m44
	ATnode_en[#L4]	: 	_________________________________________________________________|------------------------------------------------...------------------------------------------------|_____
	// 行列计数
	ConvResCol		:	_____|0  		     											     | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10| 11|...| 33| 34| 35| 36| 37| 38| 39| 40| 41| 42| 43| 44| 0 	
	ConvResRow		:	_____|0															    																								 | 1

	ConvCycCol		:	_____|0  		     											     | 1 | 2 | 0 | 1 | 2 | 0 | 1 | 2 | 0 | 1 | 2 |...| 0 | 1 | 2 | 0 | 1 | 2 | 0 | 1 | 2 | 0 | 1 | 2 | 0 	
	ConvCycRow		:	_____|0															    																								 | 1

\*-------------------------------------------------------------------*/

/*-------------------------------------------------------------------*\
	process
\*-------------------------------------------------------------------*/
// 生成卷积核数据地址
always @ ( posedge clk )
	if ( kernel_clr == 1'B1 )
	begin
		kernel_row <= 0;
		kernel_col <= 0;
	end
	else if ( kernel_data_valid == 1'B1 )
	begin
		if ( kernel_col >= ( kernel_n - 1 ) )
		begin
			kernel_row <= kernel_row + 1;
			kernel_col <= 0;
		end
		else
			kernel_col <= kernel_col + 1;
	end
// 只能打一排了
always @ ( posedge clk )
begin
	kernel_addr 		<= ( kernel_row * Kn + kernel_col );
	kernel_datax		<= kernel_data;
	kernel_data_validx	<= kernel_data_valid;
end
// 首先是卷积核
genvar	ki;
genvar 	kj;
generate
	for ( ki = 0; ki < Km; ki = ki + 1 )
	begin : conv_kernel_row
		for ( kj = 0; kj < Kn; kj = kj + 1 )
		begin : conv_kernel_col
			always @ ( posedge clk )
			begin
				if ( kernel_clr == 1'B1 )
				begin
					if ( arith_type == CONV_TYPE )
						kernel_q[ki*Kn+kj] 		<= DATA_ZERO;
					else if ( arith_type == POOL_TYPE && pool_type == MEAN_TYPE )
					begin
						if (( ki < kernel_m ) && ( kj < kernel_n ))
							kernel_q[ki*Kn+kj] 	<= DATA_UNIT;
						else
							kernel_q[ki*Kn+kj] 	<= DATA_ZERO;
					end
					else if ( arith_type == POOL_TYPE && pool_type == MAX_TYPE )
						kernel_q[ki*Kn+kj] 	<= DATA_UNIT;
				end
				else if ( kernel_addr == ( ki*Kn+kj ) && kernel_data_validx == 1'B1)
					kernel_q[ki*Kn+kj] 			<= kernel_datax;
			end	
			//
			//assign	kernel_qs[ki*Kn+kj]			= kernel_q[ki*Kn+kj];
		end
	end
endgenerate
// 然后是ram操作，构造shifter-taps
// 生成wraddr
always @ ( posedge clk )
begin	
	if ( rst == 1'B1 )
	begin
		ram_waddr 		<= 0;
		ram_wptr		<= 0;
	end
	else if ( read_data_valid )
	begin
		if ( ram_waddr >= ( width - 1) )
		begin
			ram_waddr	<= 0;
			//
			if ( ram_wptr >= (kernel_m - 1) )
				ram_wptr <= 0;
			else
				ram_wptr <= ram_wptr + 1'B1;
		end
		else
			ram_waddr	<= ram_waddr + 1;
	end
end
// 同步3个clock
always @ ( posedge clk )
begin
	//
	ram_rden			<= ram_wren_sync[1];
	ram_wren_sync[1]	<= ram_wren_sync[0];
	ram_wren_sync[0] 	<= read_data_valid;
	//
	ram_rptr			<= ram_wptr_sync[1];
	ram_wptr_sync[1] 	<= ram_wptr_sync[0];
	ram_wptr_sync[0]	<= ram_wptr;
	//
end
// ram_q[x]  ===[Km, ram_rptr]==> field_data[y]
//				x = (ram_rptr - y + kernel_m)%kernel_m
genvar 		y;
generate
	for ( y = 0; y < Km; y = y + 1 )
	begin : connect
		always @ ( posedge clk )
		begin : index
			if ( y < kernel_m )
			begin
				if ((( ram_wptr_sync[1] + kernel_m - y ) == kernel_m ) || (( ram_wptr_sync[1] + kernel_m - y ) == ( kernel_m <<< 1 )))
					field_con_idx[y] <= 0;
				else if((( ram_wptr_sync[1] + kernel_m - y ) > kernel_m ) && (( ram_wptr_sync[1] + kernel_m - y ) < ( kernel_m <<< 1 )))
					field_con_idx[y] <= ( ram_wptr_sync[1] + kernel_m - y - kernel_m );
				else
					field_con_idx[y] <= ( ram_wptr_sync[1] + kernel_m - y );
			end
			else
				field_con_idx[y] 	 <= 0;
		end
		//
		//assign	field_con_idx_s[y] 	= field_con_idx[y];
		//assign	field_data_s[y] 	= field_data[y];
		//
		always @ ( posedge clk )
		begin : value
			//
			field_data[y] 		<= ram_q[field_con_idx[y]];
		end
	end
endgenerate

always @ ( posedge clk )
	field_data_valid	<= ram_rden;
	
// 生成卷积域
genvar 		convi;
genvar 		convj;
generate
	for ( convi = 0; convi < Km; convi = convi + 1 )
	begin : conv_row
		for ( convj = 0; convj < Kn; convj = convj + 1 )
		begin : conv_col
			begin : construct
				if ( convj == 0 )
					// 首先是【0】列
					always @ ( posedge clk )
					begin
						if ( rst == 1'B1 )
						begin
							if ( arith_type == POOL_TYPE && pool_type == MAX_TYPE )
								field_q[convi*Kn+convj] <= DATA_MINF;
							else
								field_q[convi*Kn+convj] <= DATA_ZERO;
						end
						else 
						begin
							if ( arith_type == POOL_TYPE && pool_type == MAX_TYPE )
							begin
								if ( field_data_valid == 1'B1 && convi < kernel_m )
									field_q[convi*Kn+convj] <= field_data[convi];
								else if ( field_data_valid == 1'B1 && convi >= kernel_m )
									field_q[convi*Kn+convj] <= DATA_MINF;
							end
							else
							begin
								if ( field_data_valid == 1'B1 )
									field_q[convi*Kn+convj] <= field_data[convi];
							end
						end
					end
				else
				begin
					// 然后是【1...Kn-1】列
					always @ ( posedge clk )
					begin
						if ( rst == 1'B1 )
						begin
							if ( arith_type == POOL_TYPE && pool_type == MAX_TYPE )
								field_q[convi*Kn+convj] <= DATA_MINF;
							else
								field_q[convi*Kn+convj] <= DATA_ZERO;
						end
						else 
						begin
							if ( arith_type == POOL_TYPE && pool_type == MAX_TYPE )
							begin
								if ( field_data_valid == 1'B1 && convj < kernel_n )
									field_q[convi*Kn+convj] <= field_q[convi*Kn+convj-1];
								else if ( field_data_valid == 1'B1 && convj >= kernel_n )
									field_q[convi*Kn+convj] <= DATA_MINF;
							end
							else
							begin
								if ( field_data_valid == 1'B1 )
									field_q[convi*Kn+convj] <= field_q[convi*Kn+convj-1];
							end
						end
					end
				end
				//
				//assign		field_qs[convi*Kn+convj] = field_q[convi*Kn+convj];
			end
		end
	end
endgenerate
// 
always @ ( posedge clk )
	field_q_en <= field_data_valid;
	
// 然后是进行点对点乘法
genvar 	pts;
generate
	for ( pts = 0; pts < Ksz; pts = pts + 1 )
	begin : multi
		// 先计算乘法
		always @ ( posedge clk )
		begin
			field_mults[pts] 	<= field_q[pts] * kernel_q[pts];
			field_zero[pts] 	<= ( kernel_q[pts] == DATA_ZERO );
		end
		// 然后移位寄存
		always @ ( posedge clk )
		begin
			field_mult[pts] <= ( field_zero[pts] == 1'B1 )? DATA_ZERO : field_mults[pts][DATA_WIDTH+FRAC_WIDTH-1:FRAC_WIDTH];
		end
		// 调试用
		//assign	field_mult_s[pts] = field_mult[pts];
	end
endgenerate

always @ ( posedge clk )
begin
	field_mult_en 	<= field_mults_en;
	field_mults_en 	<= field_q_en;
end
	
// 加法树
genvar 	at_layer;
genvar	at_node_idx;
generate
	for ( at_layer = 0; at_layer < ATlayer; at_layer = at_layer + 1 )
	begin : ATtree
		//
		//assign	ATnode_ens[ at_layer ] = ATnode_en[ at_layer ];
		// 对于第0层，输入点对点乘法结果
		if ( at_layer == 0 )
		begin
			for ( at_node_idx = 0; at_node_idx < ( ATsize >> ( 1 + at_layer )); at_node_idx = at_node_idx + 1 )
			begin : layer_0
				always @ ( posedge clk )
				begin
					if ( rst == 1'B1 )
					begin
						if ( arith_type == CONV_TYPE )
							ATnode[ at_node_idx ] <= DATA_ZERO;
						else if ( arith_type == POOL_TYPE && pool_type == MAX_TYPE)
							ATnode[ at_node_idx ] <= DATA_MINF;
						else
							ATnode[ at_node_idx ] <= DATA_ZERO;
					end
					else if ( at_node_idx < Ksz && field_mult_en == 1'B1 )
						ATnode[ at_node_idx ] <= field_mult[ at_node_idx ];
				end
			
				//assign	ATnodes[ at_node_idx ] = ATnode[ at_node_idx ];
				
			end
			
			always @ ( posedge clk )
				ATnode_en[ at_layer ] <= field_mult_en;
		end
		// 对于其它层
		/*
		*/
		else 
		begin
			for ( at_node_idx = 0; at_node_idx < ( ATsize >> ( 1 + at_layer )); at_node_idx = at_node_idx + 1 )
			begin : layer_else
				always @ ( posedge clk )
				begin
					if ( rst == 1'B1 )
					begin
						if ( arith_type == POOL_TYPE && pool_type == MAX_TYPE )
							ATnode[ ATsize - ( ATsize >> ( at_layer )) + at_node_idx ] <= DATA_MINF;
						else
							ATnode[ ATsize - ( ATsize >> ( at_layer )) + at_node_idx ] <= DATA_ZERO;
					end
					else
					begin
						if ( arith_type == POOL_TYPE && pool_type == MAX_TYPE )
							ATnode[ ATsize - ( ATsize >> ( at_layer )) + at_node_idx ] <= 
								( ATnode[ ATsize - ( ATsize >> ( at_layer - 1 )) + ( at_node_idx <<< 1 )] > ATnode[ ATsize - ( ATsize >> ( at_layer - 1 )) + ( at_node_idx <<< 1 ) +1 ] )?
									ATnode[ ATsize - ( ATsize >> ( at_layer - 1 )) + ( at_node_idx <<< 1 )] : 
									ATnode[ ATsize - ( ATsize >> ( at_layer - 1 )) + ( at_node_idx <<< 1 ) +1 ];
						else
							ATnode[ ATsize - ( ATsize >> ( at_layer )) + at_node_idx ] <= 
								ATnode[ ATsize - ( ATsize >> ( at_layer - 1 )) + ( at_node_idx <<< 1 )] + 
								ATnode[ ATsize - ( ATsize >> ( at_layer - 1 )) + ( at_node_idx <<< 1 ) +1 ];
					end
				end
				
				//assign	ATnodes[ ATsize - ( ATsize >> ( at_layer )) + at_node_idx ] = ATnode[ ATsize - ( ATsize >> ( at_layer )) + at_node_idx ];
				
			end
			
			always @ ( posedge clk )
				ATnode_en[ at_layer ] <= ATnode_en[ at_layer - 1 ];
		end
	end
endgenerate

// 输入定点除法器，实现pool（mean-pool）
always @ ( posedge clk )
begin
	if ( rst == 1'B1 && arith_type == POOL_TYPE )
	begin
		div_numer			<= width;
		// mean_pool要 / 卷积核尺度
		div_denom			<= kernel_n;
		div_src_en			<= 1'B1;
	end
	else
	begin
		div_numer			<= ATnode[ ATsize - ( ATsize >> ( ATlayer - 1 ) ) ];
		// mean_pool要 / 卷积核尺度
		div_denom			<= ( arith_type == POOL_TYPE && pool_type == MEAN_TYPE )? {32'D0, ( kernel_m * kernel_n ), {FRAC_WIDTH{1'B0}}} : DATA_UNIT;
		div_src_en			<= ATnode_en[ ATlayer - 1 ];
	end
end
// 统计输出的行列计数
always @ ( posedge clk )
begin
	if ( rst == 1'B1 )
	begin
		ConvResRow 		<= 0;
		ConvResCol		<= 0;
	end
	// 如果AT加法树结果有效，行列计数
	else if ( pool_opt_col_rdy == 1'B1 && div_dst_en == 1'B1 )
	begin
		if ( ConvResCol >= ( width - 1 ) )
		begin	
			ConvResRow	<= ConvResRow + 1;
			ConvResCol	<= 0;
		end
		else
			ConvResCol	<= ConvResCol + 1;
	end
end
// 统计输出的循环行列计数
always @ ( posedge clk )
begin
	if ( rst == 1'B1 )
	begin
		ConvCycRow 		<= 0;
		ConvCycCol		<= 0;
	end
	// 如果AT加法树结果有效，行列计数
	else if ( pool_opt_col_rdy == 1'B1 && div_dst_en == 1'B1 )
	begin
		if ( ConvCycCol >= ( kernel_n - 1 ) || ConvResCol >= ( width - 1 ))
			ConvCycCol	<= 0;
		else
			ConvCycCol	<= ConvCycCol + 1;
		//
		if ( ConvResCol >= ( width - 1 ) )
		begin
			//
			if ( ConvCycRow >= ( kernel_m - 1 ))
				ConvCycRow	<= 0;
			else
				ConvCycRow	<= ConvCycRow + 1;
		end
	end
end


// 最后生成卷积结果
// 过滤掉无效的卷及结果
assign	write_data_validx = ( arith_type == CONV_TYPE )? ( pool_opt_col_rdy && div_dst_en && ( ConvResCol >= ( kernel_n - 1 )) && ( ConvResRow >= ( kernel_m - 1 )) ) : 
							( arith_type == POOL_TYPE )? ( pool_opt_col_rdy && div_dst_en && ( ConvCycCol == ( kernel_n - 1 )) && ( ConvCycRow == ( kernel_m - 1 )) ) : 
							1'B0;
// 寄存器打一拍输出
always @ ( posedge clk )
begin
	write_data 			<= div_quotient;
	write_data_valid 	<= write_data_validx;
end

// 因为pooloing池化运算，需要先计算最后输出的数据列数
always @ ( posedge clk )
	if ( rst == 1'B1 )
	begin
		if ( arith_type == POOL_TYPE )
			pool_opt_col_rdy 	<= 1'B0;
		else
			pool_opt_col_rdy 	<= 1'B1;
	end
	else if ( pool_opt_col_rdy == 1'B0 && div_dst_en == 1'B1 && arith_type == POOL_TYPE )
	begin
		pool_opt_col 			<= div_quotient>>>FRAC_WIDTH;
		pool_opt_col_rdy 		<= 1'B1;
	end

/*-------------------------------------------------------------------*\
	instances
\*-------------------------------------------------------------------*/
// 统计输出的一行数量
// 定点除法器
fixed_sdiv	u0_fixed_sdiv
(
	.sys_clk			( clk 				),
	.sys_rst_n			( !rst				),
	.numer				( div_numer			),
	.denom				( div_denom			),
	.quotient			( div_quotient		),
	.src_en				( div_src_en		),
	.dst_en				( div_dst_en		)
);

// 偏上缓存
genvar	rami;
generate
	for ( rami = 0; rami < Km; rami = rami + 1 )
	begin : ram
		//
		assign			ram_wraddr[rami]	= ram_waddr;
		assign			ram_data[rami] 		= read_data;
		assign			ram_wrreq[rami]		= read_data_valid && ( ram_wptr == rami );
		assign			ram_rdreq[rami] 	= 1'B1;
		assign			ram_rdaddr[rami]	= ( ram_wraddr[rami]==0 )? ( width - 1'B1 ) : ( ram_wraddr[rami] - 1'B1 );
		dpram_2p 
		#(
			.LOG2N		( logW 				),
			.DATA_WIDTH	( DATA_WIDTH		)
		) u_dpram_2p 
		(
			.wrclock	( clk 				),
			.data		( ram_data[rami] 	),
			.wrreq		( ram_wrreq[rami]	),
			.wraddr		( ram_wraddr[rami]	),
			.rdclock	( clk 				),
			.q			( ram_q[rami] 		),
			.rdreq		( ram_rdreq[rami]	),
			.rdaddr		( ram_rdaddr[rami]	)
		);
	end
endgenerate

endmodule