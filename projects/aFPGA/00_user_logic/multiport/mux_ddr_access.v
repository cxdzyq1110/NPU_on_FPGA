// 多路选通ddr读写访问器
module mux_ddr_access
(
	// 
	// [0] 写入的port
	input	wire			wport_clock_0,
	input	wire	[31:0]	wport_addr_0,
	input	wire	[31:0]	wport_data_0,
	input	wire			wport_req_0,
	output	wire			wport_ready_0,
	// [1]读取的port
	input	wire			rport_clock_1,
	input	wire	[31:0]	rport_addr_1,
	output	wire	[31:0]	rport_data_1,
	output	wire			rport_data_valid_1,
	input	wire			rport_req_1,
	output	wire			rport_ready_1,
	// 
	//[2]写入的port
	input	wire			wport_clock_2,
	input	wire	[31:0]	wport_addr_2,
	input	wire	[31:0]	wport_data_2,
	input	wire			wport_req_2,
	output	wire			wport_ready_2,
	/*
	*/
	// [3]读取的port
	input	wire			rport_clock_3,
	input	wire	[31:0]	rport_addr_3,
	output	wire	[31:0]	rport_data_3,
	output	wire			rport_data_valid_3,
	input	wire			rport_req_3,
	output	wire			rport_ready_3,
	// 
	//[4]写入的port
	input	wire			wport_clock_4,
	input	wire	[31:0]	wport_addr_4,
	input	wire	[31:0]	wport_data_4,
	input	wire			wport_req_4,
	output	wire			wport_ready_4,
	// [5]读取的port
	input	wire			rport_clock_5,
	input	wire	[31:0]	rport_addr_5,
	output	wire	[31:0]	rport_data_5,
	output	wire			rport_data_valid_5,
	input	wire			rport_req_5,
	output	wire			rport_ready_5,
	//[6]写入的port
	input	wire			wport_clock_6,
	input	wire	[31:0]	wport_addr_6,
	input	wire	[31:0]	wport_data_6,
	input	wire			wport_req_6,
	output	wire			wport_ready_6,
	// [7]读取的port
	input	wire			rport_clock_7,
	input	wire	[31:0]	rport_addr_7,
	output	wire	[31:0]	rport_data_7,
	output	wire			rport_data_valid_7,
	input	wire			rport_req_7,
	output	wire			rport_ready_7,
	//
	// DDR接口
	input	wire			afi_phy_clk,
	input	wire			afi_phy_rst_n,
	input	wire			local_init_done,
	output	wire	[31:0]	local_address,
	output	wire			local_write_req,
	output	wire			local_read_req,
	output	wire			local_burstbegin,
	output	wire	[31:0]	local_wdata,
	output	wire	[3:0]	local_be,
	output	wire	[7:0]	local_size,
	input	wire			local_ready,
	input	wire	[31:0]	local_rdata,
	input	wire			local_rdata_valid
);

	////////////////////////////////////////////////////////////////////////////////////////////////////
	// 需要有一个FIFO，用于rdata_valid/rdata的分流
	reg				[3:0]	rport_num_fifo_data;
	reg						rport_num_fifo_wrreq;
	wire			[3:0]	rport_num_fifo_q;
	wire					rport_num_fifo_rdreq;
	wire			[5:0]	rport_num_fifo_usedw;
	
	assign			rport_num_fifo_rdreq = local_rdata_valid;
	
//	alt_fifo_4b_64w		
	sc_fifo				#(
							.LOG2N(6),
							.DATA_WIDTH(4)
						)
						alt_fifo_4b_64w_inst(
							.aclr(!afi_phy_rst_n),
							//.sclr(!afi_phy_rst_n),
							.clock(afi_phy_clk),
							.data(rport_num_fifo_data),
							.wrreq(rport_num_fifo_wrreq),
							.usedw(rport_num_fifo_usedw),
							.q(rport_num_fifo_q),
							.rdreq(rport_num_fifo_rdreq)
						);
	
	/////////////////////////////////////// [0] ////////////////////////////////////////////////////
	// 首先把【0】端口的读写请求通过DCFIFO锁起来
	// 注意要用show-ahead的模式
	wire			[3:0]	wport_addr_0_fifo_wrusedw;
	wire					wport_addr_0_fifo_wrfull;
	wire			[3:0]	wport_addr_0_fifo_rdusedw;
	wire			[63:0]	wport_addr_0_fifo_q;
	reg						wport_addr_0_fifo_rdreq;
	wire					wport_addr_0_fifo_rdempty;
	
	assign			wport_ready_0 = (wport_addr_0_fifo_wrusedw[3:2]==0);
	
