module sram_controller
(
	input	wire						CLOCK,
	input	wire						RESET_N,		// 系统时钟/复位
	output	wire						sram_avalon_clock,
	output	reg							sram_avalon_reset_n,
	input	wire	[19:0]				sram_avalon_address,
	input	wire	[31:0]				sram_avalon_writedata,
	input	wire						sram_avalon_write_n,
	input	wire						sram_avalon_read_n,
	output	reg		[31:0]				sram_avalon_readdata,
	output	reg							sram_avalon_readdatavalid,
	output	wire						sram_avalon_waitrequest,
	
	// sram
	output	reg		[19:0]				sram_pins_addr,
	inout			[15:0]				sram_pins_dq,
	output	reg							sram_pins_ce_n,
	output	reg							sram_pins_oe_n,
	output	reg							sram_pins_we_n,
	output	reg							sram_pins_ub_n,
	output	reg							sram_pins_lb_n
);

	wire			afi_phy_clk = CLOCK;	// 系统时钟/复位
	assign			sram_pins_clk = CLOCK;
	
	always @(posedge afi_phy_clk)
		sram_avalon_reset_n <= RESET_N;

	// 片选始终有效，字节有效
	always @(posedge afi_phy_clk)
	begin
		sram_pins_ce_n <= 0;
		sram_pins_ub_n <= 0;
		sram_pins_lb_n <= 0;
	end
	// 使用状态机来控制读写请求
	reg			[3:0]		cstate;
	reg			[15:0]		sram_pins_dq_reg;
	reg						wait_request;	// 这个信号很重要，不然会产生死锁！
	reg						read_valid;
	assign					sram_avalon_waitrequest = (!sram_avalon_write_n || !sram_avalon_read_n) && !wait_request;
	always @(posedge afi_phy_clk)
		if(!RESET_N)
		begin
			cstate <= 0;
			wait_request <= 0;
			read_valid <= 0;
		end
		else
		begin
			case(cstate)
				0: begin
					// 如果收到写入请求
					if(!sram_avalon_write_n)
					begin
						// 首先写入低word
						sram_pins_addr <= {sram_avalon_address, 1'B0};
						sram_pins_dq_reg <= sram_avalon_writedata[15:0];
						wait_request <= 1;
						sram_pins_we_n <= 0;	// 写入使能
						sram_pins_oe_n <= 1;	// 读取不使能
						// 跳到1状态继续高word
						cstate <= 1;
					end
					// 否则如果是读取请求
					else if(!sram_avalon_read_n)
					begin
						// 首先读取低word
						sram_pins_addr <= {sram_avalon_address, 1'B0};
						wait_request <= 1;
						sram_pins_we_n <= 1;	// 写入不使能
						sram_pins_oe_n <= 0;	// 读取使能
						// 跳到2状态继续高word
						cstate <= 2;
					end
					// 否则关断写入/读取使能
					else
					begin
						sram_pins_we_n <= 1;
						sram_pins_oe_n <= 1;
						wait_request <= 0;
					end
					// 
					read_valid <= 0;
				end

				1: begin
					sram_pins_addr <= {sram_avalon_address, 1'B1};
					sram_pins_dq_reg <= sram_avalon_writedata[31:16];
					wait_request <= 0;
					sram_pins_we_n <= 0;	// 写入使能
					sram_pins_oe_n <= 1;	// 读取不使能
					// 跳到0状态
					cstate <= 0;
				end
				
				2: begin
					sram_pins_addr <= {sram_avalon_address, 1'B1};
					wait_request <= 0;
					sram_pins_we_n <= 1;	// 写入不使能
					sram_pins_oe_n <= 0;	// 读取使能
					// 跳到0状态
					cstate <= 0;
					// 生成readdata_valid信号
					read_valid <= 1;
				end	

				default: begin
					wait_request <= 0;
					cstate <= 0;
					read_valid <= 0;
				end
				
			endcase
		end
	
	
	// 把SSRAM中读取的数据传递出来！
	// 生成readdata_valid信号
	always @(posedge afi_phy_clk)
	begin
		sram_avalon_readdata <= {sram_pins_dq, sram_avalon_readdata[31:16]};
		sram_avalon_readdatavalid <= read_valid;
	end
		
	
////////////////////////////////////////
// Avalon
	assign	sram_avalon_clock = afi_phy_clk;
	
// SSRAM
	assign	sram_pins_dq = !sram_pins_we_n? sram_pins_dq_reg : 16'HZZZZ;

endmodule