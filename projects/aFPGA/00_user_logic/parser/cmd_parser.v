module cmd_parser
#(	
	parameter	UART_DATA_WIDTH = 8,    // uart 数据位宽
	parameter	UART_ADDR_WIDTH = 2,		// endpoint-地址位宽
	parameter	SYS_UART_DATA_MULT = 4,	// system 和 cypress uart 的数据位宽的比例
	parameter	SYS_DATA_WIDTH = UART_DATA_WIDTH*SYS_UART_DATA_MULT // system 的数据位宽
)
(
	output	wire						receive_valid_cmd,	// 收到有效命令
	input	wire						sys_clk, sys_rst_n, // 系统时钟和复位信号
	input	wire	[5:1]				sys_key_fn,		// 按键，用于调控！
	//
	input	wire [SYS_DATA_WIDTH-1:0]	adc_ddr_write_addr,			// adc要写入ddr的地址
	input	wire [SYS_DATA_WIDTH-1:0]	adc_ddr_write_addr_mask,			// adc要写入ddr的地址掩码
	// 要控制音频信号的采集
	output	reg							audio_sample_en,	// 音频采集使能
	// 最后，是传输NPU指令（允许通过串口修改NPU运行的指令）
	output	reg	[SYS_DATA_WIDTH-1:0]	npu_inst_part,
	output	reg							npu_inst_part_en,	
	//  uart
	output	reg	[SYS_DATA_WIDTH-1:0]	sys_uart_write_data,			// 要发送到 fifo的数据
	output	reg							sys_uart_write_data_valid,	// 要发送的数据有效
	input								sys_uart_write_data_permitted,	// 允许发送数据
	input		[UART_DATA_WIDTH-1:0]	sys_uart_read_data,			//  从 fifo 中获取的数据
	output	reg							sys_uart_read_data_req,		// 从 fifo 中获取的数据使能/请求
	input								sys_uart_read_data_permitted,		// 允许从fifo中获取数据
	// ddr
	output	reg	[SYS_DATA_WIDTH-1:0]	sys_ddr_write_addr,			// 要写入ddr的地址
	output	reg	[SYS_DATA_WIDTH-1:0]	sys_ddr_write_data,			// 要发送到 ddr的数据
	output	reg							sys_ddr_write_data_valid,	// 要发送ddr的数据有效
	output	reg							sys_ddr_write_burst_begin,	// 要发送ddr的burst突发请求（1-clock宽度）
	input								sys_ddr_write_data_permitted,	// 允许发送ddr数据
	output	reg	[SYS_DATA_WIDTH-1:0]	sys_ddr_read_addr,			// 要读取 ddr的地址
	input		[SYS_DATA_WIDTH-1:0]	sys_ddr_read_data,			//  从 ddr 中获取的数据
	input								sys_ddr_read_data_valid,		//  从 ddr 中获取的数据有效
	output	reg							sys_ddr_read_burst_begin,	// 要读取ddr的burst突发请求（1-clock宽度）
	output	reg							sys_ddr_read_data_req,		// 从 ddr 中获取的数据使能/请求
	input								sys_ddr_read_data_permitted		// 允许从 ddr 中获取数据
);
	