//	alt_fifo_64b_16w		wport_addr_data_0_fifo(
	dc_fifo				#(
							.LOG2N(4),
							.DATA_WIDTH(64)
						)
						wport_addr_data_0_fifo
						(
							.aclr(!afi_phy_rst_n),
							.data({wport_addr_0, wport_data_0}),
							.wrclock(wport_clock_0),
							.wrreq(wport_req_0 & wport_ready_0),
							.wrusedw(wport_addr_0_fifo_wrusedw),
							.wrfull(wport_addr_0_fifo_wrfull),
							.q(wport_addr_0_fifo_q),
							.rdusedw(wport_addr_0_fifo_rdusedw),
							.rdclock(afi_phy_clk),
							.rdreq(wport_addr_0_fifo_rdreq),
							.rdempty(wport_addr_0_fifo_rdempty)
						);
						
	/////////////////////////////////////// [1] ////////////////////////////////////////////////////
	// 把地址锁起来
	wire			[3:0]	rport_addr_1_fifo_wrusedw;
	wire					rport_addr_1_fifo_wrfull;
	wire			[3:0]	rport_addr_1_fifo_rdusedw;
	wire			[31:0]	rport_addr_1_fifo_q;
	reg						rport_addr_1_fifo_rdreq;
	wire					rport_addr_1_fifo_rdempty;
	
//	alt_fifo_32b_16w		rport_addr_1_fifo(
	dc_fifo				#(
							.LOG2N(4),
							.DATA_WIDTH(32)
						)
						rport_addr_1_fifo
						(
							.aclr(!afi_phy_rst_n),
							.data(rport_addr_1),
							.wrclock(rport_clock_1),
							.wrreq(rport_req_1 & rport_ready_1),
							.wrusedw(rport_addr_1_fifo_wrusedw),
							.wrfull(rport_addr_1_fifo_wrfull),
							.q(rport_addr_1_fifo_q),
							.rdusedw(rport_addr_1_fifo_rdusedw),
							.rdclock(afi_phy_clk),
							.rdreq(rport_addr_1_fifo_rdreq),
							.rdempty(rport_addr_1_fifo_rdempty)
						);
	// 把读取到的数据传递出去（100MHz采集125 mHz，中间要经过FIFO来同步）
	wire			[31:0]	rport_data_1_fifo_data = local_rdata;
	wire					rport_data_1_fifo_wrreq = (rport_num_fifo_q==1) && local_rdata_valid;
	wire			[31:0]	rport_data_1_fifo_q;
	wire					rport_data_1_fifo_rdempty;
	wire			[5:0]	rport_data_1_fifo_rdusedw;
	// 使用状态机从FIFO里面读取出数据
	assign			rport_data_1 = rport_data_1_fifo_q;
	assign			rport_data_valid_1 = !rport_data_1_fifo_rdempty;
	// FIFO例化
