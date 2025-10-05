//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Part Number: GW5AST-LV138FPG676AES
//Device: GW5AST-138
//Device Version: B


//Change the instance name and port connections to the signal names
//--------Copy here to design--------
    TMDS_PLL your_instance_name(
        .clkin(clkin), //input  clkin
        .init_clk(init_clk), //input  init_clk
        .clkout0(clkout0), //output  clkout0
        .clkout1(clkout1), //output  clkout1
        .clkout2(clkout2), //output  clkout2
        .lock(lock) //output  lock
);


//--------Copy end-------------------
