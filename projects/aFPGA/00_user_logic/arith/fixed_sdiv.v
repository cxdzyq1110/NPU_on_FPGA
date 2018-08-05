module fixed_sdiv
#(parameter	DATA_WIDTH = 32,    // 数据位宽
  parameter	FRAC_WIDTH = 16,	// 小数部分
  parameter	DATA_UNIT = {{(DATA_WIDTH-FRAC_WIDTH-1){1'B0}}, 1'B1, {FRAC_WIDTH{1'B0}}}, // 固定的单位1 
  parameter	DATA_ZERO = {DATA_WIDTH{1'B0}},	// 固定的0值
  parameter	PERIOD = ((DATA_WIDTH+FRAC_WIDTH)>>1)
)
(
	input	wire	sys_clk, sys_rst_n,		// 模块的时钟、复位信号
	//
	input	wire	[DATA_WIDTH-1:0]	numer,
	input	wire	[DATA_WIDTH-1:0]	denom,
	input	wire						src_en,
	output	reg		[DATA_WIDTH-1:0]	quotient,
	output	reg							dst_en
);

	// 首先输入的翻转
	wire	[DATA_WIDTH-1:0]	numer_pos;
	wire	[DATA_WIDTH-1:0]	denom_pos;
	assign	numer_pos = numer[DATA_WIDTH-1]? (~numer+1) : numer;
	assign	denom_pos = denom[DATA_WIDTH-1]? (~denom+1) : denom;
	
	// 迭代运算
	// 考虑到radix-2算法太消耗面积，而且总的clock周期太多
	// 这里采用radix-4的算法
	reg							src_enx			[0:PERIOD];
	reg		[2*DATA_WIDTH-1:0]	denom_tmp		[0:PERIOD];
	reg		[2*DATA_WIDTH-1:0]	numer_tmp		[0:PERIOD];
	reg							result_polar	[0:PERIOD];
	reg		[2*DATA_WIDTH-1:0]	judge_0			[0:PERIOD];	// 比较numer_tmp和denom_tmp
	reg		[2*DATA_WIDTH-1:0]	judge_1			[0:PERIOD];	// 比较numer_tmp和denom_tmp
	reg		[2*DATA_WIDTH-1:0]	judge_2			[0:PERIOD];	// 比较numer_tmp和denom_tmp
	reg		[2*DATA_WIDTH-1:0]	judge_3			[0:PERIOD];	// 比较numer_tmp和denom_tmp
	reg		[3:0]				_judge_			[0:PERIOD];	// 比较numer_tmp和denom_tmp
	// 要将比较器和减法器实现资源复用（FPGA内比较器就是减法器）
	integer q;
	always @(*)
	begin
		for(q=0; q<PERIOD; q=q+1)
		begin
			judge_0[q] = ({numer_tmp[q], 2'B00}-denom_tmp[q]);
			judge_1[q] = ({numer_tmp[q], 2'B00}-(denom_tmp[q]<<1));
			judge_2[q] = ({numer_tmp[q], 2'B00}-(denom_tmp[q] + (denom_tmp[q]<<1)));
			judge_3[q] = ({numer_tmp[q], 2'B00}-(denom_tmp[q]<<2));
			_judge_[q] = {judge_3[q][2*DATA_WIDTH-1], judge_2[q][2*DATA_WIDTH-1], judge_1[q][2*DATA_WIDTH-1], judge_0[q][2*DATA_WIDTH-1]};
		end
	end
	//assign	result_polar = denom[DATA_WIDTH-1]^numer[DATA_WIDTH-1];
	integer	p;
	always @(posedge sys_clk)
	begin
		// 复位的时候不要动，控制功耗
		if(!sys_rst_n)
		begin
			for(p=PERIOD; p>=0; p=p-1)
			begin
				result_polar[p] <= 0;
				numer_tmp[p] <= 0;
				denom_tmp[p] <= 0;
			end
		end
		//
		else
		begin
			result_polar[0] <= denom[DATA_WIDTH-1]^numer[DATA_WIDTH-1];
			numer_tmp[0] <= {8'H0, numer_pos};
			denom_tmp[0] <= {8'H0, denom_pos, {(DATA_WIDTH){1'B0}}};
			// 迭代
			for(p=PERIOD; p>=1; p=p-1)
			begin
				case(_judge_[p-1])
					4'B1000: numer_tmp[p] <= judge_2[p-1]+3;
					4'B1100: numer_tmp[p] <= judge_1[p-1]+2;	
					4'B1110: numer_tmp[p] <= judge_0[p-1]+1;
					4'B1111: numer_tmp[p] <= {numer_tmp[p-1], 2'B00};	
					default: numer_tmp[p] <= {numer_tmp[p-1], 2'B00};	
				endcase
				//
				denom_tmp[p] <= denom_tmp[p-1];
				result_polar[p] <= result_polar[p-1];
			end
		end
	end

	always @(posedge sys_clk)
	begin
		if(result_polar[PERIOD])
			quotient <= ~numer_tmp[PERIOD]+1;
		else
			quotient <= numer_tmp[PERIOD];
	end
	
	integer dp;
	always @ ( posedge sys_clk) 
	begin
		for(dp=1; dp<=PERIOD; dp=dp+1)
			src_enx[dp] <= src_enx[dp-1];
		
		src_enx[0] <= src_en;
		
		dst_en <= src_enx[PERIOD];
	end
	
endmodule