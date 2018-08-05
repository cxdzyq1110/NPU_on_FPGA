/*-------------------------------------------------------------------------*\
	FILE:			dpram_2p.v
	AUTHOR:			Xudong Chen
	CREATED BY:		Xudong Chen
	$Id$
	ABSTRACT:		behavioral code for dual-clock ram module
	
	KEYWORDS:		dpram
	MODIFICATION HISTORY:
	$Log$
		Xudong 		18/6/20			original version
\*-------------------------------------------------------------------------*/

module dpram_2p
#(
parameter	LOG2N = 6,				// 这是FIFO深度的对数值
parameter	N = (1<<LOG2N),			// FIFO的深度
parameter	DATA_WIDTH = 32,		// 数据宽度
parameter	ADDR_WIDTH = LOG2N 		// 地址宽度
)
(

input  	wire						aclr,			// 异步复位
// 写入端口的信号线
input	wire						wrclock,		// 写时钟
input	wire	[DATA_WIDTH-1:0]	data,			// 写数据
input	wire						wrreq,			// 写请求
input	wire	[ADDR_WIDTH-1:0]	wraddr,			// 写地址
// 读取端口的信号线
input	wire						rdclock,		// 读时钟
output	reg		[DATA_WIDTH-1:0]	q,				// 读数据
input	wire						rdreq,			// 读请求
input	wire	[ADDR_WIDTH-1:0]	rdaddr			// 读地址
);

/*-------------------------------------------------------------------------*\
	signals
\*-------------------------------------------------------------------------*/

// 首先声明一块内存空间
reg		[DATA_WIDTH-1:0]			dpram	[0:N-1];	// 内存空间，试图转换成DPRAM
reg		[ADDR_WIDTH-1:0]			wraddrx;			// 写入地址
reg		[DATA_WIDTH-1:0]			datax;
reg									wrreqx;
reg									rdreqx;
reg		[ADDR_WIDTH-1:0]			rdaddrx;			// 读取地址


/*-------------------------------------------------------------------------*\
	timing
\*-------------------------------------------------------------------------*/

/*
	for writing:
		wrclock		_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|-
		wraddr		 ____| a1| a2| a3| a4| a5| a6| a7| a8| a9|________
		data		 ____| d1| d2| d3| d4| d5| d6| d7| d8| d9|________
		wrreq		 ____|-----------------------------------|_______
		
	for reading:
		rdclock		_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|_|-|-
		rdaddr		 ____| a1| a2| a3| a4| a5| a6| a7| a8| a9|________
		rdreq		 ____|-----------------------------------|_______
		rdaddrx		_________| a1| a2| a3| a4| a5| a6| a7| a8| a9|________
		rdreqx		_________|-----------------------------------|_______
		q			 	_________| d1| d2| d3| d4| d5| d6| d7| d8| d9|___
	
*/

/*-------------------------------------------------------------------------*\
	process
\*-------------------------------------------------------------------------*/
// 首先是写入地址生成
always @(posedge wrclock or posedge aclr)
	if(aclr==1)
	begin
		wraddrx <= 0;
		wrreqx 	<= 0;
		datax 	<= 0;
	end
	else
	begin
		wraddrx <= wraddr;
		wrreqx 	<= wrreq;
		datax 	<= data;
	end
		
// 然后是读取地址生成
always @(posedge rdclock or posedge aclr)
	if(aclr==1)
	begin
		rdaddrx <= 0;
		rdreqx 	<= 0;
	end
	else
	begin
		rdaddrx <= rdaddr;
		rdreqx 	<= rdreq;
	end
		
// 现在是内存的行为
// 写入
always @(posedge wrclock)
	if(wrreqx==1)
		dpram[wraddrx[ADDR_WIDTH-1:0]] <= datax;
// 读取
always @(posedge rdclock)
	if(rdreqx==1)
		q <= dpram[rdaddrx[ADDR_WIDTH-1:0]];
//

//////////////////////////////////////////////////////////////

endmodule