//----------------------------------------------------------------------------------------------------------
//	FILE: 		npu_paras_config.v
// 	AUTHOR:		Xudong Chen
// 	
//	ABSTRACT:	config CNN parameters into DDR/SRAM RAM
// 	KEYWORDS:	fpga, cnn, parameter, RAM
// 
// 	MODIFICATION HISTORY:
//	$Log$
//			Xudong Chen		18/3/9		original, 用来往DDR里面写入CNN的参数
//										
//-----------------------------------------------------------------------------------------------------------
// CNN指令集架构的解析器
module npu_paras_config
#(parameter	DATA_WIDTH = 32,    // 数据位宽
  parameter	FRAC_WIDTH = 16,	// 小数部分
  parameter RAM_LATENCY = 2,	// ram的IP核读取需要延时
  parameter	PARA_BIAS = 32'H00010000	// CNN参数的偏移地址
)
(
	input	wire						clk, rst_n,	// 时钟和复位信号
	input	wire						npu_paras_en,	// 使能配置
	output	wire						npu_paras_ready,	// CNN参数配置空闲
	input	wire	[DATA_WIDTH-1:0]	npu_paras_q,	// CNN的参数
	output	reg		[DATA_WIDTH-1:0]	npu_paras_addr,	// CNN参数的地址
	// DDR接口
	output	wire						DDR_WRITE_CLK,
	output	wire	[DATA_WIDTH-1:0]	DDR_WRITE_ADDR,
	output	wire	[DATA_WIDTH-1:0]	DDR_WRITE_DATA,
	output	wire						DDR_WRITE_REQ,
	input	wire						DDR_WRITE_READY
);
	
	reg		[31:0]	ddr_write_addr;
	reg				ddr_write_req;
	wire			ddr_write_ready;
	reg		[31:0]	ddr_write_data;
	///////////
	assign			DDR_WRITE_CLK = clk;
	assign			DDR_WRITE_ADDR = ddr_write_addr;
	assign			DDR_WRITE_DATA = ddr_write_data;
	assign			DDR_WRITE_REQ = ddr_write_req;
	assign			ddr_write_ready = DDR_WRITE_READY;
	
	wire			ddr_write_data_valid = ddr_write_ready && ddr_write_req;	// 表示一次数据成功写入
	//
	// 检测 npu_paras_en 上升沿
	reg				npu_paras_enx;
	always @(posedge clk)
		npu_paras_enx <= npu_paras_en;
	wire			npu_paras_en_up = (!npu_paras_enx && npu_paras_en);	// 上升沿
	//
	reg		[3:0]	cstate;
	reg		[31:0]	delay;
	reg		[31:0]	total_paras_num;	// 所有的参数数量
	always @(posedge clk)
		if(!rst_n)
		begin
			cstate <= 0;
			delay <= 0;
			npu_paras_addr <= 0;
			ddr_write_req <= 0;	// 撤销DDR写入使能
		end
		else
		begin
			case(cstate)
				0: begin
					if(npu_paras_en_up)
					begin
						cstate <= 1;
						npu_paras_addr <= 0;
						delay <= 0;
					end
					//
					ddr_write_req <= 0;	// 撤销DDR写入使能
				end
				// 等待RAM读取完成
				1: begin
					if(delay>RAM_LATENCY)
					begin
						cstate <= 2;	// 进入逐步读取所有参数
						total_paras_num <= npu_paras_q;	// 获取参数数量
						delay <= 0;
						ddr_write_addr <= PARA_BIAS;
					end
					else
						delay <= delay + 1;
					///////	
					ddr_write_req <= 0;	// 撤销DDR写入使能
				end
				// 逐步读取所有的参数
				2: begin
					if(npu_paras_addr>total_paras_num)
					begin
						cstate <= 0;
						npu_paras_addr <= 0;
						delay <= 0;
					end
					else
					begin
						cstate <= 3;	// 进入读取RAM的等待阶段
						npu_paras_addr <= npu_paras_addr + 1;
						delay <= 0;
					end
					ddr_write_req <= 0;	// 撤销DDR写入使能
				end
				// 等待参数读取出来
				3: begin
					if(delay>RAM_LATENCY)
					begin
						cstate <= 4;	// 进入写入DDR的状态
						ddr_write_data <= npu_paras_q;
						ddr_write_req <= 1;	// 写入DDR，然后等待写入完成
						delay <= 0;
					end
					else
						delay <= delay + 1;
				end
				// 等待参数写入DDR完成
				4: begin
					if(ddr_write_ready)
					begin
						ddr_write_req <= 0;	// 撤销DDR写入使能
						ddr_write_addr <= ddr_write_addr + 1;	// DDR写入地址+1
						cstate <= 2;	// 进入读取下一个参数的任务
					end
				end
				//
				default: begin
					cstate <= 0;
					delay <= 0;
					npu_paras_addr <= 0;
					ddr_write_req <= 0;	// 撤销DDR写入使能
				end
				
			endcase
		
		end
	/////////////////////////////////////////////////////////
	assign	npu_paras_ready = (cstate==0);
	////////////////////////////////////////////////////
endmodule
	