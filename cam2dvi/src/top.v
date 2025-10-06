module top (
    input                  clk,
	input                  rst_n,
	inout                  cmos_scl,       //cmos i2c clock
	inout                  cmos_sda,       //cmos i2c data
	input                  cmos_vsync,     //cmos vsync
	input                  cmos_href,      //cmos hsync refrence,data valid
	input                  cmos_pclk,      //cmos pxiel clock
    output                 cmos_xclk,      //cmos externl clock 
	input  [7:0]           cmos_db,        //cmos data
	output                 cmos_rst_n,     //cmos reset 
	output                 cmos_pwdn,      //cmos power down
	
	output [4:0]           state_led,

    output [2:0]	       i2c_sel,

	output [16-1:0]        ddr_addr,       //ROW_WIDTH=16
	output [3-1:0]         ddr_bank,       //BANK_WIDTH=3
	output                 ddr_cs,
	output                 ddr_ras,
	output                 ddr_cas,
	output                 ddr_we,
	output                 ddr_ck,
	output                 ddr_ck_n,
	output                 ddr_cke,
	output                 ddr_odt,
	output                 ddr_reset_n,
	output [4-1:0]         ddr_dm,         //DM_WIDTH=4
	inout  [32-1:0]        ddr_dq,         //DQ_WIDTH=32
	inout  [4-1:0]         ddr_dqs,        //DQS_WIDTH=4
	inout  [4-1:0]         ddr_dqs_n,      //DQS_WIDTH=4
  
    output                 tmds_clk_n_0,
    output                 tmds_clk_p_0,
    output [2:0]           tmds_d_n_0, //{r,g,b}
    output [2:0]           tmds_d_p_0
);
    
    parameter ENABLE_WARPING = 1'b0;  // 1=启用畸变校正, 0=旁路模式

    assign i2c_sel = 'b101;

