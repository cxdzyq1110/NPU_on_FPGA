//----------------------------------------------------------------------------------------------------------
//	FILE: 		uart_conf.inc
// 	AUTHOR:		Xudong Chen
// 	
//	ABSTRACT:	behavior of uart module
// 	KEYWORDS:	fpga, uart, IO
// 
// 	MODIFICATION HISTORY:
//	$Log$
//			Xudong Chen 	16/9/14		original, only for receive
//-----------------------------------------------------------------------------------------------------------

// sysclock should be 50MHz
// @9600 bps == baud rate
`define		UART_ONE_CYCLE			200 //5208 //434 //25 //434
`define		UART_ONE_HALF_CYCLE		300 //7812 //651 //38 //651
`define		UART_HALF_CYCLE			100 //2604 //217 //13 //217

