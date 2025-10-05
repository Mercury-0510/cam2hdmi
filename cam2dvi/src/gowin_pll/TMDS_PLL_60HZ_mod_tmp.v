//Copyright (C)2014-2025 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: Template file for instantiation
//Tool Version: V1.9.12 (64-bit)
//Part Number: GW5AST-LV138FPG676AES
//Device: GW5AST-138
//Device Version: B
//Created Time: Sun Oct  5 17:30:44 2025

//Change the instance name and port connections to the signal names
//--------Copy here to design--------

    TMDS_PLL_MOD your_instance_name(
        .lock(lock), //output lock
        .clkout0(clkout0), //output clkout0
        .clkout1(clkout1), //output clkout1
        .clkout2(clkout2), //output clkout2
        .clkin(clkin), //input clkin
        .reset(reset), //input reset
        .icpsel(icpsel), //input [5:0] icpsel
        .lpfres(lpfres), //input [2:0] lpfres
        .lpfcap(lpfcap) //input [1:0] lpfcap
    );

//--------Copy end-------------------
