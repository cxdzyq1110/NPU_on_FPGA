/*-------------------------------------------------------------------------------*\
	FILE:			gray_dec_1p.v
	AUTHOR:			Xudong Chen
	CREATED BY:		Xudong Chen
	$Id$
	ABSTRACT:		behavioral code for gray decode module, with 1-clock pipeline
	
	KEYWORDS:		gray, decode, 1-clock pipeline 
	MODIFICATION HISTORY:
	$Log$
		Xudong 		18/6/20			original version
\*-------------------------------------------------------------------------------*/
module gray_dec_1p
#(
parameter	WIDTH = 6			// 宽度
)
(
input		wire					clock,	// 时钟
input		wire	[WIDTH-1:0]		src,	// 源数据
output		reg		[WIDTH-1:0]		dst		// 目标数据
);

// 
integer	p;
reg		[WIDTH-1:0]	dst_x;
always @(*)
begin
	dst_x[WIDTH-1] = src[WIDTH-1];		// b[N-1] = g[N-1]
	for(p=WIDTH-2; p>=0; p=p-1)
	begin
		dst_x[p] = src[p]^dst_x[p+1];		// b[n] = g[n]^b[n+1]	, 0 <= n <= N-2
	end
end

// 输出打一拍
always @(posedge clock)
	dst <= dst_x;

endmodule