/*------------------------------------------------------------------------------*\
	FILE: 		top.v
 	AUTHOR:		Xudong Chen
 	
	ABSTRACT:	behavior of the top module of NPU
 	KEYWORDS:	fpga, NPU
 
 	MODIFICATION HISTORY:
	$Log$
			Xudong Chen 	18/8/5		original, 
\*-------------------------------------------------------------------------------*/
module top(
	//////// CLOCK //////////
	CLOCK_50,
	CLOCK2_50,
	CLOCK3_50,
	ENETCLK_25,

	//////// LED //////////
	LEDG,
	LEDR,

	//////// KEY //////////
	KEY,

	//////// SW //////////
	SW,

	//////// RS232 //////////
	UART_RXD,
	UART_TXD,

	
	//////// SRAM //////////
	SRAM_ADDR,
	SRAM_CE_N,
	SRAM_DQ,
	SRAM_LB_N,
	SRAM_OE_N,
	SRAM_UB_N,
	SRAM_WE_N
);



//=======================================================
//  PORT declarations
//=======================================================

	//////////// CLOCK //////////
	input		          		CLOCK_50;
	input		          		CLOCK2_50;
	input		          		CLOCK3_50;
	input		          		ENETCLK_25;

	//////////// LED //////////
	output		     [8:0]		LEDG;
	output		    [17:0]		LEDR;

	//////////// KEY //////////
	input		     [3:0]		KEY;

	//////////// SW //////////
	input		    [17:0]		SW;

	//////////// RS232 //////////
	input		          		UART_RXD;
	output		          		UART_TXD;

	//////////// SRAM //////////
	output		    [19:0]		SRAM_ADDR;
	output		          		SRAM_CE_N;
	inout		    [15:0]		SRAM_DQ;
	output		          		SRAM_LB_N;
	output		          		SRAM_OE_N;
	output		          		SRAM_UB_N;
	output		          		SRAM_WE_N;