//	alt_fifo_32b_64w	rport_data_1_fifo(
	dc_fifo				#(
							.LOG2N(6),
							.DATA_WIDTH(32)
						)
						rport_data_1_fifo
						(
							.aclr(!afi_phy_rst_n),
							.data(rport_data_1_fifo_data),
							.wrclock(afi_phy_clk),
							.wrreq(rport_data_1_fifo_wrreq),
							.rdusedw(rport_data_1_fifo_rdusedw),
							.q(rport_data_1_fifo_q),
							.rdclock(rport_clock_1),
							.rdreq(!rport_data_1_fifo_rdempty),
							.rdempty(rport_data_1_fifo_rdempty)
						);
	
	assign			rport_ready_1 = (rport_addr_1_fifo_wrusedw[3:2]==0 && rport_data_1_fifo_rdusedw[5]==0);
	/////////////////////////////////////// [2] ////////////////////////////////////////////////////
	// 首先把【0】端口的读写请求通过DCFIFO锁起来
	// 注意要用show-ahead的模式
	wire			[3:0]	wport_addr_2_fifo_wrusedw;
	wire					wport_addr_2_fifo_wrfull;
	wire			[3:0]	wport_addr_2_fifo_rdusedw;
	wire			[63:0]	wport_addr_2_fifo_q;
	reg						wport_addr_2_fifo_rdreq;
	wire					wport_addr_2_fifo_rdempty;
	
	assign			wport_ready_2 = (wport_addr_2_fifo_wrusedw[3:2]==0);
	
//	alt_fifo_64b_16w		wport_addr_data_2_fifo(
	dc_fifo				#(
							.LOG2N(4),
							.DATA_WIDTH(64)
						)
						wport_addr_data_2_fifo
						(
							.aclr(!afi_phy_rst_n),
							.data({wport_addr_2, wport_data_2}),
							.wrclock(wport_clock_2),
							.wrreq(wport_req_2 & wport_ready_2),
							.wrusedw(wport_addr_2_fifo_wrusedw),
							.wrfull(wport_addr_2_fifo_wrfull),
							.q(wport_addr_2_fifo_q),
							.rdusedw(wport_addr_2_fifo_rdusedw),
							.rdclock(afi_phy_clk),
							.rdreq(wport_addr_2_fifo_rdreq),
							.rdempty(wport_addr_2_fifo_rdempty)
						);
	
	/*
	*/
	/////////////////////////////////////// [3] ////////////////////////////////////////////////////
	// 把地址锁起来
	wire			[3:0]	rport_addr_3_fifo_wrusedw;
	wire					rport_addr_3_fifo_wrfull;
	wire			[3:0]	rport_addr_3_fifo_rdusedw;
	wire			[31:0]	rport_addr_3_fifo_q;
	reg						rport_addr_3_fifo_rdreq;
	wire					rport_addr_3_fifo_rdempty;
	
	
//	alt_fifo_32b_16w			
	dc_fifo				#(
							.LOG2N(4),
							.DATA_WIDTH(32)
						)
						rport_addr_3_fifo(
							.aclr(!afi_phy_rst_n),
							.data(rport_addr_3),
							.wrclock(rport_clock_3),
							.wrreq(rport_req_3 & rport_ready_3),
							.wrusedw(rport_addr_3_fifo_wrusedw),
							.wrfull(rport_addr_3_fifo_wrfull),
							.q(rport_addr_3_fifo_q),
							.rdusedw(rport_addr_3_fifo_rdusedw),
							.rdclock(afi_phy_clk),
							.rdreq(rport_addr_3_fifo_rdreq),
							.rdempty(rport_addr_3_fifo_rdempty)
						);
	// 把读取到的数据传递出去（100MHz采集125 mHz，中间要经过FIFO来同步）
	wire			[31:0]	rport_data_3_fifo_data = local_rdata;
	wire					rport_data_3_fifo_wrreq = (rport_num_fifo_q==3) && local_rdata_valid;
	wire			[31:0]	rport_data_3_fifo_q;
	wire					rport_data_3_fifo_rdempty;
	wire			[5:0]	rport_data_3_fifo_rdusedw;
	// 使用状态机从FIFO里面读取出数据
	assign			rport_data_3 = rport_data_3_fifo_q;
	assign			rport_data_valid_3 = !rport_data_3_fifo_rdempty;
	// FIFO例化