// 首先，要能根据rfifo的情况，获取uart发送过来的命令
// 使用状态机：0看，1拿，2求，3空
reg		[3:0]	read_cnt;
reg		[127:0]	uart_cmd_shift /* synthesis noprune */;
always @(posedge sys_clk)
	if(!sys_rst_n)
	begin
		uart_cmd_shift <= 0;
		read_cnt <= 0;
	end
	else 
	begin
		case(read_cnt)
			// 生成rfifo的读取使能信号
			0: begin
				if(sys_uart_read_data_permitted)
				begin
					read_cnt <= 1;
					sys_uart_read_data_req <= 0;
				end
			end
			
			// 要把收到的命令进行移位存储
			1: begin
				read_cnt <= 2;
				uart_cmd_shift <= {uart_cmd_shift[119:0], 
									sys_uart_read_data[7:0]
								};
				sys_uart_read_data_req <= 1;	// 生成FIFO读取请求
			end
			
			// 撤销rfifo的读取时能信号
			2: begin
				read_cnt <= 3;
				sys_uart_read_data_req <= 0;
			end
			
			// 这个3主要是为了能够“凑时序”，在uart-cmd_shift移位之后给出使能
			3: 	read_cnt <= 0;
			
			default:
				read_cnt <= 0;
		endcase
	end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////	
	////////////////////////////////////////////
	// 如果收到 hello  = {68,65,6c,6c,6f, xx, yy, zz, aa} 其中{xx, yy, zz, aa} 表示要发送的数据量（32 bit为单元）
	// 就要返回 helloworldhh = {68,65,6c,6c,6f, 77 6F 72 6C 64 68 68, mm, nn, ...} 其中{mm, nn}表示的是要发送的数据
	reg		[31:0]		send_back_cnt;
	
	reg					test_uart_cmd;	// 测试uart的命令(hello/xxxx)
	reg					read_ddr_cmd;	// 读取ddr的命令(r_ddr/xxxx)
	reg					write_ddr_cmd; // 写入ddr的命令(w_ddr/xxxx/yyyy)
	reg					cont_read_cmd; // 连续读取ddr的命令(contr/xxxx/yyyy)
	reg					cont_write_cmd; // 写入ddr的命令(contw/xxxx/yyyy)
	reg					adc_read_cmd;	// 要读取adc写入ddr的命令(cradc/ffff/yyyy)
	reg					audio_sample_cmd;	// 要采集音频信号的命令(audio/tttttttt)
	reg					measure_ram_cmd;	// 测试RAM的读写速度的命令(msddr/xxxx/yyyy)	
	reg					npu_inst_cmd;		// 传输的是NPU指令的命令（npust/tttttttt)
	always @(posedge sys_clk)
	begin
		test_uart_cmd <= (uart_cmd_shift[79:40]==40'H68656C6C6F && (read_cnt==3));	
		read_ddr_cmd <= (uart_cmd_shift[79:40]==40'H725F646472 && (read_cnt==3));
		write_ddr_cmd <= (uart_cmd_shift[111:72]==40'H775F646472 && (read_cnt==3));
		cont_read_cmd <= (uart_cmd_shift[111:72]==40'H636F6E7472  && (read_cnt==3));
		cont_write_cmd <= (uart_cmd_shift[111:72]==40'H636F6E7477 && (read_cnt==3));
		adc_read_cmd <= (uart_cmd_shift[111:72]==40'H6372616463 && (read_cnt==3));
		audio_sample_cmd <= (uart_cmd_shift[79:40]==40'H617564696F && (read_cnt==3));
		measure_ram_cmd <= (uart_cmd_shift[111:72]==40'H6D73646472 && (read_cnt==3));
		npu_inst_cmd <= (uart_cmd_shift[79:40]==40'H6E70757374 && (read_cnt==3));
	end
	
	assign				receive_valid_cmd = (npu_inst_cmd|test_uart_cmd|read_ddr_cmd|write_ddr_cmd|cont_read_cmd|cont_write_cmd|adc_read_cmd|audio_sample_cmd|measure_ram_cmd);
	reg		[8:0]		receive_cmd_type;
	always @(posedge sys_clk)
		if(receive_valid_cmd)
			receive_cmd_type <= {npu_inst_cmd, measure_ram_cmd, audio_sample_cmd, adc_read_cmd, cont_write_cmd, cont_read_cmd, write_ddr_cmd, read_ddr_cmd, test_uart_cmd};
	
	/////////////////
	// DDR-HMC出来的数据 sys_ddr_read_data 和数据有效 sys_ddr_read_data_valid 路径太长
	// 所以中间再用register打一拍，拆开这条路径
	reg		[SYS_DATA_WIDTH-1:0]	sys_ddr_read_data_reg;
	reg								sys_ddr_read_data_valid_reg;
	always @(posedge sys_clk)
	begin
		sys_ddr_read_data_reg <= sys_ddr_read_data;
		sys_ddr_read_data_valid_reg <= sys_ddr_read_data_valid;
	end
	/////////////////////////////////
	// 为了优化时序，所以要把uart_cmd_shift 打一拍
	reg		[127:0]		uart_cmd_shift_reg;
	always @(posedge sys_clk)
		if(receive_valid_cmd)	// 可恶！居然漏了！这样的话，一旦发送命令的时候多了0x0D/0x0A就会出错！	2018-05-04
			uart_cmd_shift_reg <= uart_cmd_shift;
	// 此外，由于发送到uart的fifo已经是一个安全深度了， 可以把 sys_ddr_write_data_permitted 也打一拍
	reg		sys_uart_write_data_permitted_reg;
	always @(posedge sys_clk)
		sys_uart_write_data_permitted_reg <= sys_uart_write_data_permitted;
	
////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 要读写ddr的接口
// 考虑到wfifo的almost full状态，以及HMC核的闲置与否，这里引入
// wfifo的写入锁与HMC的读取锁
// HMC的写入锁，使用状态机来实现
	reg		[4:0]		ddr_wr_state;
	reg		[31:0]		ddr_wr_number;	// 计数 ddr 读写的次数
	reg		[31:0]		ddr_wr_time;	// 计量DDR读写的时间
	always @(posedge sys_clk)
		if(!sys_rst_n)
		begin
			sys_ddr_read_data_req <= 0;		// 撤销读取请求
			sys_ddr_write_data_valid <= 0;	// 撤销写入请求
			sys_ddr_read_burst_begin <= 0;		// 撤销读取burst请求
			sys_ddr_write_burst_begin <= 0;	// 撤销写入burst请求
			ddr_wr_state <= 0;	// 复位ddr读写状态机
			// 撤销音频采样
			audio_sample_en <= 0;		
			// 清除NPU指令有效
			npu_inst_part_en <= 0;
		end
		else
		begin
			case(ddr_wr_state)
				0:	begin
					sys_ddr_read_data_req <= 0;		// 撤销读取请求
					sys_ddr_write_data_valid <= 0;	// 撤销写入请求
					sys_ddr_read_burst_begin <= 0;		// 撤销读取burst请求
					sys_ddr_write_burst_begin <= 0;	// 撤销写入burst请求
					// 清除NPU指令有效
					npu_inst_part_en <= 0;
					//
					// 读取ddr请求
					if(read_ddr_cmd)
						ddr_wr_state <= 1;
					// 写入ddr请求
					else if(write_ddr_cmd)
						ddr_wr_state <= 3;
					// 连续写入ddr的请求
					else if(cont_write_cmd)
					begin
						ddr_wr_state <= 5;
						ddr_wr_number <= 0;
					end
					// 连续读取ddr的请求
					else if(cont_read_cmd)
					begin
						ddr_wr_state <= 7;
						ddr_wr_number <= 0;
					end
					// 连续读取adc写入的数据
					else if(adc_read_cmd)
					begin
						ddr_wr_state <= 10;
						ddr_wr_number <= 0;
					end
					// 采集音频信号
					else if(audio_sample_cmd)
					begin
						ddr_wr_state <= 13;
						ddr_wr_number <= 0;
						audio_sample_en <= 1;	// 使能音频采样
					end
					// 测试DDR读写速率的指令
					else if(measure_ram_cmd)
					begin
						ddr_wr_state <= 14;	// 首先是进行写入测速
						ddr_wr_number <= 0;
						ddr_wr_time <= 0;	// 计时器清零
					end
					// 传输NPU指令的命令
					else if(npu_inst_cmd)
					begin
						ddr_wr_state <= 18;
					end
				end
				
				// 单次读取
				1: begin
					// 检查ddr是否允许读取
					if(sys_ddr_read_data_permitted)
					begin	
						sys_ddr_read_addr <= uart_cmd_shift_reg[39:8];
						sys_ddr_read_data_req <= 1;
						sys_ddr_read_burst_begin <= 1;	// 给出读取burst请求（但在下一个clock撤销！）
						ddr_wr_state <= 2;
					end
				end
				
				2: begin
					sys_ddr_read_burst_begin <= 0;		// 撤销读取burst请求
					// 等待ddr读取完成
					if(sys_ddr_read_data_permitted)
					begin	
						//sys_ddr_read_addr <= 0;
						sys_ddr_read_data_req <= 0;
						ddr_wr_state <= 0;
					end
				end	
					
				// 单次写入
				3: begin
					// 检查ddr是否允许写入
					if(sys_ddr_write_data_permitted)
					begin
						sys_ddr_write_addr <= uart_cmd_shift_reg[71:40];
						sys_ddr_write_data <= uart_cmd_shift_reg[39:8];
						sys_ddr_write_data_valid <= 1;
						sys_ddr_write_burst_begin <= 1;	// 给出写入burst请求（但在下一个clock撤销！）
						ddr_wr_state <= 4;
					end
				end
				
				4: begin
					sys_ddr_write_burst_begin <= 0;	// 撤销写入burst请求
					// 等待ddr写入完成
					if(sys_ddr_write_data_permitted)
					begin	
						//sys_ddr_write_addr <= 0;
						//sys_ddr_write_data <= 0;
						sys_ddr_write_data_valid <= 0;
						ddr_wr_state <= 0;
					end
				end	
				
				
				// 连续写入
				5: begin
					// 检查ddr是否允许写入
					if(sys_ddr_write_data_permitted)
					begin
						sys_ddr_write_addr <= uart_cmd_shift_reg[71:40];
						sys_ddr_write_data <= uart_cmd_shift_reg[71:40];	// 地址和数据一致
						sys_ddr_write_data_valid <= 1;
						sys_ddr_write_burst_begin <= 1;	// 给出写入burst请求（但在下一个clock撤销！）
						ddr_wr_state <= 6;
						// 计数++
						ddr_wr_number <= ddr_wr_number+1;
					end
				end
				
				6: begin
					sys_ddr_write_burst_begin <= 0;	// 撤销写入burst请求
					// 等待ddr写入完成
					if(sys_ddr_write_data_permitted)
					begin	
						sys_ddr_write_addr <= sys_ddr_write_addr+1;
						sys_ddr_write_data <= sys_ddr_write_data+1;
						if(ddr_wr_number<uart_cmd_shift_reg[39:8])
						begin
							sys_ddr_write_data_valid <= 1;
							ddr_wr_number <= ddr_wr_number+1;
						end
						else 
						begin
							sys_ddr_write_data_valid <= 0;
							ddr_wr_state <= 0;
						end
					end
				end	
				
				// 连续读取ddr的命令
				7: begin
					// 检查ddr是否允许读取
					if(sys_ddr_read_data_permitted)
					begin	
						sys_ddr_read_addr <= uart_cmd_shift_reg[71:40];
						sys_ddr_read_data_req <= 1;
						sys_ddr_read_burst_begin <= 1;	// 给出读取burst请求（但在下一个clock撤销！）
						ddr_wr_state <= 8;
						// 计数++
						ddr_wr_number <= ddr_wr_number+1;
					end
				end
				
				8: begin
					sys_ddr_read_burst_begin <= 0;		// 撤销读取burst请求
					// 等待ddr读取完成
					if(sys_ddr_read_data_permitted)
					begin	
						// 考察是不是读取够了，如果不够，就要考察slavefifo是否允许写入
						if(ddr_wr_number<uart_cmd_shift_reg[39:8])
						begin
							// 如果允许uart写入，那么ddr的读取地址++，并且给出读取请求
							if(sys_uart_write_data_permitted_reg)
							begin
								sys_ddr_read_addr <= sys_ddr_read_addr+1;
								sys_ddr_read_data_req <= 1;
								// 计数++
								ddr_wr_number <= ddr_wr_number+1;
							end
							// 如果uart不能写入，那么撤销ddr读取请求
							// ，并且跳到新的状态，需要重新给出burst_begin
							else
							begin
								sys_ddr_read_data_req <= 0;
								ddr_wr_state <= 9;
							end
						end
						// 读取够了，就要跳出循环
						else 
						begin
							sys_ddr_read_data_req <= 0;
							ddr_wr_state <= 0;
						end
					end
				end	
				
				9: begin
					// 检查uart是否允许写入
					if(sys_uart_write_data_permitted_reg)
					begin	
						sys_ddr_read_addr <= sys_ddr_read_addr+1;
						sys_ddr_read_data_req <= 1;
						sys_ddr_read_burst_begin <= 1;	// 给出读取burst请求（但在下一个clock撤销！）
						ddr_wr_state <= 8;
						// 计数++
						ddr_wr_number <= ddr_wr_number+1;
					end
				end
				/////////////////////////////////////////////////
				
				// 连续读取adc写入ddr数据的命令
				10: begin
					// 检查ddr是否允许读取
					if(sys_ddr_read_data_permitted)
					begin	
						sys_ddr_read_addr <= ((adc_ddr_write_addr-uart_cmd_shift_reg[39:8])&adc_ddr_write_addr_mask);
						sys_ddr_read_data_req <= 1;
						sys_ddr_read_burst_begin <= 1;	// 给出读取burst请求（但在下一个clock撤销！）
						ddr_wr_state <= 11;
						// 计数++
						ddr_wr_number <= ddr_wr_number+1;
					end
				end
				
				11: begin
					sys_ddr_read_burst_begin <= 0;		// 撤销读取burst请求
					// 等待ddr读取完成
					if(sys_ddr_read_data_permitted)
					begin	
						// 考察是不是读取够了，如果不够，就要考察slavefifo是否允许写入
						if(ddr_wr_number<uart_cmd_shift_reg[39:8])
						begin
							// 如果允许uart写入，那么ddr的读取地址++，并且给出读取请求
							if(sys_uart_write_data_permitted_reg)
							begin
								sys_ddr_read_addr <= ((sys_ddr_read_addr+1)&adc_ddr_write_addr_mask);
								sys_ddr_read_data_req <= 1;
								// 计数++
								ddr_wr_number <= ddr_wr_number+1;
							end
							// 如果uart不能写入，那么撤销ddr读取请求
							// ，并且跳到新的状态，需要重新给出burst_begin
							else
							begin
								sys_ddr_read_data_req <= 0;
								ddr_wr_state <= 12;
							end
						end
						// 读取够了，就要跳出循环
						else 
						begin
							sys_ddr_read_data_req <= 0;
							ddr_wr_state <= 0;
						end
					end
				end	
				
				12: begin
					// 检查uart是否允许写入
					if(sys_uart_write_data_permitted_reg)
					begin	
						sys_ddr_read_addr <= ((sys_ddr_read_addr+1)&adc_ddr_write_addr_mask);
						sys_ddr_read_data_req <= 1;
						sys_ddr_read_burst_begin <= 1;	// 给出读取burst请求（但在下一个clock撤销！）
						ddr_wr_state <= 11;
						// 计数++
						ddr_wr_number <= ddr_wr_number+1;
					end
				end
				
				13: begin
					// 等待tttttttt个clock
					if(ddr_wr_number>=uart_cmd_shift_reg[39:8])
					begin
						audio_sample_en <= 0;	// 采集够了，关断写入
						ddr_wr_number <= 0;
						ddr_wr_state <= 0;
					end
					else
						ddr_wr_number <= ddr_wr_number + 1;	// 否则继续采集
				end
				
				// 进行DDR读写测试
				14: begin
					ddr_wr_time <= ddr_wr_time + 1;
					// 检查ddr是否允许写入
					if(sys_ddr_write_data_permitted)
					begin
						sys_ddr_write_addr <= uart_cmd_shift_reg[71:40];
						sys_ddr_write_data <= uart_cmd_shift_reg[71:40];	// 地址和数据一致
						sys_ddr_write_data_valid <= 1;
						ddr_wr_state <= 15;
						// 计数++
						ddr_wr_number <= ddr_wr_number+1;
					end
				end
				
				15: begin
					ddr_wr_time <= ddr_wr_time + 1;
					// 等待ddr写入完成
					if(sys_ddr_write_data_permitted)
					begin	
						sys_ddr_write_addr <= sys_ddr_write_addr+1;
						sys_ddr_write_data <= sys_ddr_write_data+1;
						if(ddr_wr_number<uart_cmd_shift_reg[39:8])
						begin
							sys_ddr_write_data_valid <= 1;
							ddr_wr_number <= ddr_wr_number+1;
						end
						else 
						begin
							sys_ddr_write_data_valid <= 0;
							ddr_wr_state <= 16;	// 然后进行DDR读取测试
							ddr_wr_number <= 0;
						end
					end
				end	
				
				16: begin
					ddr_wr_time <= ddr_wr_time + 1;
					// 检查ddr是否允许读取
					if(sys_ddr_read_data_permitted)
					begin
						sys_ddr_read_addr <= uart_cmd_shift_reg[71:40];
						sys_ddr_read_data_req <= 1;
						ddr_wr_state <= 17;
						// 计数++
						ddr_wr_number <= ddr_wr_number+1;
					end
				end
				
				17: begin
					ddr_wr_time <= ddr_wr_time + 1;
					// 等待ddr写入完成
					if(sys_ddr_read_data_permitted)
					begin	
						sys_ddr_read_addr <= sys_ddr_read_addr+1;
						if(ddr_wr_number<uart_cmd_shift_reg[39:8])
						begin
							sys_ddr_read_data_req <= 1;
							ddr_wr_number <= ddr_wr_number+1;
						end
						else 
						begin
							sys_ddr_read_data_req <= 0;
							ddr_wr_state <= 0;	// 然后回到IDLE状态
						end
					end
				end	
				
				// 传输NPU指令的命令
				18: begin
					npu_inst_part <= uart_cmd_shift_reg[39:8];
					npu_inst_part_en <= 1;
					ddr_wr_state <= 0;	// 然后回到IDLE状态
				end
				//////////////////////////////////////////////
				
				default: begin
					sys_ddr_read_data_req <= 0;		// 撤销读取请求
					sys_ddr_write_data_valid <= 0;	// 撤销写入请求
					sys_ddr_read_burst_begin <= 0;		// 撤销读取burst请求
					sys_ddr_write_burst_begin <= 0;	// 撤销写入burst请求
					ddr_wr_state <= 0;
				end
			endcase
		end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 数据包构造，还是使用状态机来实现
reg		[4:0]	pkt_state;
reg		[31:0]	pkt_cnt;
always @(posedge sys_clk)
	if(!sys_rst_n)
	begin
		pkt_state <= 0;
		sys_uart_write_data_valid <= 0;
	end
	else
	begin
		case(pkt_state)
			0: begin
				sys_uart_write_data_valid <= 0;
				if(test_uart_cmd)
				begin
					pkt_cnt <= 0;
					pkt_state <= 1;
				end
				else if(read_ddr_cmd)
				begin
					pkt_cnt <= 0;
					pkt_state <= 2;
				end
				else if(write_ddr_cmd)
				begin
					pkt_cnt <= 0;
					pkt_state <= 3;
				end
				else if(cont_read_cmd)
				begin
					pkt_cnt <= 0;
					pkt_state <= 4;
				end
				else if(cont_write_cmd)
				begin
					pkt_cnt <= 0;
					pkt_state <= 5;
				end
				else if(adc_read_cmd)
				begin
					pkt_cnt <= 0;
					pkt_state <= 6;
				end
				else if(audio_sample_cmd)
				begin
					pkt_cnt <= 0;
					pkt_state <= 7;
				end
				else if(measure_ram_cmd)
				begin
					pkt_cnt <= 0;
					pkt_state <= 8;
				end
				else if(npu_inst_cmd)
				begin
					pkt_cnt <= 0;
					pkt_state <= 11;
				end
			end
			
			// uart 测试
			1: begin
				if(pkt_cnt >= (uart_cmd_shift_reg[39:8]+3))
				begin
					pkt_state <= 0;
					sys_uart_write_data_valid <= 0;
				end
				else
				begin
					if(sys_uart_write_data_permitted_reg)
					begin
						if(pkt_cnt==0) 		sys_uart_write_data <= 32'H68656C6C;	// hell
						else if(pkt_cnt==1)	sys_uart_write_data <= 32'H6F776F72;	// owor
						else if(pkt_cnt==2)	sys_uart_write_data <= 32'H6C646868;	// ldhh
						else				sys_uart_write_data <= pkt_cnt-3;	// 测试数据（00, 01, 02, ...
						pkt_cnt <= pkt_cnt + 1;
					end
					sys_uart_write_data_valid <= sys_uart_write_data_permitted_reg;
				end
			end
			
			// ddr单次读取
			2 : begin
				if(pkt_cnt >= 2)
				begin
					pkt_state <= 0;
					sys_uart_write_data_valid <= 0;
				end
				else 
				begin
					if(pkt_cnt==0)
					begin
						if(sys_uart_write_data_permitted_reg)
						begin
							sys_uart_write_data <= 32'H72646472;	// rddr
							pkt_cnt <= pkt_cnt + 1;
							sys_uart_write_data_valid <= 1;
						end
						else
							sys_uart_write_data_valid <= 0;
					end
					else if(sys_ddr_read_data_valid_reg)
					begin
						sys_uart_write_data <= sys_key_fn[2]? sys_ddr_read_data_reg : {sys_ddr_read_data_reg[15:0], sys_ddr_read_data_reg[31:16]};	
						pkt_cnt <= pkt_cnt + 1;
						sys_uart_write_data_valid <= 1;
					end
					else
						sys_uart_write_data_valid <= 0;
				end
			end
			
			// ddr单次写入
			3: begin
				if(pkt_cnt >= 1)
				begin
					pkt_state <= 0;
					sys_uart_write_data_valid <= 0;
				end
				else if(sys_uart_write_data_permitted_reg)
				begin
					sys_uart_write_data <= 32'H77646472;	// wddr
					pkt_cnt <= pkt_cnt + 1;
					sys_uart_write_data_valid <= 1;
				end
				else
					sys_uart_write_data_valid <= 0;
			end
			
			// ddr连续读取
			4: begin
				if(pkt_cnt >= uart_cmd_shift_reg[39:8]+1)
				begin
					pkt_state <= 0;
					sys_uart_write_data_valid <= 0;
				end
				else 
				begin
					// 
					if(pkt_cnt==0)
					begin
						if(sys_uart_write_data_permitted_reg)
						begin
							sys_uart_write_data <= 32'H72636F6E;	// rcon
							pkt_cnt <= pkt_cnt + 1;
							sys_uart_write_data_valid <= 1;
						end
						else
							sys_uart_write_data_valid <= 0;
					end
					else if(sys_ddr_read_data_valid_reg)
					begin
						sys_uart_write_data <= sys_key_fn[2]? sys_ddr_read_data_reg : {sys_ddr_read_data_reg[15:0], sys_ddr_read_data_reg[31:16]};	
						pkt_cnt <= pkt_cnt + 1;
						sys_uart_write_data_valid <= 1;
					end
					else
						sys_uart_write_data_valid <= 0;
				end
			end
			
			// ddr 连续写入
			5: begin
				if(pkt_cnt >= 1)
				begin
					pkt_state <= 0;
					sys_uart_write_data_valid <= 0;
				end
				else if(sys_uart_write_data_permitted_reg)
				begin
					sys_uart_write_data <= 32'H77636F6E;	// wcon
					pkt_cnt <= pkt_cnt + 1;
					sys_uart_write_data_valid <= 1;
				end
				else
					sys_uart_write_data_valid <= 0;
			end
			
			// ddr连续读取
			6: begin
				if(pkt_cnt >= uart_cmd_shift_reg[39:8]+1)
				begin
					pkt_state <= 0;
					sys_uart_write_data_valid <= 0;
				end
				else 
				begin
					// 
					if(pkt_cnt==0)
					begin
						if(sys_uart_write_data_permitted_reg)
						begin
							sys_uart_write_data <= 32'H72616463;	// radc
							pkt_cnt <= pkt_cnt + 1;
							sys_uart_write_data_valid <= 1;
						end
						else
							sys_uart_write_data_valid <= 0;
					end
					else if(sys_ddr_read_data_valid_reg)
					begin
						sys_uart_write_data <= sys_key_fn[2]? sys_ddr_read_data_reg : {sys_ddr_read_data_reg[15:0], sys_ddr_read_data_reg[31:16]};	
						pkt_cnt <= pkt_cnt + 1;
						sys_uart_write_data_valid <= 1;
					end
					else
						sys_uart_write_data_valid <= 0;
				end
			end
			// 音频采集使能
			7: begin
				if(pkt_cnt >= 1)
				begin
					pkt_state <= 0;
					sys_uart_write_data_valid <= 0;
				end
				else if(sys_uart_write_data_permitted_reg)
				begin
					sys_uart_write_data <= 32'H61756469;	// audi
					pkt_cnt <= pkt_cnt + 1;
					sys_uart_write_data_valid <= 1;
				end
				else
					sys_uart_write_data_valid <= 0;
			end
			// 然后是DDR读写速度的测试
			8: begin
				// 首先等待DDR读写状态机进入读写状态
				if(ddr_wr_state>=15 && ddr_wr_number<=17)
				begin
					pkt_state <= 9;
					pkt_cnt <= 0;
				end
			end
			9: begin
				// 等待DDR读写测试完成
				if(ddr_wr_state==0)
				begin
					pkt_state <= 10;
					pkt_cnt <= 0;
				end
			end
			10: begin
				// 然后就是发送DDR速度
				if(pkt_cnt >= 2)
				begin
					pkt_state <= 0;
					sys_uart_write_data_valid <= 0;
				end
				// 生成数据报文
				else 
				begin
					if(pkt_cnt==0)
					begin
						if(sys_uart_write_data_permitted_reg)
						begin
							sys_uart_write_data <= 32'H6D646472;	// mddr
							pkt_cnt <= pkt_cnt + 1;
							sys_uart_write_data_valid <= 1;
						end
					end
					else if(pkt_cnt == 1)
					begin
						if(sys_uart_write_data_permitted_reg)
						begin
							sys_uart_write_data <= ddr_wr_time;	// 读写时间（cmd系统时钟频率计数）
							pkt_cnt <= pkt_cnt + 1;
							sys_uart_write_data_valid <= 1;
						end
					end
				end
			end
			// NPU指令传输完毕
			11: begin
				if(pkt_cnt >= 1)
				begin
					pkt_state <= 0;
					sys_uart_write_data_valid <= 0;
				end
				else if(sys_uart_write_data_permitted_reg)
				begin
					sys_uart_write_data <= 32'H696e7374;	// inst
					pkt_cnt <= pkt_cnt + 1;
					sys_uart_write_data_valid <= 1;
				end
				else
					sys_uart_write_data_valid <= 0;
			end
			//
			default: begin
				pkt_state <= 0;
				sys_uart_write_data_valid <= 0;
			end
			///////////
		endcase
	end

////////////////////////////////////////////////////////////////////////////////////////////////////////////////
endmodule

	
	