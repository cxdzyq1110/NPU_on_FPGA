module uart_wr
#(	
	parameter	UART_DATA_WIDTH = 8,    // uart 数据位宽
	parameter	UART_ADDR_WIDTH = 2,		// endpoint-地址位宽
	parameter	SYS_UART_DATA_MULT = 4,	// system 和 cypress uart 的数据位宽的比例
	parameter	SYS_DATA_WIDTH = UART_DATA_WIDTH*SYS_UART_DATA_MULT // system 的数据位宽
)
(
	input	wire						sys_clk, sys_rst_n, // 系统时钟和复位信号
	/* CYPRESS UART SLAVEFIFO */
	input	wire						uart_sys_clk, uart_sys_rst_n,
	input	wire						uart_rxd,
	output	wire						uart_txd,
	
	/* 和外界的接口 */
	input		[SYS_DATA_WIDTH-1:0]	sys_write_data,			// 要发送到 fifo的数据
	input								sys_write_data_valid,	// 要发送的数据有效
	output								sys_write_data_permitted,	// 允许发送数据
	output		[UART_DATA_WIDTH-1:0]	sys_read_data,			//  从 fifo 中获取的数据
	input								sys_read_data_req,		// 从 fifo 中获取的数据使能/请求
	output								sys_read_data_permitted		// 允许从fifo中获取数据
	);
	wire								logic_uart_write_data_empty;
	wire		[SYS_DATA_WIDTH-1:0]	logic_uart_write_data /* synthesis keep */;
	wire								logic_uart_write_data_valid = !logic_uart_write_data_empty /* synthesis keep */;
	wire								logic_uart_write_data_req;
	wire		[UART_DATA_WIDTH-1:0]	logic_uart_read_data /* synthesis keep*/;
	wire								logic_uart_read_data_valid /* synthesis keep*/;

	wire		[SYS_DATA_WIDTH-1:0]	logic_fifo_write_data /* synthesis keep */;
	wire								logic_fifo_write_data_valid /* synthesis keep */;
	wire		[5:0]					logic_fifo_write_usedw /* synthesis keep */;
	wire								logic_fifo_write_full /* synthesis keep */;
	wire		[UART_DATA_WIDTH-1:0]	logic_fifo_read_data /* synthesis keep */;
	wire								logic_fifo_read_data_req /* synthesis keep */;
	wire								logic_fifo_read_empty /* synthesis keep */;

	// 和外部的接口赋值
	assign		logic_fifo_write_data = sys_write_data;
	assign		logic_fifo_write_data_valid = sys_write_data_valid;
	assign		sys_write_data_permitted = (logic_fifo_write_usedw[5:3]==0);	// 应该要留出大半部分的空间，用于缓冲
	assign		sys_read_data = logic_fifo_read_data;
	assign		logic_fifo_read_data_req = sys_read_data_req;
	assign		sys_read_data_permitted = !logic_fifo_read_empty;
	
	
	wire		uart_tx_busy;
	assign		logic_uart_write_data_req = !uart_tx_busy && !logic_uart_write_data_empty;
	// uart 状态机
	uart_rtl			uart_rtl_inst(
							.clock(uart_sys_clk),
							.rst(!uart_sys_rst_n),
							.uart_rxd(uart_rxd),
							.uart_txd(uart_txd),
							// system
							.rx_en(logic_uart_read_data_valid),
							.rx_data(logic_uart_read_data),
							.tx_en(logic_uart_write_data_req),
							.tx_busy(uart_tx_busy),
							.tx_data(logic_uart_write_data)
						);
						
	// 然后例化1个发送数据的dcfifo
//	alt_fifo_32b_64w		
	dc_fifo				#(
							.LOG2N(6),
							.DATA_WIDTH(32)
						)
						alt_fifo_32b_64w_inst(
							.aclr(!uart_sys_rst_n),
							.wrclock(sys_clk),
							.wrreq(logic_fifo_write_data_valid),
							.data(logic_fifo_write_data),
							.wrfull(logic_fifo_write_full),
							.wrusedw(logic_fifo_write_usedw),
							.rdclock(uart_sys_clk),
							.rdreq(logic_uart_write_data_req),
							.q(logic_uart_write_data),
							.rdempty(logic_uart_write_data_empty)
						);	
	// 再是例化一个用于接收slavefifo里面的数据的dcfifo
//	alt_fifo_8b_4w			
	dc_fifo				#(
							.LOG2N(4),
							.DATA_WIDTH(8)
						)
						alt_fifo_8b_4w_inst(
							.aclr(!uart_sys_rst_n),
							.wrclock(uart_sys_clk),
							.wrreq(logic_uart_read_data_valid),
							.data(logic_uart_read_data),
							.rdclock(sys_clk),
							.rdreq(logic_fifo_read_data_req),
							.q(logic_fifo_read_data),
							.rdempty(logic_fifo_read_empty)
						);
						
endmodule