//	alt_fifo_32b_64w		
	dc_fifo				#(
							.LOG2N(6),
							.DATA_WIDTH(32)
						)
						rport_data_3_fifo(
							.aclr(!afi_phy_rst_n),
							.data(rport_data_3_fifo_data),
							.wrclock(afi_phy_clk),
							.wrreq(rport_data_3_fifo_wrreq),
							.rdusedw(rport_data_3_fifo_rdusedw),
							.q(rport_data_3_fifo_q),
							.rdclock(rport_clock_3),
							.rdreq(!rport_data_3_fifo_rdempty),
							.rdempty(rport_data_3_fifo_rdempty)
						);	
						
	assign			rport_ready_3 = (rport_addr_3_fifo_wrusedw[3:2]==0 && rport_data_3_fifo_rdusedw[5]==0);
	/////////////////////////////////////// [4] ////////////////////////////////////////////////////
	// 首先把【4】端口的读写请求通过DCFIFO锁起来
	// 注意要用show-ahead的模式
	wire			[3:0]	wport_addr_4_fifo_wrusedw;
	wire					wport_addr_4_fifo_wrfull;
	wire			[3:0]	wport_addr_4_fifo_rdusedw;
	wire			[63:0]	wport_addr_4_fifo_q;
	reg						wport_addr_4_fifo_rdreq;
	wire					wport_addr_4_fifo_rdempty;
	
	assign			wport_ready_4 = (wport_addr_4_fifo_wrusedw[3:2]==0);
	
//	alt_fifo_64b_16w			
	dc_fifo				#(
							.LOG2N(4),
							.DATA_WIDTH(64)
						)
						wport_addr_data_4_fifo(
							.aclr(!afi_phy_rst_n),
							.data({wport_addr_4, wport_data_4}),
							.wrclock(wport_clock_4),
							.wrreq(wport_req_4 & wport_ready_4),
							.wrusedw(wport_addr_4_fifo_wrusedw),
							.wrfull(wport_addr_4_fifo_wrfull),
							.q(wport_addr_4_fifo_q),
							.rdusedw(wport_addr_4_fifo_rdusedw),
							.rdclock(afi_phy_clk),
							.rdreq(wport_addr_4_fifo_rdreq),
							.rdempty(wport_addr_4_fifo_rdempty)
						);
	
	/////////////////////////////////////// [5] ////////////////////////////////////////////////////
	// 把地址锁起来
	wire			[3:0]	rport_addr_5_fifo_wrusedw;
	wire					rport_addr_5_fifo_wrfull;
	wire			[3:0]	rport_addr_5_fifo_rdusedw;
	wire			[31:0]	rport_addr_5_fifo_q;
	reg						rport_addr_5_fifo_rdreq;
	wire					rport_addr_5_fifo_rdempty;
	
	
//	alt_fifo_32b_16w			
	dc_fifo				#(
							.LOG2N(4),
							.DATA_WIDTH(32)
						)
						rport_addr_5_fifo(
							.aclr(!afi_phy_rst_n),
							.data(rport_addr_5),
							.wrclock(rport_clock_5),
							.wrreq(rport_req_5 & rport_ready_5),
							.wrusedw(rport_addr_5_fifo_wrusedw),
							.wrfull(rport_addr_5_fifo_wrfull),
							.q(rport_addr_5_fifo_q),
							.rdusedw(rport_addr_5_fifo_rdusedw),
							.rdclock(afi_phy_clk),
							.rdreq(rport_addr_5_fifo_rdreq),
							.rdempty(rport_addr_5_fifo_rdempty)
						);
	// 把读取到的数据传递出去（100MHz采集125 mHz，中间要经过FIFO来同步）
	wire			[31:0]	rport_data_5_fifo_data = local_rdata;
	wire					rport_data_5_fifo_wrreq = (rport_num_fifo_q==5) && local_rdata_valid;
	wire			[31:0]	rport_data_5_fifo_q;
	wire					rport_data_5_fifo_rdempty;
	wire			[5:0]	rport_data_5_fifo_rdusedw;
	// 使用状态机从FIFO里面读取出数据
	assign			rport_data_5 = rport_data_5_fifo_q;
	assign			rport_data_valid_5 = !rport_data_5_fifo_rdempty;
	// FIFO例化
