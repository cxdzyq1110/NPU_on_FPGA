// CNN指令集架构的执行器
module npu_inst_fsm
#(parameter	DATA_WIDTH = 32,    // 数据位宽
  parameter	FRAC_WIDTH = 16,	// 小数部分
  parameter RAM_LATENCY = 2,	// ram的IP核读取需要延时
  parameter MAC_LATENCY = 2,	// ram的IP核读取需要延时
  parameter	DIV_LATENCY = 50,	// 除法器的延时
  parameter	DMI_LATENCY = 2,	// 除法器的延时
  parameter	DATA_UNIT = {{(DATA_WIDTH-FRAC_WIDTH-1){1'B0}}, 1'B1, {FRAC_WIDTH{1'B0}}}, // 固定的单位1 
  parameter	DATA_ZERO = {DATA_WIDTH{1'B0}},	// 固定的0值
  parameter	INST_WIDTH = 128	// 指令的长度
)
(
	input	wire						clk, rst_n,	// 时钟和复位信号
	input	wire	[INST_WIDTH-1:0]	npu_inst_q,	// CNN的指令
	output	reg 	[DATA_WIDTH-1:0]	npu_inst_addr,	// CNN的指令地址
	input	wire						npu_inst_start,	// 指令使能标志
	output	reg							npu_inst_ready,	// 指令执行完成标志
	output	reg		[DATA_WIDTH-1:0]	npu_inst_time,	// 计量指令执行时间
	// DDR接口
	output	wire						DDR_WRITE_CLK,
	output	wire	[DATA_WIDTH-1:0]	DDR_WRITE_ADDR,
	output	wire	[DATA_WIDTH-1:0]	DDR_WRITE_DATA,
	output	wire						DDR_WRITE_REQ,
	input	wire						DDR_WRITE_READY,
	output	wire						DDR_READ_CLK,
	output	wire	[DATA_WIDTH-1:0]	DDR_READ_ADDR,
	output	wire						DDR_READ_REQ,
	input	wire						DDR_READ_READY,
	input	wire	[DATA_WIDTH-1:0]	DDR_READ_DATA,
	input	wire						DDR_READ_DATA_VALID
);

    // 使用状态机控制
    reg     [3:0]   cstate;
    reg     [10:0]  delay;
    reg             npu_inst_parser_en;
    wire            npu_inst_parser_ready;
    always @(posedge clk)
        if(!rst_n)
        begin
            cstate <= 0;
            npu_inst_parser_en <= 0;
        end
        else 
        begin
            case(cstate)
                0: begin
                    if(npu_inst_start)
                    begin
                        npu_inst_addr <= 0;
                        cstate <= 1;
                        delay <= 0;
                        npu_inst_parser_en <= 0;
                    end
                end
                
                1: begin
                    if(delay>=3)
                    begin
                        if(npu_inst_q==128'D0)  // NOP指令
                        begin
                            cstate <= 0;
                            npu_inst_parser_en <= 0;
                        end
                        else if(npu_inst_parser_ready)
                        begin
                            cstate <= 2;
                            npu_inst_parser_en <= 1;
                        end
                    end
                    
                    else
                        delay <= delay + 1;
                end
                
                2: begin
                    npu_inst_parser_en <= 0;    // 关断使能信号
                    cstate <= 5;
                    delay <= 0;
                end
                
                // 延时一下
                5: begin
                    if(delay>=5)
                        cstate <= 3;
                    else
                        delay <= delay + 1;
                end
                
                3: begin
                    if(npu_inst_parser_ready)
                    begin
                        cstate <= 4;
                        npu_inst_parser_en <= 0;
                    end
                end
                
                4: begin
                    npu_inst_addr <= npu_inst_addr + 1;
                    cstate <= 1;
                    delay <= 0;
                end
                
                
                default: begin
                    cstate <= 0;
                    npu_inst_parser_en <= 0;
                end
                
            endcase
        
        end
        
    //
    always @(posedge clk)
        npu_inst_ready <= (cstate==0);
        
    always @(posedge clk)
        if(npu_inst_start)
            npu_inst_time <= 0;
        else if(!npu_inst_ready)
            npu_inst_time <= npu_inst_time + 1;
        
    // CNN指令执行
	npu_inst_excutor			npu_inst_excutor_inst(
									.clk(clk),
									.rst_n(rst_n),
									.npu_inst(npu_inst_q),
									.npu_inst_en(npu_inst_parser_en),
									.npu_inst_ready(npu_inst_parser_ready),
									// DDR
									.DDR_WRITE_CLK(DDR_WRITE_CLK),
									.DDR_WRITE_ADDR(DDR_WRITE_ADDR),
									.DDR_WRITE_DATA(DDR_WRITE_DATA),
									.DDR_WRITE_REQ(DDR_WRITE_REQ),
									.DDR_WRITE_READY(DDR_WRITE_READY),
									.DDR_READ_CLK(DDR_READ_CLK),
									.DDR_READ_ADDR(DDR_READ_ADDR),
									.DDR_READ_REQ(DDR_READ_REQ),
									.DDR_READ_READY(DDR_READ_READY),
									.DDR_READ_DATA(DDR_READ_DATA),
									.DDR_READ_DATA_VALID(DDR_READ_DATA_VALID)
								);

endmodule