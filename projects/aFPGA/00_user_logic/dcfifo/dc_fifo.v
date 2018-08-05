/*-------------------------------------------------------------------------*\
	FILE:			dc_fifo.v
	AUTHOR:			Xudong Chen
	CREATED BY:		Xudong Chen
	$Id$
	ABSTRACT:		behavioral code for dual-clock fifo module
	
	KEYWORDS:		dcfifo, dpram
	MODIFICATION HISTORY:
	$Log$
		Xudong 		18/6/20			original version
		Xudong  	18/6/21			add synthesis preserve to gray-enc/dec
		Xudong 		18/6/26			add sync stage parameter
\*-------------------------------------------------------------------------*/

module dc_fifo
#(
parameter	LOG2N = 6,				// 这是FIFO深度的对数值
parameter	N = (1<<LOG2N),			// FIFO的深度
parameter	DATA_WIDTH = 32,		// 数据宽度
parameter	ADDR_WIDTH = LOG2N,		// 地址宽度
parameter	SYNC_STAGE = 4			// 同步级数
)
(
input  	wire						aclr,			// 异步复位
// 写入端口的信号线
input	wire						wrclock,		// 写时钟
input	wire	[DATA_WIDTH-1:0]	data,			// 写数据
input	wire						wrreq,			// 写请求
output	wire	[ADDR_WIDTH-1:0]	wrusedw,		// 写数据量
output	wire						wrfull,			// 写满标志
output	wire						wrempty,		// 写空标志
// 读取端口的信号线
input	wire						rdclock,		// 读时钟
output	reg		[DATA_WIDTH-1:0]	q,				// 读数据
input	wire						rdreq,			// 读请求
output	wire	[ADDR_WIDTH-1:0]	rdusedw,		// 读数据量
output	wire						rdfull,			// 读满标志
output	wire						rdempty			// 读空标志
);

/*-------------------------------------------------------------------------*\
	signals
\*-------------------------------------------------------------------------*/

// 首先声明一块内存空间
reg		[DATA_WIDTH-1:0]			dpram	[0:N-1];	// 内存空间，试图转换成DPRAM
reg		[ADDR_WIDTH:0]				wr_addr;			// 写入地址
reg		[ADDR_WIDTH:0]				rd_addr;			// 读取地址

/////////////// 然后是gray码
wire	[ADDR_WIDTH:0]				wr_addr_gray_enc /* synthesis preserve */;	// 1-clock pipeline
wire	[ADDR_WIDTH:0]				rd_addr_gray_enc /* synthesis preserve */;	// 1-clock pipeline

// 同步时钟域
wire	[ADDR_WIDTH:0]				wr_addr_gray_sync /* synthesis preserve */;	// write-gray --> read-clock
wire	[ADDR_WIDTH:0]				rd_addr_gray_sync /* synthesis preserve */;	// read-gray --> write-clock

// 最后是格雷码译码
wire	[ADDR_WIDTH:0]				wr_addr_gray_dec /* synthesis preserve */;	// write-addr --> read-clock
wire	[ADDR_WIDTH:0]				rd_addr_gray_dec /* synthesis preserve */;	// read-addr --> write-clock
/*-------------------------------------------------------------------------*\
	process
\*-------------------------------------------------------------------------*/
// 首先是写入地址生成
always @(posedge wrclock or posedge aclr)
	if(aclr==1)
		wr_addr <= 0;
	else if(wrreq && !wrfull)
		wr_addr <= wr_addr + {{(ADDR_WIDTH){1'B0}}, 1'B1};
		
// 然后是读取地址生成
always @(posedge rdclock or posedge aclr)
	if(aclr==1)
		rd_addr <= 0;
	else if(rdreq && !rdempty)
		rd_addr <= rd_addr + {{(ADDR_WIDTH){1'B0}}, 1'B1};
		
// 现在是内存的行为
// 写入
always @(posedge wrclock)
	if(wrreq && !wrfull)
		dpram[wr_addr[ADDR_WIDTH-1:0]] <= data;
// 读取
always @(*)
	q = dpram[rd_addr[ADDR_WIDTH-1:0]];
//

// 然后是要生成一些标志信号
assign		wrusedw = (wr_addr - rd_addr_gray_dec + N);
assign		wrfull 	= (wrusedw>=(N-SYNC_STAGE-4));
assign		wrempty = (wrusedw==0);
assign		rdusedw = (wr_addr_gray_dec - rd_addr + N);
assign		rdfull 	= (rdusedw>=(N-SYNC_STAGE-4));
assign		rdempty = (rdusedw==0);
/*-------------------------------------------------------------------------*\
	instantiation
\*-------------------------------------------------------------------------*/
// 例化格雷码编码模块	
gray_enc_1p		
#(
	.WIDTH(ADDR_WIDTH+1)
)
u0_gray_enc_1p(
	.clock(wrclock),
	.src(wr_addr),
	.dst(wr_addr_gray_enc)
);

gray_enc_1p		
#(
	.WIDTH(ADDR_WIDTH+1)
)
u1_gray_enc_1p(
	.clock(rdclock),
	.src(rd_addr),
	.dst(rd_addr_gray_enc)
);
// 例化时钟域同步器
sync_dual_clock
#(
	.WIDTH(ADDR_WIDTH+1),
	.SYNC_STAGE(SYNC_STAGE)
)
u0_sync_dual_clock
(
	.clock_dst(rdclock),
	.src(wr_addr_gray_enc),
	.dst(wr_addr_gray_sync)
);
sync_dual_clock
#(
	.WIDTH(ADDR_WIDTH+1),
	.SYNC_STAGE(SYNC_STAGE)
)
u1_sync_dual_clock
(
	.clock_dst(wrclock),
	.src(rd_addr_gray_enc),
	.dst(rd_addr_gray_sync)
);

gray_dec_1p		
#(
	.WIDTH(ADDR_WIDTH+1)
)
u0_gray_dec_1p(
	.clock(wrclock),
	.src(rd_addr_gray_sync),
	.dst(rd_addr_gray_dec)
);

gray_dec_1p		
#(
	.WIDTH(ADDR_WIDTH+1)
)
u1_gray_dec_1p(
	.clock(rdclock),
	.src(wr_addr_gray_sync),
	.dst(wr_addr_gray_dec)
);

//////////////////////////////////////////////////////////////

endmodule