//	alt_fifo_32b_64w		
	dc_fifo				#(
							.LOG2N(6),
							.DATA_WIDTH(32)
						)
						rport_data_5_fifo(
							.aclr(!afi_phy_rst_n),
							.data(rport_data_5_fifo_data),
							.wrclock(afi_phy_clk),
							.wrreq(rport_data_5_fifo_wrreq),
							.rdusedw(rport_data_5_fifo_rdusedw),
							.q(rport_data_5_fifo_q),
							.rdclock(rport_clock_5),
							.rdreq(!rport_data_5_fifo_rdempty),
							.rdempty(rport_data_5_fifo_rdempty)
						);	
						
	assign			rport_ready_5 = (rport_addr_5_fifo_wrusedw[3:2]==0 && rport_data_5_fifo_rdusedw[5]==0);
	/////////////////////////////////////// [6] ////////////////////////////////////////////////////
	// 首先把【6】端口的读写请求通过DCFIFO锁起来
	// 注意要用show-ahead的模式
	wire			[3:0]	wport_addr_6_fifo_wrusedw;
	wire					wport_addr_6_fifo_wrfull;
	wire			[3:0]	wport_addr_6_fifo_rdusedw;
	wire			[63:0]	wport_addr_6_fifo_q;
	reg						wport_addr_6_fifo_rdreq;
	wire					wport_addr_6_fifo_rdempty;
	
	assign			wport_ready_6 = (wport_addr_6_fifo_wrusedw[3:2]==0);
	
//	alt_fifo_64b_16w			
	dc_fifo				#(
							.LOG2N(4),
							.DATA_WIDTH(64)
						)
						wport_addr_data_6_fifo(
							.aclr(!afi_phy_rst_n),
							.data({wport_addr_6, wport_data_6}),
							.wrclock(wport_clock_6),
							.wrreq(wport_req_6 & wport_ready_6),
							.wrusedw(wport_addr_6_fifo_wrusedw),
							.wrfull(wport_addr_6_fifo_wrfull),
							.q(wport_addr_6_fifo_q),
							.rdusedw(wport_addr_6_fifo_rdusedw),
							.rdclock(afi_phy_clk),
							.rdreq(wport_addr_6_fifo_rdreq),
							.rdempty(wport_addr_6_fifo_rdempty)
						);
	
	/////////////////////////////////////// [7] ////////////////////////////////////////////////////
	// 把地址锁起来
	wire			[3:0]	rport_addr_7_fifo_wrusedw;
	wire					rport_addr_7_fifo_wrfull;
	wire			[3:0]	rport_addr_7_fifo_rdusedw;
	wire			[31:0]	rport_addr_7_fifo_q;
	reg						rport_addr_7_fifo_rdreq;
	wire					rport_addr_7_fifo_rdempty;
	
	
//	alt_fifo_32b_16w			
	dc_fifo				#(
							.LOG2N(4),
							.DATA_WIDTH(32)
						)
						rport_addr_7_fifo(
							.aclr(!afi_phy_rst_n),
							.data(rport_addr_7),
							.wrclock(rport_clock_7),
							.wrreq(rport_req_7 & rport_ready_7),
							.wrusedw(rport_addr_7_fifo_wrusedw),
							.wrfull(rport_addr_7_fifo_wrfull),
							.q(rport_addr_7_fifo_q),
							.rdusedw(rport_addr_7_fifo_rdusedw),
							.rdclock(afi_phy_clk),
							.rdreq(rport_addr_7_fifo_rdreq),
							.rdempty(rport_addr_7_fifo_rdempty)
						);
	// 把读取到的数据传递出去（100MHz采集125 mHz，中间要经过FIFO来同步）
	wire			[31:0]	rport_data_7_fifo_data = local_rdata;
	wire					rport_data_7_fifo_wrreq = (rport_num_fifo_q==7) && local_rdata_valid;
	wire			[31:0]	rport_data_7_fifo_q;
	wire					rport_data_7_fifo_rdempty;
	wire			[5:0]	rport_data_7_fifo_rdusedw;
	// 使用状态机从FIFO里面读取出数据
	assign			rport_data_7 = rport_data_7_fifo_q;
	assign			rport_data_valid_7 = !rport_data_7_fifo_rdempty;
	// FIFO例化
