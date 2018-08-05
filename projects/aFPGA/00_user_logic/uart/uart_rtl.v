//----------------------------------------------------------------------------------------------------------
//	FILE: 		uart_rtl.v
// 	AUTHOR:		Xudong Chen
// 	
//	ABSTRACT:	behavior of uart module
// 	KEYWORDS:	fpga, uart, IO
// 
// 	MODIFICATION HISTORY:
//	$Log$
//			Xudong Chen 	16/9/14		original, only for receive
// 			Xudong Chen		18/1/2		add "transfer" function
//-----------------------------------------------------------------------------------------------------------
`include "uart_conf.inc"
module uart_rtl(clock,rst,uart_rxd,rx_en,rx_data,uart_txd,tx_en,tx_data,tx_busy);

	input		clock,rst;			// clock  and reset signals
	input		uart_rxd;			// rxd line for uart
	output		rx_en;				// impulse for rx_data_valid
	output		[7:0]	rx_data;	// received data
	output		uart_txd;			// txd line for uart
	input		tx_en;				// impulse for tx_data_valid
	input		[31:0]	tx_data;	// data to transfer
	output	reg	tx_busy;			// busy when transfering
	
	//////////////////////
	reg			[15:0]	base_counter;
	reg			[3:0]	bit_counter;
	wire		bit_count_zero_flag;	// flag that says bit counter is zero
	
	
	reg			ready;
	reg			bit_in;
	
	always @(posedge clock)
		if(rst || !ready)
			base_counter <= 16'D0;
		else if(bit_count_zero_flag && base_counter==(`UART_ONE_HALF_CYCLE))
			begin
				base_counter <= 16'D0;
				bit_in <= 1'B1;
			end
		else if(!bit_count_zero_flag && base_counter == (`UART_ONE_CYCLE))
			begin
				base_counter <= 16'D0;
				bit_in <= 1'B1;
			end
		else
			begin
				base_counter <= base_counter + 16'D1;
				bit_in <= 1'B0;
			end
		
	
	always @(posedge clock)
		if(rst || !ready || (bit_counter == 4'D8 && bit_in && uart_rxd==1'B1))
			bit_counter <= 4'D0;
		else if(bit_in)
			bit_counter <= bit_counter + 4'D1;
	
	assign	bit_count_zero_flag = (bit_counter==4'D0);
	
	reg		[15:0]	counter;
	wire	sample = (counter == (`UART_ONE_CYCLE));
	always @(posedge clock)
		if(rst)
			counter <= 16'D0;
		else if(sample)
			counter <= 16'D0;
		else
			counter <= counter + 16'D1;
	
	reg		[10:0]	recv;
	always @(posedge clock)
		if(rst)
			recv <= 11'H000;
		else if(sample)
			//recv <= {iRXD,recv[9:1]};
			recv <= {recv[9:0],uart_rxd};
			
	reg		first_bit;
	always @(posedge clock)
		if(rst)
			first_bit <= 1'B0;
		else if(bit_count_zero_flag && base_counter==(`UART_HALF_CYCLE))
			first_bit <= uart_rxd;
	
	
	// 下降沿的检测很重要
	reg		[3:0]	jrxd;
	always @(posedge clock)
		if(rst)
			jrxd <= 4'H0;
		else
			jrxd <= {jrxd[2:0],uart_rxd};
	wire	rxd_dn = (jrxd == 4'HC);
	
	reg		recv_ones;
	always @(posedge clock)
		if(rst)
			recv_ones <= 1'B0;
		else if(recv == 11'H7FF)
			recv_ones <= 1'B1;
		else 
			recv_ones <= 1'B0;
	
	reg		recv_ones_x;
	always @(posedge clock)
		recv_ones_x <= recv_ones;
	wire	recv_ones_up = !recv_ones_x && recv_ones;
	
	always @(posedge clock)
		if(rst || recv_ones_up)
			ready <= 1'B0;
		else if(!ready && rxd_dn)
			ready <= 1'B1;
			// 需要 停止位 的 检测
		else if(ready && bit_counter==4'D8 && bit_in && uart_rxd==1'B1)
			ready <= 1'B0;
		
	reg		[9:0]	ready_x;
	always @(posedge clock)
		if(rst)
			ready_x <= 10'H000;
		else
			ready_x <= {ready_x[8:0],ready};
	
	
	// LSB >> MSB
	reg		[7:0]	rx_datax;
	reg		[7:0]	data_recv;
	always @(posedge clock)	
		if(rst || !ready)
			rx_datax <= 8'H00;
		else if(ready && bit_in && bit_counter<=4'D7)
			rx_datax <= {uart_rxd,rx_datax[7:1]};
	
	always @(posedge clock)
		if(rst)
			data_recv <= 8'H00;
		else if(ready && bit_counter==4'D8 && bit_in)
			data_recv <= rx_datax;
	
	assign	rx_en = (ready_x==10'H3E0);
	assign	rx_data = data_recv;
	/////////////////////////////////
	
	// 把数据LSB与MSB交换
	integer			i;
	reg		[31:0]	tx_data_reversed;
	always @(*)
		for(i=0; i<32; i=i+1)
			tx_data_reversed[i] = tx_data[31-i];
	
	// 然后是发送部分
	reg		[31:0]	tx_cnt;
	reg		[43:0]	tx_shifter;
	reg		[9:0]	tx_bit;
	reg		[3:0]	tx_state;
	always @(posedge clock)
		if(rst)
		begin
			tx_shifter <= 44'HFFF_FFFF_FFFF;
			tx_cnt <= 0;
			tx_bit <= 0;
			tx_busy <= 0;
			tx_state <= 0;
		end
		else 
		begin
			case(tx_state)
				0: begin
					if(tx_en)
					begin
						tx_shifter <= {	2'B10, tx_data_reversed[7:0], 1'B1,
										2'B10, tx_data_reversed[15:8], 1'B1,
										2'B10, tx_data_reversed[23:16], 1'B1,
										2'B10, tx_data_reversed[31:24], 1'B1
									};
						tx_busy <= 1;
						tx_cnt <= 0;
						tx_bit <= 0;
						tx_state <= 1;
					end
				end
				
				1: begin
					if(tx_cnt>=`UART_ONE_CYCLE)
					begin
						tx_cnt <= 0;
						if(tx_bit>=43)
						begin
							tx_busy <= 0;
							tx_state <= 0;
							tx_bit <= 0;
						end
						else
						begin
							tx_bit <= tx_bit + 1;
							tx_shifter <= {tx_shifter[42:0], 1'B1};
						end
					end
					else 
						tx_cnt <= tx_cnt + 1;
				end
				
				default: begin
					tx_shifter <= 44'HFFF_FFFF_FFFF;
					tx_cnt <= 0;
					tx_bit <= 0;
					tx_busy <= 0;
					tx_state <= 0;
				end
			endcase
		end
	
	assign	uart_txd = tx_shifter[43];
			
endmodule
	