// ==================== 参数定义 ====================
    `define	USE_THREE_FRAME_BUFFER
    `define	DEF_ADDR_WIDTH 29 
    `define	DEF_SRAM_DATA_WIDTH 256
    
    parameter ADDR_WIDTH          = `DEF_ADDR_WIDTH;        //存储单元是byte，总容量=2^29*16bit = 8Gbit,增加1位rank地址，{rank[0],bank[2:0],row[15:0],cloumn[9:0]}
    parameter DATA_WIDTH          = `DEF_SRAM_DATA_WIDTH;   //与生成DDR3IP有关，此ddr3 4Gbit, x32， 时钟比例1:4 ，则固定256bit

    // ==================== 信号定义 ====================
    //memory interface
    wire                   memory_clk         ;
    wire                   dma_clk         	  ;
    wire                   DDR_pll_lock       ;
    wire                   cmd_ready          ;
    wire[2:0]              cmd                ;
    wire                   cmd_en             ;
    wire[ADDR_WIDTH-1:0]   addr               ;
    wire                   wr_data_rdy        ;
    wire                   wr_data_en         ;
    wire                   wr_data_end        ;
    wire[DATA_WIDTH-1:0]   wr_data            ;   
    wire[DATA_WIDTH/8-1:0] wr_data_mask       ;   
    wire                   rd_data_valid      ;  
    wire                   rd_data_end        ; 
    wire[DATA_WIDTH-1:0]   rd_data            ;   
    wire                   init_calib_complete;
    wire                   TMDS_DDR_pll_lock  ;
    wire                   pll_stop           ;

    wire                            video_clk       ;     //video pixel clock (74.25MHz)
    wire                            video_clk_2x    ;  //video clock x2 for warping (148.5MHz)
    
    wire                            syn_off0_vs     ;
    wire                            syn_off0_hs     ;
    wire                            off0_syn_de     ;
    wire[31:0]                      off0_syn_data   ;

    wire[15:0]                      cmos_16bit_data ;
    wire                            cmos_16bit_clk  ;
    wire                            cmos_16bit_wr   ;
    wire[15:0] 						write_data      ;

    wire[9:0]                       lut_index       ;
    wire[31:0]                      lut_data        ;
    wire i2c_done;

    // ==================== CMOS控制信号 ====================
    wire cmos_clk;
    reg cmos_reset;
    reg [31:0] cmos_reset_delay_cnt;
    reg cmos_start_config;

    assign cmos_xclk = cmos_clk;
    assign cmos_pwdn = 1'b0;
    assign cmos_rst_n = cmos_reset;
    assign write_data = cmos_16bit_data;

    reg [4:0] cmos_vs_cnt;
    always@(posedge cmos_vsync) 
        cmos_vs_cnt <= cmos_vs_cnt + 1;


    //状态指示灯
    assign state_led[4] = ~i2c_done;
    assign state_led[3] = ~cmos_vs_cnt[4];
    assign state_led[2] = ~TMDS_DDR_pll_lock;
    assign state_led[1] = ~DDR_pll_lock; 
    assign state_led[0] = ~init_calib_complete; //DDR3初始化指示灯

    // ==================== Video Warping 畸变校正信号 ====================
    // 视频处理流程：Camera -> Frame Buffer -> Video Warping -> HDMI
    // Frame Buffer输出: off0_syn_data[31:0], off0_syn_de, syn_off0_vs, syn_off0_hs  
    // Video Warping: 8位RGB输入输出，需要格式转换
    wire [7:0] warped_r, warped_g, warped_b;       // 8位RGB输出分量
    wire [15:0] warped_data;                       // 转换为RGB565格式
    wire warped_de, warped_vs, warped_hs;
    
    // 8位RGB转换为RGB565格式（R:5bit, G:6bit, B:5bit）
    // 注意：这个warped_data在旁路模式下不使用
    assign warped_data = {warped_r[7:3], warped_g[7:2], warped_b[7:3]};
    
    // HDMI复位信号（需要TMDS PLL锁定）
    wire hdmi4_rst_n;
    assign hdmi4_rst_n = rst_n & TMDS_DDR_pll_lock;
    
    wire [15:0] HActive;
    wire HA_valid;
    wire [15:0] VActive;
    wire VA_valid;
    wire [7:0] fps;
    wire fps_valid;

    timing_check#(
        .REFCLK_FREQ_MHZ(50),
        .IS_2Pclk_1Pixel("true")
    ) timing_check_5640(
        .Refclk(clk),
        .pxl_clk(cmos_pclk),
        .rst_n(rst_n),
        .video_de(cmos_href),
        .video_vsync(cmos_vsync),
        .H_Active(HActive),
        .Ha_updated(HA_valid),
        .V_Active(VActive),
        .va_updated(VA_valid),
        .fps(fps),
        .fps_valid(fps_valid)
    ); 


    //generate the CMOS sensor clock and the SDRAM controller, I2C controller clock
    Gowin_PLL Gowin_PLL_m0(
    	.clkin                     (clk                         ),
    	.clkout0                   (cmos_clk 	              	),
        .clkout0duty               (                            ),
        .clkout2                   (memory_clk 	              	),
    	.lock 					   (DDR_pll_lock 				),
        .reset                     (1'b0                        ),
        .enclk0                    (1'b1                        ), //input enclk0
        .enclk1                    (1'b1                        ), //input enclk1
        .enclk2                    (pll_stop                    ) //input enclk2
	);

    // CMOS复位逻辑）
    always@(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            cmos_reset_delay_cnt <= 0;
            cmos_reset <= 0;
            cmos_start_config <= 0;
        end else begin
            if(cmos_reset_delay_cnt == 32'd50_000_000)  //60ms  32'd3_000_000
            begin
                cmos_reset_delay_cnt <= cmos_reset_delay_cnt;
                cmos_reset <= 1'b1;
                cmos_start_config <= 1'b1;
            end else if(cmos_reset_delay_cnt == 32'd100_000)
            begin
                cmos_reset_delay_cnt <= cmos_reset_delay_cnt + 1;
                cmos_reset <= 1'b1;
                cmos_start_config <= 1'b0;
            end else begin
                cmos_reset_delay_cnt <= cmos_reset_delay_cnt + 1;
                cmos_reset <= cmos_reset;
                cmos_start_config <= cmos_start_config;
            end
            
        end
    end

    //configure look-up table

    lut_ov5640_rgb565 #(
    	.HActive(12'd1280),
    	.VActive(12'd720),
    	.HTotal(13'd1892),
    	.VTotal(13'd740),
        .USE_4vs3_frame("false")
    )lut_ov5640_rgb565_m0(
    	.lut_index(lut_index),
    	.lut_data(lut_data)
    );


    //I2C master controller
    i2c_config i2c_config_m0(
    	.rst                        (~cmos_start_config       ),
    	.clk                        (clk                      ),
    	.clk_div_cnt                (16'd500                  ),
    	.i2c_addr_2byte             (1'b1                     ),
    	.lut_index                  (lut_index                ),
    	.lut_dev_addr               (lut_data[31:24]          ),
    	.lut_reg_addr               (lut_data[23:8]           ),
    	.lut_reg_data               (lut_data[7:0]            ),
    	.error                      (                         ), // i2c_err未使用
    	.done                       (i2c_done                 ),
    	.i2c_scl                    (cmos_scl                 ),
    	.i2c_sda                    (cmos_sda                 )
    );
    

    //CMOS sensor 8bit data is converted to 16bit data
    cmos_8_16bit cmos_8_16bit_m0(
    	.rst                        (~rst_n                   ),
    	.pclk                       (cmos_pclk                ),
    	.pdata_i                    (cmos_db                  ),
    	.de_i                       (cmos_href                ),
    	.pdata_o                    (cmos_16bit_data          ),
    	.hblank                     (cmos_16bit_wr            ),
    	.de_o                       (cmos_16bit_clk           )
    );

    //The video output timing generator and generate a frame read data request
    //输出
    wire out_de;
    wire [11:0] lcd_x,lcd_y;


    // ==================== VGA时序生成模块 ====================
    vga_timing #(
        .H_ACTIVE(16'd1280),                        // 水平有效像素数：1280
        .H_FP(16'd110),                             // 水平前肩时间：110个像素时钟
        .H_SYNC(16'd40),                            // 水平同步脉冲宽度：40个像素时钟
        .H_BP(16'd220),                             // 水平后肩时间：220个像素时钟
        .V_ACTIVE(16'd720),                         // 垂直有效行数：720行
        .V_FP(16'd5),                               // 垂直前肩时间：5行
        .V_SYNC(16'd5),                             // 垂直同步脉冲宽度：5行
        .V_BP(16'd20),                              // 垂直后肩时间：20行
        .HS_POL(1'b1),                              // 水平同步极性：正极性
        .VS_POL(1'b1)                               // 垂直同步极性：正极性
    ) vga_timing_m0(
        // 时钟和复位信号
        .clk (video_clk),                           // 视频像素时钟
        .rst (~hdmi4_rst_n),                        // 复位信号（高有效），使用HDMI PLL锁定信号

        // 像素坐标输出
        .active_x(lcd_x),                           // 当前有效区域X坐标（0-1279）
        .active_y(lcd_y),                           // 当前有效区域Y坐标（0-719）

        // 同步信号输出
        .hs(syn_off0_hs),                           // 水平同步信号输出
        .vs(syn_off0_vs),                           // 垂直同步信号输出
        .de(out_de)                                 // 数据使能信号输出（有效区域标志）
    );

    //CMOS DATA
    
    Video_Frame_Buffer_Top Video_Frame_Buffer_Top_inst
    ( 
        // 复位和时钟信号
        .I_rst_n              (init_calib_complete ),  // 复位信号，DDR3初始化完成后有效
        .I_dma_clk            (dma_clk          ),      // DMA时钟，DDR3控制器输出的用户接口时钟
        
        // 三帧缓存控制（可选功能）
        `ifdef USE_THREE_FRAME_BUFFER 
        .I_wr_halt            (1'd0             ),      // 写入暂停控制：1=暂停，0=正常
        .I_rd_halt            (1'd0             ),      // 读取暂停控制：1=暂停，0=正常
        `endif
        
        // 视频数据输入接口（来自摄像头）
        .I_vin0_clk           (cmos_16bit_clk   ),          // 输入视频时钟（摄像头像素时钟）
        .I_vin0_vs_n          (~cmos_vsync      ),          // 输入垂直同步信号（负极性）
        .I_vin0_de            (cmos_16bit_wr    ),          // 输入数据有效信号
        .I_vin0_data          (write_data       ),          // 输入视频数据（16位RGB565）
        .O_vin0_fifo_full     (                 ),          // 输入FIFO满标志（未连接）
        
        // 视频数据输出接口（给显示模块）
        .I_vout0_clk          (video_clk        ),      // 输出视频时钟（显示像素时钟）
        .I_vout0_vs_n         (~syn_off0_vs     ),      // 输出垂直同步信号（负极性）
        .I_vout0_de           (out_de           ),      // 输出数据使能请求
        .O_vout0_den          (off0_syn_de      ),      // 输出数据有效信号
        .O_vout0_data         (off0_syn_data    ),      // 输出视频数据（16位）
        .O_vout0_fifo_empty   (                 ),      // 输出FIFO空标志（未连接）
        
        // DDR3内存访问接口（连接到DDR3控制器）
        .I_cmd_ready          (cmd_ready          ),    // DDR3命令准备就绪信号
        .O_cmd                (cmd                ),    // DDR3命令：0=写入，1=读取
        .O_cmd_en             (cmd_en             ),    // DDR3命令使能信号
        .O_addr               (addr               ),    // DDR3地址总线[ADDR_WIDTH-1:0]
        .I_wr_data_rdy        (wr_data_rdy        ),    // DDR3写数据准备就绪信号
        .O_wr_data_en         (wr_data_en         ),    // DDR3写数据使能信号
        .O_wr_data_end        (wr_data_end        ),    // DDR3写数据结束信号
        .O_wr_data            (wr_data            ),    // DDR3写数据总线（256位）
        .O_wr_data_mask       (wr_data_mask       ),    // DDR3写数据掩码（32位）
        .I_rd_data_valid      (rd_data_valid      ),    // DDR3读数据有效信号
        .I_rd_data_end        (rd_data_end        ),    // DDR3读数据结束信号
        .I_rd_data            (rd_data            ),    // DDR3读数据总线（256位）
        .I_init_calib_complete(init_calib_complete)     // DDR3初始化校准完成信号
    ); 

    DDR3MI u_ddr3 
    (
        // 系统时钟和复位信号
        .clk                (clk                ),      // 系统主时钟（50MHz）
        .memory_clk         (memory_clk         ),      // DDR3内存时钟（400MHz）
        .pll_stop           (pll_stop           ),      // PLL停止控制信号
        .pll_lock           (DDR_pll_lock       ),      // PLL锁定状态信号
        .rst_n              (rst_n              ),      // 系统复位信号（低有效）
        
        // DDR3用户接口 - 命令通道
        .cmd_ready          (cmd_ready          ),      // 命令准备就绪信号
        .cmd                (cmd                ),      // 命令类型：读/写/刷新等
        .cmd_en             (cmd_en             ),      // 命令使能信号
        .addr               (addr               ),      // 29位地址总线
        
        // DDR3用户接口 - 写数据通道
        .wr_data_rdy        (wr_data_rdy        ),      // 写数据准备就绪信号
        .wr_data            (wr_data            ),      // 256位写数据总线
        .wr_data_en         (wr_data_en         ),      // 写数据使能信号
        .wr_data_end        (wr_data_end        ),      // 写数据结束信号
        .wr_data_mask       (wr_data_mask       ),      // 32位写数据掩码
        
        // DDR3用户接口 - 读数据通道
        .rd_data            (rd_data            ),      // 256位读数据总线
        .rd_data_valid      (rd_data_valid      ),      // 读数据有效信号
        .rd_data_end        (rd_data_end        ),      // 读数据结束信号
        
        // DDR3控制接口
        .sr_req             (1'b0               ),      // 自刷新请求（未使用）
        .ref_req            (1'b0               ),      // 刷新请求（未使用）
        .sr_ack             (                   ),      // 自刷新确认（未连接）
        .ref_ack            (                   ),      // 刷新确认（未连接）
        .init_calib_complete(init_calib_complete),      // 初始化校准完成信号
        .clk_out            (dma_clk            ),      // 用户接口时钟输出（DMA时钟）
        .burst              (1'b1               ),      // 突发模式使能
        
        // DDR3物理接口（连接到外部DDR3芯片）
        .ddr_rst            (                 ),        // DDR3复位输出（未连接）
        .O_ddr_addr         (ddr_addr         ),        // DDR3地址总线（16位）
        .O_ddr_ba           (ddr_bank         ),        // DDR3 Bank地址（3位）
        .O_ddr_cs_n         (ddr_cs           ),        // DDR3片选信号（低有效）
        .O_ddr_ras_n        (ddr_ras          ),        // DDR3行地址选通（低有效）
        .O_ddr_cas_n        (ddr_cas          ),        // DDR3列地址选通（低有效）
        .O_ddr_we_n         (ddr_we           ),        // DDR3写使能（低有效）
        .O_ddr_clk          (ddr_ck           ),        // DDR3差分时钟正端
        .O_ddr_clk_n        (ddr_ck_n         ),        // DDR3差分时钟负端
        .O_ddr_cke          (ddr_cke          ),        // DDR3时钟使能
        .O_ddr_odt          (ddr_odt          ),        // DDR3片上终端阻抗
        .O_ddr_reset_n      (ddr_reset_n      ),        // DDR3复位信号（低有效）
        .O_ddr_dqm          (ddr_dm           ),        // DDR3数据掩码（4位）
        .IO_ddr_dq          (ddr_dq           ),        // DDR3数据总线（32位双向）
        .IO_ddr_dqs         (ddr_dqs          ),        // DDR3数据选通（4位双向）
        .IO_ddr_dqs_n       (ddr_dqs_n        )         // DDR3数据选通负端（4位双向）
    );

    //==============================================================================
    // Video Warping IP - 畸变校正模块（按照Gowin IP信号表）
    // 使用Gowin Video Warping IP核
    // 信号映射说明:
    // - clk: 像素时钟（74.25MHz for 720p@60Hz）
    // - clk_2: 计算时钟，为像素时钟的2倍（148.5MHz），从TMDS_PLL的clkout2输出
    // - Hsync_in: 实际上是数据有效信号（DE），不是行同步
    // - RGB输入输出都是8位，需要与RGB565格式进行转换
    //   输入：RGB565 -> 8位RGB（低位补0）
    //   输出：8位RGB -> RGB565（取高位）
    Video_Warping_Top u_video_warping (
        // 时钟和复位
        .clk                (video_clk        ),      // 输入时钟信号，作为像素时钟 (74.25MHz)
        .clk_2              (video_clk_2x     ),      // 输入时钟信号，作为计算时钟，为像素时钟的2倍 (148.5MHz)
        .rstn               (hdmi4_rst_n      ),      // 复位信号，低电平有效，使用HDMI PLL锁定信号
        
        // 输入视频流（RGB565转8位RGB）
        .Vsync_in           (syn_off0_vs      ),      // 输入场同步信号
        .Hsync_in           (off0_syn_de      ),      // 输入图像数据有效信号（对应DE信号）
        .R_din              ({off0_syn_data[15:11], 3'b000}), // R分量：5位扩展到8位
        .G_din              ({off0_syn_data[10:5], 2'b00}),   // G分量：6位扩展到8位  
        .B_din              ({off0_syn_data[4:0], 3'b000}),   // B分量：5位扩展到8位
        
        // 写信号和地址（用于配置多项式系数）
        .wr                 (1'b0            ),       // 写信号（暂时不写入配置）
        .waddr              (16'h0           ),       // 写地址信号
        .wdata              (32'h0           ),       // 写数据信号
        
        // 输出视频流  
        .Vsync_out          (warped_vs       ),       // 输出场同步信号
        .Hsync_out          (warped_hs       ),       // 输出行同步信号
        .DE_out             (warped_de       ),       // 输出有效信号，高电平时表示此时输出信号为有效位
        .R_dout             (warped_r        ),       // 输出图像数据信号 - R分量（5位）
        .G_dout             (warped_g        ),       // 输出图像数据信号 - G分量（6位）
        .B_dout             (warped_b        )        // 输出图像数据信号 - B分量（5位）
    );

    //==============================================================================
    //TMDS TX(HDMI4)
    wire serial_clk;

    TMDS_PLL u_tmds_pll(
        .clkin     (clk              ),
        .clkout0   (serial_clk       ),  // 371.25MHz (5x pixel clock for TMDS)
        .clkout1   (video_clk        ),  // 74.25MHz (pixel clock for 720p@60Hz)
        .clkout2   (video_clk_2x     ),  // 148.5MHz (2x pixel clock for warping)
        .lock      (TMDS_DDR_pll_lock)
        );

    wire dvi0_rgb_clk;
    wire dvi0_rgb_vs ;
    wire dvi0_rgb_hs ;
    wire dvi0_rgb_de ;
    wire [7:0] dvi0_rgb_r  ;
    wire [7:0] dvi0_rgb_g  ;
    wire [7:0] dvi0_rgb_b  ;

    assign dvi0_rgb_clk = video_clk;
    
    // 选择是否启用Video Warping（根据ENABLE_WARPING参数）
    assign dvi0_rgb_vs  = ENABLE_WARPING ? warped_vs : syn_off0_vs;
    assign dvi0_rgb_hs  = ENABLE_WARPING ? warped_hs : syn_off0_hs;
    assign dvi0_rgb_de  = ENABLE_WARPING ? warped_de : off0_syn_de;
    
    // Video Warping输出已经是8位RGB，直接使用
    // 旁路模式时从帧缓存输出的RGB565转换为8位RGB
    assign dvi0_rgb_r   = ENABLE_WARPING ? warped_r : {off0_syn_data[15:11], 3'd0};
    assign dvi0_rgb_g   = ENABLE_WARPING ? warped_g : {off0_syn_data[10:5], 2'd0};
    assign dvi0_rgb_b   = ENABLE_WARPING ? warped_b : {off0_syn_data[4:0], 3'd0};

    DVI_TX_Top DVI_TX_Top_inst0
    (
        .I_rst_n       (hdmi4_rst_n   ),
        .I_serial_clk  (serial_clk    ),
        .I_rgb_clk     (dvi0_rgb_clk),
        .I_rgb_vs      (dvi0_rgb_vs ),    
        .I_rgb_hs      (dvi0_rgb_hs ),    
        .I_rgb_de      (dvi0_rgb_de ), 
        .I_rgb_r       (dvi0_rgb_r  ), 
        .I_rgb_g       (dvi0_rgb_g  ),  
        .I_rgb_b       (dvi0_rgb_b  ),  

        .O_tmds_clk_p  (tmds_clk_p_0  ),
        .O_tmds_clk_n  (tmds_clk_n_0  ),
        .O_tmds_data_p (tmds_d_p_0    ),
        .O_tmds_data_n (tmds_d_n_0    )
    );

endmodule