//	alt_fifo_32b_64w		
	dc_fifo				#(
							.LOG2N(6),
							.DATA_WIDTH(32)
						)
						rport_data_7_fifo(
							.aclr(!afi_phy_rst_n),
							.data(rport_data_7_fifo_data),
							.wrclock(afi_phy_clk),
							.wrreq(rport_data_7_fifo_wrreq),
							.rdusedw(rport_data_7_fifo_rdusedw),
							.q(rport_data_7_fifo_q),
							.rdclock(rport_clock_7),
							.rdreq(!rport_data_7_fifo_rdempty),
							.rdempty(rport_data_7_fifo_rdempty)
						);	
						
	assign			rport_ready_7 = (rport_addr_7_fifo_wrusedw[3:2]==0 && rport_data_7_fifo_rdusedw[5]==0);
	/////////////////////////////////////// [ddr mux] ////////////////////////////////////////////////////
	// 在这里进行ddr读写测试
	// 首先需要看看到底full_rate的时钟下，读写avalon总线怎么调度
	reg		[31:0]	avl_addr;
	reg		[31:0]	avl_wdata;
	reg				avl_write_req;
	reg				avl_read_req;
	reg		[7:0]	avl_size;
	reg				avl_burstbegin;
	// 使用状态机跳转进行测试
	reg		[7:0]	cstate;
	always @(posedge afi_phy_clk)
		if(!local_init_done || !afi_phy_rst_n)
		begin
			init_avl_signals_task;
			init_port_ctrl_task;
			cstate <= 0;
		end
		else 
		begin
			case(cstate)
				0: begin
					polling_all_multi_ports_task(8'B11111111);	// 轮询所有的port，找到要执行的读写命令
				end
				
				// 执行端口0的写入
				1: begin
					if(!local_ready)
						init_port_ctrl_task;
					else if(local_ready)
						polling_all_multi_ports_task(8'B11111110);// 屏蔽端口0
				end
				
				// 执行端口1的读取
				2: begin
					if(!local_ready)
						init_port_ctrl_task;
					else if(local_ready)
						polling_all_multi_ports_task(8'B11111101);// 屏蔽端口1
				end
				/*
				*/
				// 执行端口2的写入
				3: begin
					if(!local_ready)
						init_port_ctrl_task;
					else if(local_ready)
						polling_all_multi_ports_task(8'B11111011);// 屏蔽端口2
				end
				
				// 执行端口3的读取
				4: begin
					if(!local_ready)
						init_port_ctrl_task;
					else if(local_ready)
						polling_all_multi_ports_task(8'B11110111);// 屏蔽端口3
				end
				
				// 执行端口4的写入
				5: begin
					if(!local_ready)
						init_port_ctrl_task;
					else if(local_ready)
						polling_all_multi_ports_task(8'B11101111);// 屏蔽端口4
				end
				
				// 执行端口5的读取
				6: begin
					if(!local_ready)
						init_port_ctrl_task;
					else if(local_ready)
						polling_all_multi_ports_task(8'B11011111);// 屏蔽端口5
				end
				// 执行端口6的写入
				7: begin
					if(!local_ready)
						init_port_ctrl_task;
					else if(local_ready)
						polling_all_multi_ports_task(8'B10111111);// 屏蔽端口6
				end
				
				// 执行端口7的读取
				8: begin
					if(!local_ready)
						init_port_ctrl_task;
					else if(local_ready)
						polling_all_multi_ports_task(8'B01111111);// 屏蔽端口7
				end
				//
				default: begin
					init_avl_signals_task;
					init_port_ctrl_task;
					cstate <= 0;
				end
				
			endcase
		end
//////////////////////////////////////
// 轮询所有的port，找到要执行的读写命令
// 最正确的做法是：如果polling的时候，发现port_fifo_rdusedw==1而且已经在port_fifo_rdreq了，就不能继续读
task polling_all_multi_ports_task(input [7:0] port_mask);
begin
	// 考察端口0
	if(!wport_addr_0_fifo_rdempty & local_ready & port_mask[0])
	begin
		single_write_task(wport_addr_0_fifo_q[63:32], wport_addr_0_fifo_q[31:0]);
		wport_addr_0_fifo_rdreq <= 1;
		rport_addr_1_fifo_rdreq <= 0;
		wport_addr_2_fifo_rdreq <= 0;
		/*
		*/
		rport_addr_3_fifo_rdreq <= 0;
		wport_addr_4_fifo_rdreq <= 0;
		rport_addr_5_fifo_rdreq <= 0;
		wport_addr_6_fifo_rdreq <= 0;
		rport_addr_7_fifo_rdreq <= 0;
		rport_num_fifo_wrreq <= 0;
		//
		cstate <= 1;
	end
	// 考察端口1
	else if(!rport_addr_1_fifo_rdempty & local_ready & port_mask[1])
	begin
		single_read_task(rport_addr_1_fifo_q);
		wport_addr_0_fifo_rdreq <= 0;
		rport_addr_1_fifo_rdreq <= 1;
		wport_addr_2_fifo_rdreq <= 0;
		/*
		*/
		rport_addr_3_fifo_rdreq <= 0;
		wport_addr_4_fifo_rdreq <= 0;
		rport_addr_5_fifo_rdreq <= 0;
		wport_addr_6_fifo_rdreq <= 0;
		rport_addr_7_fifo_rdreq <= 0;
		rport_num_fifo_write_task(1);
		cstate <= 2;
	end
	// 考察端口2
	else if(!wport_addr_2_fifo_rdempty & local_ready & port_mask[2])
	begin
		single_write_task(wport_addr_2_fifo_q[63:32], wport_addr_2_fifo_q[31:0]);
		wport_addr_0_fifo_rdreq <= 0;
		rport_addr_1_fifo_rdreq <= 0;
		wport_addr_2_fifo_rdreq <= 1;
		/*
		*/
		rport_addr_3_fifo_rdreq <= 0;
		wport_addr_4_fifo_rdreq <= 0;
		rport_addr_5_fifo_rdreq <= 0;
		wport_addr_6_fifo_rdreq <= 0;
		rport_addr_7_fifo_rdreq <= 0;
		rport_num_fifo_wrreq <= 0;
		cstate <= 3;
	end
	// 考察端口3
	else if(!rport_addr_3_fifo_rdempty & local_ready & port_mask[3])
	begin
		single_read_task(rport_addr_3_fifo_q);
		wport_addr_0_fifo_rdreq <= 0;
		rport_addr_1_fifo_rdreq <= 0;
		wport_addr_2_fifo_rdreq <= 0;
		rport_addr_3_fifo_rdreq <= 1;
		wport_addr_4_fifo_rdreq <= 0;
		rport_addr_5_fifo_rdreq <= 0;
		wport_addr_6_fifo_rdreq <= 0;
		rport_addr_7_fifo_rdreq <= 0;
		rport_num_fifo_write_task(3);
		cstate <= 4;
	end
	// 考察端口4
	else if(!wport_addr_4_fifo_rdempty & local_ready & port_mask[4])
	begin
		single_write_task(wport_addr_4_fifo_q[63:32], wport_addr_4_fifo_q[31:0]);
		wport_addr_0_fifo_rdreq <= 0;
		rport_addr_1_fifo_rdreq <= 0;
		wport_addr_2_fifo_rdreq <= 0;
		rport_addr_3_fifo_rdreq <= 0;
		wport_addr_4_fifo_rdreq <= 1;
		rport_addr_5_fifo_rdreq <= 0;
		wport_addr_6_fifo_rdreq <= 0;
		rport_addr_7_fifo_rdreq <= 0;
		rport_num_fifo_wrreq <= 0;
		cstate <= 5;
	end
	// 考察端口5
	else if(!rport_addr_5_fifo_rdempty & local_ready & port_mask[5])
	begin
		single_read_task(rport_addr_5_fifo_q);
		wport_addr_0_fifo_rdreq <= 0;
		rport_addr_1_fifo_rdreq <= 0;
		wport_addr_2_fifo_rdreq <= 0;
		rport_addr_3_fifo_rdreq <= 0;
		wport_addr_4_fifo_rdreq <= 0;
		rport_addr_5_fifo_rdreq <= 1;
		wport_addr_6_fifo_rdreq <= 0;
		rport_addr_7_fifo_rdreq <= 0;
		rport_num_fifo_write_task(5);
		cstate <= 6;
	end
	
	// 考察端口6
	else if(!wport_addr_6_fifo_rdempty & local_ready & port_mask[6])
	begin
		single_write_task(wport_addr_6_fifo_q[63:32], wport_addr_6_fifo_q[31:0]);
		wport_addr_0_fifo_rdreq <= 0;
		rport_addr_1_fifo_rdreq <= 0;
		wport_addr_2_fifo_rdreq <= 0;
		rport_addr_3_fifo_rdreq <= 0;
		wport_addr_4_fifo_rdreq <= 0;
		rport_addr_5_fifo_rdreq <= 0;
		wport_addr_6_fifo_rdreq <= 1;
		rport_addr_7_fifo_rdreq <= 0;
		rport_num_fifo_wrreq <= 0;
		cstate <= 7;
	end
	// 考察端口7
	else if(!rport_addr_7_fifo_rdempty & local_ready & port_mask[7])
	begin
		single_read_task(rport_addr_7_fifo_q);
		wport_addr_0_fifo_rdreq <= 0;
		rport_addr_1_fifo_rdreq <= 0;
		wport_addr_2_fifo_rdreq <= 0;
		rport_addr_3_fifo_rdreq <= 0;
		wport_addr_4_fifo_rdreq <= 0;
		rport_addr_5_fifo_rdreq <= 0;
		wport_addr_6_fifo_rdreq <= 0;
		rport_addr_7_fifo_rdreq <= 1;
		rport_num_fifo_write_task(7);
		cstate <= 8;
	end
	
	/**/
	// 否则维持
	else
	begin
		cstate <= 0;
		init_avl_signals_task;
		init_port_ctrl_task;
	end
end
endtask

// 初始化port的控制信号
task init_port_ctrl_task;
begin
	wport_addr_0_fifo_rdreq <= 0;
	rport_addr_1_fifo_rdreq <= 0;
	wport_addr_2_fifo_rdreq <= 0;
	/*
	*/
	rport_addr_3_fifo_rdreq <= 0;
	wport_addr_4_fifo_rdreq <= 0;
	rport_addr_5_fifo_rdreq <= 0;
	// mark: 2018/6/3: 居然漏掉了！怪不得高速读写的时候会出错！
	wport_addr_6_fifo_rdreq <= 0;
	rport_addr_7_fifo_rdreq <= 0;
	// 读取端口标记，写入使能，清零
	rport_num_fifo_wrreq <= 0;
end
endtask
		
// 初始化avalon接口的task
task init_avl_signals_task;
begin
	avl_addr <= 0;
	avl_wdata <= 0;
	avl_write_req <= 0;
	avl_read_req <= 0;
	avl_burstbegin <= 0;
	avl_size <= 0;
end
endtask

// rport序号标记的fifo写入操作
task rport_num_fifo_write_task(input [3:0] rport_num);
begin
	rport_num_fifo_data <= rport_num;
	rport_num_fifo_wrreq <= 1;
end
endtask

// 单次DDR写入的task
task single_write_task(input [31:0]	addr, input [31:0] data);
begin
	$display("write: [%08H] into [%08H]", data, addr);
	avl_addr <= addr;
	avl_wdata <= data;
	avl_write_req <= 1;
	avl_read_req <= 0;
	avl_burstbegin <= 0;
	avl_size <= 1;
end
endtask	

// 单次DDR读取的task
task single_read_task(input [31:0]	addr);
begin
	$display("read: [?] from [%08H]", addr);
	avl_addr <= addr;
	avl_wdata <= 0;
	avl_write_req <= 0;
	avl_read_req <= 1;
	avl_burstbegin <= 0;
	avl_size <= 1;
end
endtask	

	/////////////////////////////////////////////// 
	// 输出和DDR IP核的接口
	assign			local_address = avl_addr;
	assign			local_wdata = avl_wdata;
	assign			local_write_req = avl_write_req;
	assign			local_read_req = avl_read_req;
	assign			local_be = 4'HF;
	assign			local_size = avl_size;
	assign			local_burstbegin = avl_burstbegin;
	
	////////////////////////
endmodule