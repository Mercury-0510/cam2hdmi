//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12 (64-bit)
//Part Number: GW5AST-LV138FPG676AC1/I0
//Device: GW5AST-138
//Device Version: B
//Created Time: Wed Oct  8 19:50:08 2025

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

	Video_Warping_Top your_instance_name(
		.clk(clk), //input clk
		.clk_2(clk_2), //input clk_2
		.rstn(rstn), //input rstn
		.Vsync_in(Vsync_in), //input Vsync_in
		.Hsync_in(Hsync_in), //input Hsync_in
		.R_din(R_din), //input [7:0] R_din
		.G_din(G_din), //input [7:0] G_din
		.B_din(B_din), //input [7:0] B_din
		.wr(wr), //input wr
		.waddr(waddr), //input [15:0] waddr
		.wdata(wdata), //input [31:0] wdata
		.Vsync_out(Vsync_out), //output Vsync_out
		.Hsync_out(Hsync_out), //output Hsync_out
		.DE_out(DE_out), //output DE_out
		.R_dout(R_dout), //output [7:0] R_dout
		.G_dout(G_dout), //output [7:0] G_dout
		.B_dout(B_dout) //output [7:0] B_dout
	);

//--------Copy end-------------------
