/*-------------------------------------------------------------------------*\
	FILE:			sc_fifo.v
	AUTHOR:			Xudong Chen
	CREATED BY:		Xudong Chen
	$Id$
	ABSTRACT:		behavioral code for dual-clock fifo module
	
	KEYWORDS:		scfifo, dpram
	MODIFICATION HISTORY:
	$Log$
		Xudong 		18/7/16			original version
\*-------------------------------------------------------------------------*/

module sc_fifo
#(
parameter	LOG2N = 6,				// 这是FIFO深度的对数值
parameter	N = (1<<LOG2N),			// FIFO的深度
parameter	DATA_WIDTH = 32,		// 数据宽度
parameter	ADDR_WIDTH = LOG2N 		// 地址宽度
)
(
input  	wire						aclr,			// 异步复位
input	wire						clock,			// 读写时钟
// 写入端口的信号线
input	wire	[DATA_WIDTH-1:0]	data,			// 写数据
input	wire						wrreq,			// 写请求
// 读取端口的信号线
output	reg		[DATA_WIDTH-1:0]	q,				// 读数据
input	wire						rdreq,			// 读请求
// 标志位
output	wire	[ADDR_WIDTH-1:0]	usedw,			// 写数据量
output	wire						full,			// 写满标志
output	wire						empty			// 写空标志
);

/*-------------------------------------------------------------------------*\
	signals
\*-------------------------------------------------------------------------*/

// 首先声明一块内存空间
reg		[DATA_WIDTH-1:0]			dpram	[0:N-1];	// 内存空间，试图转换成DPRAM
reg		[ADDR_WIDTH:0]				wr_addr;			// 写入地址
reg		[ADDR_WIDTH:0]				rd_addr;			// 读取地址

/*-------------------------------------------------------------------------*\
	timing
\*-------------------------------------------------------------------------*/

/*
	for writing:
		clock		_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|-
		aclr		__|-|____________________________________________
		wrreq		 ____|-----------------------------------|_______
		wraddr		 _|  0	 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |________
		data		 ____| d0| d1| d2| d3| d4| d5| d6| d7| d8|________
		
	for reading:
		clock		_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|-
		aclr		__|-|____________________________________________
		rdreq		 ____|-----------------------------------|_______
		rdaddr		 _|  0	 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |________
		q			 _| d0	 | d1| d2| d3| d4| d5| d6| d7| d8|________
	
*/

/*-------------------------------------------------------------------------*\
	process
\*-------------------------------------------------------------------------*/
// 首先是写入地址生成
always @(posedge clock or posedge aclr)
	if(aclr==1)
		wr_addr <= 0;
	else if(wrreq && !full)
		wr_addr <= wr_addr + {{(ADDR_WIDTH){1'B0}}, 1'B1};
		
// 然后是读取地址生成
always @(posedge clock or posedge aclr)
	if(aclr==1)
		rd_addr <= 0;
	else if(rdreq && !empty)
		rd_addr <= rd_addr + {{(ADDR_WIDTH){1'B0}}, 1'B1};
		
// 现在是内存的行为
// 写入
always @(posedge clock)
	if(wrreq && !full)
		dpram[wr_addr[ADDR_WIDTH-1:0]] <= data;
// 读取
always @(*)
	q = dpram[rd_addr[ADDR_WIDTH-1:0]];
//

// 然后是要生成一些标志信号
assign		usedw = (wr_addr - rd_addr + N);
assign		full  = (usedw>=N);
assign		empty = (usedw==0);
/*-------------------------------------------------------------------------*\
	instantiation
\*-------------------------------------------------------------------------*/
//////////////////////////////////////////////////////////////

endmodule