////////////////////////////////////////////////////////
////////////////////////////////////////////////////////
////////////////////////////////////////////////////////
/*
	// 下面是SW拨码开关的配置
	[0]: reserved，恒为0
	[1]: reserved，恒为0
	[2]: reserved，恒为0
	[3]: 按钮KEY[3]按下触发CNN；1-->使能按钮触发
	[4]: reserved，恒为0
	[5]: 串口触发CNN运算，测试硬件化正确性；1-->使能串口触发
*/
////////////////////////////////////////////////////////

	// 三种模式
	wire 		TEST_MODE = (SW[5:1]==5'B10100);
	wire		SAMP_MODE = (SW[5:1]==5'B00011);
	wire		RUN_MODE = (SW[5:1]==5'B01001);
	wire		SIMU_MODE = (SW[5:1]==5'B01000);	// 仿真模式，切断MFCC写入SRAM的过程
	////////////////////////////////////////////////
	// 全局复位信号
	wire		RESET_N = KEY[0];
	// 同时用PLL重新生成一下全局时钟
	wire		CLOCK50, CLOCK60, CLOCK40, CLOCK10, CLOCK12p28;

	alt_pll_ip_core		alt_pll_ip_core_inst(
							.inclk0(CLOCK_50),
							.c0(CLOCK50),
							.c1(CLOCK60),
							.c2(CLOCK40),
							.c3(CLOCK10),
							.c4(CLOCK12p28)
						);
	////////////////////////////////////////////////////////////////
	// 系统运行的时钟和复位信号
	wire		sys_clk = CLOCK60;
	wire		sys_rst_n = RESET_N;
	// 然后是uart接口
	// 然后需要一个命令解析器，能够将数据扩充之后返回
	// 和uart的接口
	wire		[31:0]					sys_uart_write_data /* synthesis keep */;
	wire								sys_uart_write_data_valid /* synthesis keep */;
	wire								sys_uart_write_data_permitted /* synthesis keep */;
	wire		[15:0]					sys_uart_read_data /* synthesis keep */;
	wire								sys_uart_read_data_req /* synthesis keep */;
	wire								sys_uart_read_data_permitted /* synthesis keep */;
	// 和ddr的接口
	wire		[31:0]					sys_ddr_write_addr /* synthesis keep */;
	wire		[31:0]					sys_ddr_write_data /* synthesis keep */;
	wire								sys_ddr_write_data_valid /* synthesis keep */;
	wire								sys_ddr_write_burst_begin /* synthesis keep */;
	wire								sys_ddr_write_data_permitted /* synthesis keep */;
	wire		[31:0]					sys_ddr_read_addr /* synthesis keep */;
	wire		[31:0]					sys_ddr_read_data /* synthesis keep */;
	wire								sys_ddr_read_data_valid /* synthesis keep */;
	wire								sys_ddr_read_burst_begin /* synthesis keep */;
	wire								sys_ddr_read_data_req /* synthesis keep */;
	wire								sys_ddr_read_data_permitted /* synthesis keep */;
	wire								logic_receive_valid_cmd;
	/********************************************************************************************/
	// NPU指令接口
	wire		[31:0]					npu_inst_part;
	wire								npu_inst_part_en;
	/*
	*/
	cmd_parser			cmd_parser_inst(
							.sys_clk(sys_clk),
							.sys_rst_n(sys_rst_n),
							.sys_uart_write_data(sys_uart_write_data),
							.sys_uart_write_data_valid(sys_uart_write_data_valid),
							.sys_uart_write_data_permitted(sys_uart_write_data_permitted),
							.sys_uart_read_data(sys_uart_read_data),
							.sys_uart_read_data_req(sys_uart_read_data_req),
							.sys_uart_read_data_permitted(sys_uart_read_data_permitted),
							.sys_ddr_write_addr(sys_ddr_write_addr),
							.sys_ddr_write_data(sys_ddr_write_data),
							.sys_ddr_write_data_valid(sys_ddr_write_data_valid),
							.sys_ddr_write_burst_begin(sys_ddr_write_burst_begin),
							.sys_ddr_write_data_permitted(sys_ddr_write_data_permitted),
							.sys_ddr_read_addr(sys_ddr_read_addr),
							.sys_ddr_read_data(sys_ddr_read_data),
							.sys_ddr_read_data_valid(sys_ddr_read_data_valid),
							.sys_ddr_read_data_req(sys_ddr_read_data_req),
							.sys_ddr_read_burst_begin(sys_ddr_read_burst_begin),
							.sys_ddr_read_data_permitted(sys_ddr_read_data_permitted),
							.receive_valid_cmd(logic_receive_valid_cmd),
							.sys_key_fn(8'HFF),
							//
							.adc_ddr_write_addr(),
							.adc_ddr_write_addr_mask(),
							//
							.audio_sample_en(audio_sample_en),
							// NPU指令接口
							.npu_inst_part(npu_inst_part),
							.npu_inst_part_en(npu_inst_part_en)
						);
	// 串口
	// 例化一个cypress uart的读写模块
	// uart的slavefifo读写模块
	uart_wr				uart_wr_inst(
							.sys_clk(sys_clk),
							.sys_rst_n(sys_rst_n),
							.uart_rxd(UART_RXD),
							.uart_txd(UART_TXD),
							.uart_sys_clk(CLOCK50),
							.uart_sys_rst_n(RESET_N),
							.sys_write_data(sys_uart_write_data),
							.sys_write_data_valid(sys_uart_write_data_valid),
							.sys_write_data_permitted(sys_uart_write_data_permitted),
							.sys_read_data(sys_uart_read_data),
							.sys_read_data_req(sys_uart_read_data_req),
							.sys_read_data_permitted(sys_uart_read_data_permitted)
						);	
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////
	///////////////////////////// NPU 指令集架构
	/*
	*/
	wire	[127:0]				npu_inst /* synthesis noprune */;
	wire						npu_inst_en /* synthesis noprune */;
	wire						npu_inst_ready;
	// 计量NPU指令计算周期数
	wire	[31:0]				npu_inst_time;
	wire						NPU_DDR_WRITE_CLK;
	wire	[31:0]				NPU_DDR_WRITE_ADDR;
	wire	[31:0]				NPU_DDR_WRITE_DATA;
	wire						NPU_DDR_WRITE_REQ;
	wire						NPU_DDR_WRITE_READY;
	wire						NPU_DDR_READ_CLK;
	wire	[31:0]				NPU_DDR_READ_ADDR;
	wire						NPU_DDR_READ_REQ;
	wire						NPU_DDR_READ_READY;
	wire	[31:0]				NPU_DDR_READ_DATA;
	wire						NPU_DDR_READ_DATA_VALID;
	wire						npu_inst_clk = CLOCK60;
	wire						npu_inst_rst_n = RESET_N;
    wire    [31:0]              npu_inst_addr;
    wire    [127:0]             npu_inst_q;
	wire						npu_inst_start_vad;	// 允许另一个模块启动NPU运算
	// 这里debug一下；因为不确定NPU卡住/不断被触发
	// 所以NPU运算使能，需要有debug措施：如果 KEY_CNN ==1，那么由按钮按下触发；否则，就是正常工作	// mark: 2018/6/4
	wire						KEY3_DOWN;	// 按下按钮3
    wire                        npu_inst_start = TEST_MODE? ((npu_inst_en && npu_inst==128'D2)|KEY3_DOWN) : (RUN_MODE||SIMU_MODE)? npu_inst_start_vad : 0;	
	npu_inst_fsm				npu_inst_fsm_inst(
									.clk(npu_inst_clk),
									.rst_n(npu_inst_rst_n),
									.npu_inst_addr(npu_inst_addr),
									.npu_inst_q(npu_inst_q),
									.npu_inst_start(npu_inst_start),
									.npu_inst_ready(npu_inst_ready),
									.npu_inst_time(npu_inst_time),
									// DDR
									.DDR_WRITE_CLK(NPU_DDR_WRITE_CLK),
									.DDR_WRITE_ADDR(NPU_DDR_WRITE_ADDR),
									.DDR_WRITE_DATA(NPU_DDR_WRITE_DATA),
									.DDR_WRITE_REQ(NPU_DDR_WRITE_REQ),
									.DDR_WRITE_READY(NPU_DDR_WRITE_READY),
									.DDR_READ_CLK(NPU_DDR_READ_CLK),
									.DDR_READ_ADDR(NPU_DDR_READ_ADDR),
									.DDR_READ_REQ(NPU_DDR_READ_REQ),
									.DDR_READ_READY(NPU_DDR_READ_READY),
									.DDR_READ_DATA(NPU_DDR_READ_DATA),
									.DDR_READ_DATA_VALID(NPU_DDR_READ_DATA_VALID)
								);
	// 生成 按下按钮的信号
	reg		[1:0]				KEY3;
	always @(posedge npu_inst_clk)
		KEY3 <= {KEY3[0], KEY[3]};
	assign						KEY3_DOWN = (KEY3==2'B10);
                                
    // 存储NPU指令的地址
    reg     [31:0]      npu_inst_wraddr;
    always @(posedge npu_inst_clk)
        if(npu_inst_en && npu_inst==128'D1)
            npu_inst_wraddr <= 0;
        else if(npu_inst_en && npu_inst!=128'D1 && npu_inst!=128'D2)
            npu_inst_wraddr <= npu_inst_wraddr  +1;
    // 然后要将NPU指令存储到RAM里面去
    npu_inst_ram            npu_inst_ram_inst(
                                .data(npu_inst),
                                .wren(npu_inst_en && npu_inst!=128'D1 && npu_inst!=128'D2),
                                .wraddress(npu_inst_wraddr),
                                .wrclock(npu_inst_clk),
                                .rdclock(npu_inst_clk),
                                .rdaddress(npu_inst_addr),
                                .q(npu_inst_q)
                            );   
    // 然后要将NPU指令存储到RAM里面去，并可以通过memory editor观察
    npu_inst_ram_bak        npu_inst_ram_bak_inst(
                                .data(npu_inst),
                                .wren(npu_inst_en && npu_inst!=128'D1 && npu_inst!=128'D2),
                                .address(npu_inst_wraddr),
                                .clock(npu_inst_clk)
                            );   
							
	// 生成npu_inst/npu_inst_en
	// 超时等待机制
	npu_inst_join			npu_inst_join_inst(
								.npu_inst_clk(npu_inst_clk),
								.npu_inst_rst_n(npu_inst_rst_n),
								.npu_inst_part(npu_inst_part),
								.npu_inst_part_en(npu_inst_part_en),
								.npu_inst(npu_inst),
								.npu_inst_en(npu_inst_en)
							);
	/////////////////////////////////////////////////////////////////////
	// 配置CNN的参数
	// 配置CNN的参数
	wire					cnn_paras_ready;	// 参数配置模块闲置状态
	wire					cnn_paras_en = !KEY[2];	// 使能配置
	wire	[31:0]			cnn_paras_q;	// CNN的参数
	wire	[31:0]			cnn_paras_addr;	// CNN参数的地址
	// DDR接口
	wire					CNN_DDR_WRITE_CLK;
	wire	[31:0]			CNN_DDR_WRITE_ADDR;
	wire	[31:0]			CNN_DDR_WRITE_DATA;
	wire					CNN_DDR_WRITE_REQ;
	wire					CNN_DDR_WRITE_READY;
	//
	npu_paras_rom			npu_paras_rom_inst(
								.clock(CLOCK60),
								.address(cnn_paras_addr),
								.q(cnn_paras_q)
							);
	
	npu_paras_config		npu_paras_config_inst(
								.clk(CLOCK60),
								.rst_n(RESET_N),
								.npu_paras_ready(cnn_paras_ready),
								.npu_paras_en(cnn_paras_en),
								.npu_paras_addr(cnn_paras_addr),
								.npu_paras_q(cnn_paras_q),
								// DDR
								.DDR_WRITE_CLK(CNN_DDR_WRITE_CLK),
								.DDR_WRITE_ADDR(CNN_DDR_WRITE_ADDR),
								.DDR_WRITE_DATA(CNN_DDR_WRITE_DATA),
								.DDR_WRITE_REQ(CNN_DDR_WRITE_REQ),
								.DDR_WRITE_READY(CNN_DDR_WRITE_READY)
							);
	/////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////
	///////////////////
	// 和内存有关的时钟和复位
	wire		afi_phy_clk /* synthesis keep */;
	wire		afi_phy_rst_n /* synthesis keep */;
	// SSRAM
	// 添加一个缓存空间	// 使用ddr的IP核
	//	// 声明核心多路选通控制器
	wire        local_ready;                //              local.waitrequest_n
	wire        local_burstbegin;           //                   .beginbursttransfer
	wire [31:0] local_addr;                 //                   .address
	wire        local_rdata_valid;          //                   .readdatavalid
	wire [31:0] local_rdata;                //                   .readdata
	wire [31:0] local_wdata;                //                   .writedata
	wire [3:0]  local_be;                   //                   .byteenable
	wire        local_read_req;             //                   .read
	wire        local_write_req;            //                   .write
	wire [2:0]  local_size;                 //                   .burstcount
	wire		local_waitrequest;
	//	// 声明附属多路选通控制器
	wire        attach_ready;                //              attach.waitrequest_n
	wire        attach_burstbegin;           //                   .beginbursttransfer
	wire [31:0] attach_addr;                 //                   .address
	wire        attach_rdata_valid;          //                   .readdatavalid
	wire [31:0] attach_rdata;                //                   .readdata
	wire [31:0] attach_wdata;                //                   .writedata
	wire [3:0]  attach_be;                   //                   .byteenable
	wire        attach_read_req;             //                   .read
	wire        attach_write_req;            //                   .write
	wire [2:0]  attach_size;                 //                   .burstcount
	wire		attach_ready_w, attach_ready_r;	// 读写允许
	assign		attach_ready = 	attach_write_req? attach_ready_w : 
								attach_read_req? attach_ready_r : 
								attach_ready_w && attach_ready_r;	// 挂载在核心选通上，必须读写都允许的情况下可以允许附属选通器读写
	//
	///////// 复位信号
	// 例化SSRAM控制器
	sram_controller		sram_controller_inst(
							.CLOCK(CLOCK40),
							.RESET_N(RESET_N),
							.sram_avalon_clock(afi_phy_clk),
							.sram_avalon_reset_n(afi_phy_rst_n),
							.sram_avalon_address(local_addr),
							.sram_avalon_writedata(local_wdata),
							.sram_avalon_write_n(!local_write_req),
							.sram_avalon_read_n(!local_read_req),
							.sram_avalon_readdata(local_rdata),
							.sram_avalon_readdatavalid(local_rdata_valid),
							.sram_avalon_waitrequest(local_waitrequest),
							//
							.sram_pins_addr(SRAM_ADDR),
							.sram_pins_dq(SRAM_DQ),
							.sram_pins_ce_n(SRAM_CE_N),
							.sram_pins_oe_n(SRAM_OE_N),
							.sram_pins_we_n(SRAM_WE_N),
							.sram_pins_lb_n(SRAM_LB_N),
							.sram_pins_ub_n(SRAM_UB_N)
						);
	////////////////////////////////////////////////////////////////////////////////////////
	mux_ddr_access		mux_ddr_access_local_inst(
							.afi_phy_clk(afi_phy_clk),
							.afi_phy_rst_n(afi_phy_rst_n),
							//
							.local_address(local_addr),
							.local_write_req(local_write_req),
							.local_read_req(local_read_req),
							.local_burstbegin(local_burstbegin),
							.local_wdata(local_wdata),
							.local_be(local_be),
							.local_size(local_size),
							.local_ready(!local_waitrequest),
							.local_rdata(local_rdata),
							.local_rdata_valid(local_rdata_valid),
							//.local_refresh_ack,
							.local_init_done(RESET_N),
							///////////////
							// 附属的多路选通器
							.wport_clock_6(afi_phy_clk),
							.wport_addr_6(attach_addr),
							.wport_data_6(attach_wdata),
							.wport_req_6(attach_write_req),
							.wport_ready_6(attach_ready_w),
							.rport_clock_7(afi_phy_clk),
							.rport_addr_7(attach_addr),
							.rport_data_7(attach_rdata),
							.rport_data_valid_7(attach_rdata_valid),
							.rport_req_7(attach_read_req),
							.rport_ready_7(attach_ready_r),
							// MFCC特征搬运 mark[2018/6/6]: 测试CNN状态下，禁止MFCC写入
							.wport_clock_4(),
							.wport_addr_4(),
							.wport_data_4(),
							.wport_req_4(),
							.wport_ready_4(),
							// MFCC特征搬运
							.rport_clock_3(),
							.rport_addr_3(),
							.rport_data_3(),
							.rport_data_valid_3(),
							.rport_req_3(),
							.rport_ready_3(),
							// CNN参数配置接口 mark[2018/6/6]: 测试CNN状态下，不能禁止CNN参数写入
							.wport_clock_2(CNN_DDR_WRITE_CLK),
							.wport_addr_2(CNN_DDR_WRITE_ADDR),
							.wport_data_2(CNN_DDR_WRITE_DATA),
							.wport_req_2(CNN_DDR_WRITE_REQ && (RUN_MODE||TEST_MODE||SIMU_MODE)),
							.wport_ready_2(CNN_DDR_WRITE_READY),
							// NPU读写接口
							.wport_clock_0(NPU_DDR_WRITE_CLK),
							.wport_addr_0(NPU_DDR_WRITE_ADDR),
							.wport_data_0(NPU_DDR_WRITE_DATA),
							.wport_req_0(NPU_DDR_WRITE_REQ && (RUN_MODE||TEST_MODE||SIMU_MODE)),
							.wport_ready_0(NPU_DDR_WRITE_READY),
							// NPU读写接口
							.rport_clock_1(NPU_DDR_READ_CLK),
							.rport_addr_1(NPU_DDR_READ_ADDR),
							.rport_data_1(NPU_DDR_READ_DATA),
							.rport_data_valid_1(NPU_DDR_READ_DATA_VALID),
							.rport_req_1(NPU_DDR_READ_REQ && (RUN_MODE||TEST_MODE||SIMU_MODE)),
							.rport_ready_1(NPU_DDR_READ_READY)
						);
	// 附属多路选通
	mux_ddr_access		mux_ddr_access_attach_inst(
							.afi_phy_clk(afi_phy_clk),
							.afi_phy_rst_n(afi_phy_rst_n),
							//
							.local_address(attach_addr),
							.local_write_req(attach_write_req),
							.local_read_req(attach_read_req),
							.local_burstbegin(attach_burstbegin),
							.local_wdata(attach_wdata),
							.local_be(attach_be),
							.local_size(attach_size),
							.local_ready(attach_ready),
							.local_rdata(attach_rdata),
							.local_rdata_valid(attach_rdata_valid),
							//.local_refresh_ack,
							.local_init_done(RESET_N),
							///////////////
							// 测试 写入
							.wport_clock_4(sys_clk),
							.wport_addr_4(sys_ddr_write_addr),
							.wport_data_4(sys_ddr_write_data),
							.wport_req_4(sys_ddr_write_data_valid),
							.wport_ready_4(sys_ddr_write_data_permitted),
							// 测试 读取
							.rport_clock_5(sys_clk),
							.rport_addr_5(sys_ddr_read_addr),
							.rport_data_5(sys_ddr_read_data),
							.rport_data_valid_5(sys_ddr_read_data_valid),
							.rport_req_5(sys_ddr_read_data_req),
							.rport_ready_5(sys_ddr_read_data_permitted),
							// 音频信号 写入
							.wport_clock_0(),
							.wport_addr_0(),
							.wport_data_0(),
							.wport_req_0(),
							.wport_ready_0(),
							// MFCC特征 写入
							.wport_clock_2(),
							.wport_addr_2(),
							.wport_data_2(),
							.wport_req_2(),
							.wport_ready_2()
							
						);
	


endmodule