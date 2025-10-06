module vga_timing#(
		parameter H_ACTIVE = 16'd1280,   	//水平有效像素数
		parameter H_FP    = 16'd110,		//水平前沿（像素）
		parameter H_SYNC   = 16'd40,   		//水平同步脉冲宽度（像素）
		parameter H_BP   = 16'd220,  		//水平后沿（像素）
		parameter V_ACTIVE = 16'd720,		//垂直有效行数
		parameter V_FP     = 16'd5,  		//垂直前沿（行）
		parameter V_SYNC   = 16'd5,  		//垂直同步脉冲宽度（行）
		parameter V_BP     = 16'd20, 		//垂直后沿（行）
		parameter HS_POL   = 1'b1,   		//水平同步极性，1为正，0为负
		parameter VS_POL   = 1'b1    		//垂直同步极性，1为正，0为负
)(
		input                 clk,           //像素时钟
		input                 rst,           //高电平复位信号
		output                hs,            //水平同步信号
		output                vs,            //垂直同步信号
		output                de,            //视频有效信号

		output reg [11:0] active_x,           //当前像素的x坐标
		output reg [11:0] active_y            //当前像素的y坐标
	
	);

		parameter H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP;//水平总周期（像素）
		parameter V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;//垂直总周期（行）

reg hs_reg;                      //水平同步寄存器
reg vs_reg;                      //垂直同步寄存器
reg[11:0] h_cnt;                 //水平计数器
reg[11:0] v_cnt;                 //垂直计数器

reg h_active;                    //水平有效信号
reg v_active;                    //垂直有效信号
assign hs = hs_reg;
assign vs = vs_reg;
assign de = h_active & v_active;


// 水平计数
always@(posedge clk or posedge rst)
begin
		if(rst == 1'b1)
			h_cnt <= 12'd0;
		else if(h_cnt == H_TOTAL - 1)//水平计数器最大值
			h_cnt <= 12'd0;
		else
			h_cnt <= h_cnt + 12'd1;
end
// 有效像素计数
always@(posedge clk)
begin
		if(h_cnt >= H_FP + H_SYNC + H_BP)//水平有效区
			active_x <= h_cnt - (H_FP[11:0] + H_SYNC[11:0] + H_BP[11:0]);
		else
			active_x <= active_x;
end
always@(posedge clk)
begin	
		if(v_cnt >= V_FP + V_SYNC + V_BP)//垂直有效区
			active_y <= v_cnt - (V_FP[11:0] + V_SYNC[11:0] + V_BP[11:0]);
		else
			active_y <= active_y;
end
// 垂直计数
always@(posedge clk or posedge rst)
begin
		if(rst == 1'b1)
			v_cnt <= 12'd0;
		else if(h_cnt == H_FP  - 1)//每行结束时
			if(v_cnt == V_TOTAL - 1)//垂直计数器最大值
				v_cnt <= 12'd0;
			else
				v_cnt <= v_cnt + 12'd1;
		else
			v_cnt <= v_cnt;
end
// 水平同步信号生成
always@(posedge clk or posedge rst)
begin
		if(rst == 1'b1)
			hs_reg <= 1'b0;
		else if(h_cnt == H_FP - 1)//水平同步开始
			hs_reg <= HS_POL;
		else if(h_cnt == H_FP + H_SYNC - 1)//水平同步结束
			hs_reg <= ~hs_reg;
		else
			hs_reg <= hs_reg;
end
// 水平有效信号生成
always@(posedge clk or posedge rst)
begin
		if(rst == 1'b1)
			h_active <= 1'b0;
		else if(h_cnt == H_FP + H_SYNC + H_BP - 1)//水平有效区开始
			h_active <= 1'b1;
		else if(h_cnt == H_TOTAL - 1)//水平有效区结束
			h_active <= 1'b0;
		else
			h_active <= h_active;
end
// 垂直同步信号生成
always@(posedge clk or posedge rst)
begin
		if(rst == 1'b1)
			vs_reg <= 1'd0;
		else if((v_cnt == V_FP - 1) && (h_cnt == H_FP - 1))//垂直同步开始
			vs_reg <= HS_POL;
		else if((v_cnt == V_FP + V_SYNC - 1) && (h_cnt == H_FP - 1))//垂直同步结束
			vs_reg <= ~vs_reg;  
		else
			vs_reg <= vs_reg;
end
// 垂直有效信号生成
always@(posedge clk or posedge rst)
begin
		if(rst == 1'b1)
			v_active <= 1'd0;
		else if((v_cnt == V_FP + V_SYNC + V_BP - 1) && (h_cnt == H_FP - 1))//垂直有效区开始
			v_active <= 1'b1;
		else if((v_cnt == V_TOTAL - 1) && (h_cnt == H_FP - 1)) //垂直有效区结束
			v_active <= 1'b0;   
		else
			v_active <= v_active;
end


endmodule 