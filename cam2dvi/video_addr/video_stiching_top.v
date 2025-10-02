module video_stiching_top#(
    //======================== HDMI 时序参数 ========================
      parameter  H_SYNC   = 12'd40
    , parameter  H_BACK   = 12'd220
    , parameter  H_DISP   = 12'd1280
    , parameter  H_FRONT  = 12'd110
    , parameter  H_TOTAL  = H_SYNC + H_BACK + H_DISP + H_FRONT
    , parameter  V_SYNC   = 12'd5
    , parameter  V_BACK   = 12'd20
    , parameter  V_DISP   = 12'd720
    , parameter  V_FRONT  = 12'd5
    , parameter  V_TOTAL  = V_SYNC + V_BACK + V_DISP + V_FRONT

    //======================== 基本分辨率（每路） ====================
    , parameter  Cmos0_H  = H_DISP
    , parameter  Cmos0_V  = V_DISP

    //======================== FIFO/AXI 参数 ========================
    , parameter FIFO_AW           = 10
    , parameter AXI4_DATA_WIDTH   = 128

    // AXI Master
    , parameter C_M_TARGET_SLAVE_BASE_ADDR = 32'h0000_0000
    , parameter integer C_M_AXI_BURST_LEN  = 16
    , parameter integer C_M_AXI_ID_WIDTH   = 1
    , parameter integer C_M_AXI_ADDR_WIDTH = 32
    , parameter integer C_M_AXI_DATA_WIDTH = AXI4_DATA_WIDTH
    , parameter integer C_M_AXI_AWUSER_WIDTH = 0
    , parameter integer C_M_AXI_ARUSER_WIDTH = 0
    , parameter integer C_M_AXI_WUSER_WIDTH  = 0
    , parameter integer C_M_AXI_RUSER_WIDTH  = 0
    , parameter integer C_M_AXI_BUSER_WIDTH  = 0
)(
    //======================== 三路 CMOS 口 =========================
      input         cmos0_clk
    , input         cmos0_vsync
    , input         cmos0_href
    , input         cmos0_clken
    , input  [23:0] cmos0_data

    , input         cmos1_clk
    , input         cmos1_vsync
    , input         cmos1_href
    , input         cmos1_clken
    , input  [23:0] cmos1_data

    , input         cmos2_clk
    , input         cmos2_vsync
    , input         cmos2_href
    , input         cmos2_clken
    , input  [23:0] cmos2_data

    //======================== Video 输出口 =========================
    , input         video_clk
    , output        video_vsync
    , output        video_href
    , output        video_de
    , output [23:0] video_data

    //======================== DDR3 Native 口 ======================
    , input         ref_clk
    , input         sys_rst_n
    , output        init_calib_complete
    , input         c0_sys_clk
    , input         c0_sys_clk_locked
    , output [14:0] ddr_addr
    , output [2:0]  ddr_bank
    , output        ddr_cs
    , output        ddr_ras
    , output        ddr_cas
    , output        ddr_we
    , output        ddr_ck
    , output        ddr_ck_n
    , output        ddr_cke
    , output        ddr_odt
    , output        ddr_reset_n
    , output [3:0]  ddr_dm
    , inout  [31:0] ddr_dq
    , inout  [3:0]  ddr_dqs
    , inout  [3:0]  ddr_dqs_n
);

    //======================== AXI Master 总线 ======================
    wire [C_M_AXI_ID_WIDTH-1:0]   M_AXI_AWID;
    wire [C_M_AXI_ADDR_WIDTH-1:0] M_AXI_AWADDR;
    wire [7:0]                    M_AXI_AWLEN;
    wire [2:0]                    M_AXI_AWSIZE;
    wire [1:0]                    M_AXI_AWBURST;
    wire                          M_AXI_AWLOCK;
    wire [3:0]                    M_AXI_AWCACHE;
    wire [2:0]                    M_AXI_AWPROT;
    wire [3:0]                    M_AXI_AWQOS;
    wire [C_M_AXI_AWUSER_WIDTH-1:0] M_AXI_AWUSER;
    wire                          M_AXI_AWVALID;
    wire                          M_AXI_AWREADY;
    wire [C_M_AXI_DATA_WIDTH-1:0] M_AXI_WDATA;
    wire [C_M_AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB;
    wire                          M_AXI_WLAST;
    wire [C_M_AXI_WUSER_WIDTH-1:0] M_AXI_WUSER;
    wire                          M_AXI_WVALID;
    wire                          M_AXI_WREADY;
    wire [C_M_AXI_ID_WIDTH-1:0]   M_AXI_BID;
    wire [1:0]                    M_AXI_BRESP;
    wire [C_M_AXI_BUSER_WIDTH-1:0] M_AXI_BUSER;
    wire                          M_AXI_BVALID;
    wire                          M_AXI_BREADY;
    wire [C_M_AXI_ID_WIDTH-1:0]   M_AXI_ARID;
    wire [C_M_AXI_ADDR_WIDTH-1:0] M_AXI_ARADDR;
    wire [7:0]                    M_AXI_ARLEN;
    wire [2:0]                    M_AXI_ARSIZE;
    wire [1:0]                    M_AXI_ARBURST;
    wire                          M_AXI_ARLOCK;
    wire [3:0]                    M_AXI_ARCACHE;
    wire [2:0]                    M_AXI_ARPROT;
    wire [3:0]                    M_AXI_ARQOS;
    wire [C_M_AXI_ARUSER_WIDTH-1:0] M_AXI_ARUSER;
    wire                          M_AXI_ARVALID;
    wire                          M_AXI_ARREADY;
    wire [C_M_AXI_ID_WIDTH-1:0]   M_AXI_RID;
    wire [C_M_AXI_DATA_WIDTH-1:0] M_AXI_RDATA;
    wire [1:0]                    M_AXI_RRESP;
    wire                          M_AXI_RLAST;
    wire [C_M_AXI_RUSER_WIDTH-1:0] M_AXI_RUSER;
    wire                          M_AXI_RVALID;
    wire                          M_AXI_RREADY;

    //======================== DDR3 Native 应用口 ===================
    localparam nCK_PER_CLK      = 4;
    localparam ADDR_WIDTH_N     = 28;                 // ← 以 DDR3 IP 实际端口为准
    localparam MEM_IF_ADDR_BITS = 29;                 // = `DEF_ADDR_WIDTH
    localparam PAYLOAD_WIDTH    = 32;                 // x32 DQ（由 IP 配置决定）
    localparam APP_DATA_WIDTH   = 2 * nCK_PER_CLK * PAYLOAD_WIDTH; // 256-bit
    localparam APP_MASK_WIDTH   = APP_DATA_WIDTH/8;   // 32

    wire                        app_clk, app_rst;
    wire [MEM_IF_ADDR_BITS-1:0] app_addr;
    wire [2:0]                  app_cmd;
    wire                        app_en, app_rdy;
    wire [APP_DATA_WIDTH-1:0]   app_rd_data;
    wire                        app_rd_data_end, app_rd_data_valid;
    wire [APP_DATA_WIDTH-1:0]   app_wdf_data;
    wire                        app_wdf_end;
    wire [APP_MASK_WIDTH-1:0]   app_wdf_mask;
    wire                        app_wdf_rdy, app_wdf_wren;

    //======================== 复位/时钟域 ==========================
    wire rst_n;
    assign M_AXI_ACLK    = app_clk;
    assign M_AXI_ARESETN = !(app_rst | (!init_calib_complete));
    assign rst_n         = M_AXI_ARESETN;

    //======================== 3 路 CMOS 打包 =======================
    wire        cmos_clk   [0:2];
    wire        cmos_vsync [0:2];
    wire        cmos_href  [0:2];
    wire        cmos_clken [0:2];
    wire [23:0] cmos_data  [0:2];

    assign cmos_clk[0]   = cmos0_clk;   assign cmos_vsync[0] = cmos0_vsync;
    assign cmos_href[0]  = cmos0_href;  assign cmos_clken[0] = cmos0_clken;
    assign cmos_data[0]  = cmos0_data;

    assign cmos_clk[1]   = cmos1_clk;   assign cmos_vsync[1] = cmos1_vsync;
    assign cmos_href[1]  = cmos1_href;  assign cmos_clken[1] = cmos1_clken;
    assign cmos_data[1]  = cmos1_data;

    assign cmos_clk[2]   = cmos2_clk;   assign cmos_vsync[2] = cmos2_vsync;
    assign cmos_href[2]  = cmos2_href;  assign cmos_clken[2] = cmos2_clken;
    assign cmos_data[2]  = cmos2_data;

    //======================== 写入端：视频→FIFO ====================
    wire                          cmos_burst_valid [0:2];
    wire                          cmos_burst_ready [0:2];
    wire                          cmos_fifo_wr_enable [0:2];
    wire [AXI4_DATA_WIDTH-1:0]    cmos_fifo_wr_data_out [0:2];
    wire                          cmos_fifo_rd_enable [0:2];
    wire [AXI4_DATA_WIDTH-1:0]    cmos_fifo_rd_data_out [0:2];

    generate
        for (genvar i=0;i<3;i=i+1) begin : G_V2F
            video_to_fifo_ctrl u_cmos_to_fifo_ctrl(
                .video_rst_n          (rst_n),
                .video_clk            (cmos_clk[i]),
                .video_vs_out         (cmos_vsync[i]),
                .video_hs_out         (cmos_href[i]),
                .video_de_out         (cmos_clken[i]),
                .video_data_out       (cmos_data[i]),
                .M_AXI_ACLK           (M_AXI_ACLK),
                .M_AXI_ARESETN        (M_AXI_ARESETN),
                .fifo_enable          (cmos_fifo_wr_enable[i]),
                .fifo_data_out        (cmos_fifo_wr_data_out[i]),
                .AXI_FULL_BURST_VALID (cmos_burst_valid[i]),
                .AXI_FULL_BURST_READY (cmos_burst_ready[i])
            );

            FIFO_HS_Top_axi u_async_forward_fifo(
                .Data     (cmos_fifo_wr_data_out[i]),
                .WrReset  (!cmos_vsync[i] | !M_AXI_ARESETN),
                .RdReset  (!cmos_vsync[i] | !M_AXI_ARESETN),
                .WrClk    (cmos_clk[i]),
                .RdClk    (M_AXI_ACLK),
                .WrEn     (cmos_fifo_wr_enable[i]),
                .RdEn     (cmos_fifo_rd_enable[i]),
                .Q        (cmos_fifo_rd_data_out[i]),
                .Empty    (),
                .Full     ()
            );
        end
    endgenerate

    //======================== 读端：DDR→视频 ======================
    wire                        video_burst_valid, video_burst_ready;
    wire                        video_fifo_wr_enable;
    wire [AXI4_DATA_WIDTH-1:0]  video_fifo_wr_data_out;
    wire                        video_fifo_rd_enable, video_fifo_rst_n;
    wire [AXI4_DATA_WIDTH-1:0]  video_fifo_rd_data_out;
    wire                        backward_fifo_empty, backward_fifo_full;

    //======================== AXI master（写三路，读一路） ========
    // --- 方案A：你已有的 5 路 axi_full_core.v 改为 3 路版本（推荐） ---
    //    端口只留 cmos0..2，对应地址映射也修改为三段；
    //    这样本顶层更干净。
    //
    // --- 方案B：继续复用 5 路 axi_full_core（快速） ---
    //    把 cmos3/4 相关端口绑到常 0，burst_valid=0，vsync=0，din无所谓。
    //    我在这里先给“方案B”的连接，便于你直接跑起来。
    wire [AXI4_DATA_WIDTH-1:0] dummy_zero = {AXI4_DATA_WIDTH{1'b0}};
    wire                       dummy0 = 1'b0;

    axi_full_core #(
        .FDW                      (AXI4_DATA_WIDTH),
        .FAW                      (FIFO_AW),
        .C_M_TARGET_SLAVE_BASE_ADDR(C_M_TARGET_SLAVE_BASE_ADDR),
        .C_M_AXI_BURST_LEN        (C_M_AXI_BURST_LEN),
        .C_M_AXI_ID_WIDTH         (C_M_AXI_ID_WIDTH),
        .C_M_AXI_ADDR_WIDTH       (C_M_AXI_ADDR_WIDTH),
        .C_M_AXI_DATA_WIDTH       (C_M_AXI_DATA_WIDTH),
        .C_M_AXI_AWUSER_WIDTH     (C_M_AXI_AWUSER_WIDTH),
        .C_M_AXI_ARUSER_WIDTH     (C_M_AXI_ARUSER_WIDTH),
        .C_M_AXI_WUSER_WIDTH      (C_M_AXI_WUSER_WIDTH),
        .C_M_AXI_RUSER_WIDTH      (C_M_AXI_RUSER_WIDTH),
        .C_M_AXI_BUSER_WIDTH      (C_M_AXI_BUSER_WIDTH)
    ) u_axi_full_core (
        // three valid CMOS read-sides
        .cmos0_frd_rdy  (cmos_fifo_rd_enable[0]),
        .cmos0_frd_vld  (),
        .cmos0_frd_din  (cmos_fifo_rd_data_out[0]),
        .cmos0_frd_empty(),
        .cmos0_frd_cnt  (),

        .cmos1_frd_rdy  (cmos_fifo_rd_enable[1]),
        .cmos1_frd_vld  (),
        .cmos1_frd_din  (cmos_fifo_rd_data_out[1]),
        .cmos1_frd_empty(),
        .cmos1_frd_cnt  (),

        .cmos2_frd_rdy  (cmos_fifo_rd_enable[2]),
        .cmos2_frd_vld  (),
        .cmos2_frd_din  (cmos_fifo_rd_data_out[2]),
        .cmos2_frd_empty(),
        .cmos2_frd_cnt  (),

        // tie-off camera#3/#4
        .cmos3_frd_rdy  (),
        .cmos3_frd_vld  (1'b0),
        .cmos3_frd_din  (dummy_zero),
        .cmos3_frd_empty(1'b1),
        .cmos3_frd_cnt  (),

        .cmos4_frd_rdy  (),
        .cmos4_frd_vld  (1'b0),
        .cmos4_frd_din  (dummy_zero),
        .cmos4_frd_empty(1'b1),
        .cmos4_frd_cnt  (),

        // video write-backward fifo
        .video_bwr_rdy  (),
        .video_bwr_vld  (video_fifo_wr_enable),
        .video_bwr_din  (video_fifo_wr_data_out),
        .video_bwr_empty(),
        .video_bwr_cnt  (),

        // burst handshake (three active + two disabled)
        .cmos0_burst_valid (cmos_burst_valid[0]),
        .cmos0_burst_ready (cmos_burst_ready[0]),
        .cmos1_burst_valid (cmos_burst_valid[1]),
        .cmos1_burst_ready (cmos_burst_ready[1]),
        .cmos2_burst_valid (cmos_burst_valid[2]),
        .cmos2_burst_ready (cmos_burst_ready[2]),
        .cmos3_burst_valid (1'b0),
        .cmos3_burst_ready (),
        .cmos4_burst_valid (1'b0),
        .cmos4_burst_ready (),

        .video_burst_valid (video_burst_valid),
        .video_burst_ready (video_burst_ready),

        .cmos0_vsync (cmos_vsync[0]),
        .cmos1_vsync (cmos_vsync[1]),
        .cmos2_vsync (cmos_vsync[2]),
        .cmos3_vsync (1'b0),
        .cmos4_vsync (1'b0),

        .video_vsync (video_vsync),

        .INIT_AXI_TXN (), .TXN_DONE(), .ERROR(),
        .M_AXI_ACLK (M_AXI_ACLK),
        .M_AXI_ARESETN (M_AXI_ARESETN),

        .M_AXI_AWID   (M_AXI_AWID),
        .M_AXI_AWADDR (M_AXI_AWADDR),
        .M_AXI_AWLEN  (M_AXI_AWLEN),
        .M_AXI_AWSIZE (M_AXI_AWSIZE),
        .M_AXI_AWBURST(M_AXI_AWBURST),
        .M_AXI_AWLOCK (M_AXI_AWLOCK),
        .M_AXI_AWCACHE(M_AXI_AWCACHE),
        .M_AXI_AWPROT (M_AXI_AWPROT),
        .M_AXI_AWQOS  (M_AXI_AWQOS),
        .M_AXI_AWUSER (M_AXI_AWUSER),
        .M_AXI_AWVALID(M_AXI_AWVALID),
        .M_AXI_AWREADY(M_AXI_AWREADY),

        .M_AXI_WDATA (M_AXI_WDATA),
        .M_AXI_WSTRB (M_AXI_WSTRB),
        .M_AXI_WLAST (M_AXI_WLAST),
        .M_AXI_WUSER (M_AXI_WUSER),
        .M_AXI_WVALID(M_AXI_WVALID),
        .M_AXI_WREADY(M_AXI_WREADY),

        .M_AXI_BID   (M_AXI_BID),
        .M_AXI_BRESP (M_AXI_BRESP),
        .M_AXI_BUSER (M_AXI_BUSER),
        .M_AXI_BVALID(M_AXI_BVALID),
        .M_AXI_BREADY(M_AXI_BREADY),

        .M_AXI_ARID   (M_AXI_ARID),
        .M_AXI_ARADDR (M_AXI_ARADDR),
        .M_AXI_ARLEN  (M_AXI_ARLEN),
        .M_AXI_ARSIZE (M_AXI_ARSIZE),
        .M_AXI_ARBURST(M_AXI_ARBURST),
        .M_AXI_ARLOCK (M_AXI_ARLOCK),
        .M_AXI_ARCACHE(M_AXI_ARCACHE),
        .M_AXI_ARPROT (M_AXI_ARPROT),
        .M_AXI_ARQOS  (M_AXI_ARQOS),
        .M_AXI_ARUSER (M_AXI_ARUSER),
        .M_AXI_ARVALID(M_AXI_ARVALID),
        .M_AXI_ARREADY(M_AXI_ARREADY),

        .M_AXI_RID   (M_AXI_RID),
        .M_AXI_RDATA (M_AXI_RDATA),
        .M_AXI_RRESP (M_AXI_RRESP),
        .M_AXI_RLAST (M_AXI_RLAST),
        .M_AXI_RUSER (M_AXI_RUSER),
        .M_AXI_RVALID(M_AXI_RVALID),
        .M_AXI_RREADY(M_AXI_RREADY)
    );

    //======================== DDR→video 异步 FIFO ==================
    FIFO_HS_Top_axi u_async_backward_fifo(
        .Data    (video_fifo_wr_data_out),
        .WrReset (!video_fifo_rst_n | !M_AXI_ARESETN),
        .RdReset (!video_fifo_rst_n | !M_AXI_ARESETN),
        .WrClk   (M_AXI_ACLK),
        .RdClk   (video_clk),
        .WrEn    (video_fifo_wr_enable),
        .RdEn    (video_fifo_rd_enable),
        .Q       (video_fifo_rd_data_out),
        .Empty   (backward_fifo_empty),
        .Full    (backward_fifo_full),
        .Almost_Empty(), //output Almost_Empty
        .Almost_Full() //output Almost_Full
    );


    //======================== 出口：拼接控制 =======================
    fifo_to_video_ctrl #(
          .H_SYNC (H_SYNC), .H_BACK(H_BACK), .H_DISP(H_DISP), .H_FRONT(H_FRONT), .H_TOTAL(H_TOTAL)
        , .V_SYNC (V_SYNC), .V_BACK(V_BACK), .V_DISP(V_DISP), .V_FRONT(V_FRONT), .V_TOTAL(V_TOTAL)
        , .AXI4_DATA_WIDTH(AXI4_DATA_WIDTH)
    ) u_fifo_to_video_ctrl(
          .video_clk     (video_clk)
        , .video_rst_n   (rst_n)
        , .M_AXI_ACLK    (M_AXI_ACLK)
        , .M_AXI_ARESETN (M_AXI_ARESETN)
        , .video_vs_out  (video_vsync)
        , .video_hs_out  (video_href)
        , .video_de_out  (video_de)
        , .video_data_out(video_data)
        , .fifo_data_in  (video_fifo_rd_data_out)
        , .fifo_enable   (video_fifo_rd_enable)
        , .fifo_rst_n    (video_fifo_rst_n)
        , .AXI_FULL_BURST_VALID(video_burst_valid)
        , .AXI_FULL_BURST_READY(video_burst_ready)
    );

    //======================== DDR3 控制器实例 ======================
    DDR3MI DDR3_Memory_Interface_Top_inst (
        .O_ddr_addr (ddr_addr), 
        .O_ddr_ba(ddr_bank), 
        .O_ddr_cs_n(ddr_cs),
        .O_ddr_ras_n(ddr_ras), 
        .O_ddr_cas_n(ddr_cas), 
        .O_ddr_we_n(ddr_we),
        .O_ddr_clk  (ddr_ck), 
        .O_ddr_clk_n(ddr_ck_n), 
        .O_ddr_cke(ddr_cke),
        .O_ddr_odt  (ddr_odt), 
        .O_ddr_reset_n(ddr_reset_n),
        .O_ddr_dqm  (ddr_dm), 
        .IO_ddr_dq(ddr_dq), 
        .IO_ddr_dqs(ddr_dqs), 
        .IO_ddr_dqs_n(ddr_dqs_n),

        .clk(ref_clk), 
        .memory_clk(c0_sys_clk), 
        .pll_lock(c0_sys_clk_locked),
        .rst_n(sys_rst_n),
        .cmd_ready(app_rdy), 
        .cmd(app_cmd), 
        .cmd_en(app_en), 
        .addr(app_addr),
        .wr_data_rdy(app_wdf_rdy), 
        .wr_data(app_wdf_data), 
        .wr_data_en(app_wdf_wren),
        .wr_data_end(app_wdf_end), 
        .wr_data_mask(app_wdf_mask),
        .rd_data(app_rd_data), 
        .rd_data_valid(app_rd_data_valid), 
        .rd_data_end(app_rd_data_end),
        .sr_req(1'b0), 
        .ref_req(1'b0), 
        .sr_ack(), 
        .ref_ack(),
        .init_calib_complete(init_calib_complete),
        .clk_out(app_clk), 
        .burst(1'b1),
        .ddr_rst()
    );

    axi_native_transition #(
          .MEM_DATA_BITS      (APP_DATA_WIDTH)
        , .MEM_IF_ADDR_BITS   (MEM_IF_ADDR_BITS)
        , .ADDR_BITS          (ADDR_WIDTH_N)
        , .C_S_AXI_ID_WIDTH   (C_M_AXI_ID_WIDTH)
        , .C_S_AXI_ADDR_WIDTH (C_M_AXI_ADDR_WIDTH)
        , .C_S_AXI_DATA_WIDTH (AXI4_DATA_WIDTH)
        , .C_S_AXI_AWUSER_WIDTH(C_M_AXI_AWUSER_WIDTH)
        , .C_S_AXI_ARUSER_WIDTH(C_M_AXI_ARUSER_WIDTH)
        , .C_S_AXI_WUSER_WIDTH (C_M_AXI_WUSER_WIDTH)
        , .C_S_AXI_RUSER_WIDTH (C_M_AXI_RUSER_WIDTH)
        , .C_S_AXI_BUSER_WIDTH (C_M_AXI_BUSER_WIDTH)
    ) u_axi_native_transition (
        .app_clk(app_clk),
        .app_rst(app_rst | (!init_calib_complete)),
        .app_addr(app_addr),
        .app_cmd(app_cmd),
        .app_en(app_en),
        .app_rdy(app_rdy),
        .app_rd_data(app_rd_data),
        .app_rd_data_end(app_rd_data_end),
        .app_rd_data_valid(app_rd_data_valid),
        .app_wdf_data(app_wdf_data),
        .app_wdf_end(app_wdf_end),
        .app_wdf_mask(app_wdf_mask),
        .app_wdf_rdy(app_wdf_rdy),
        .app_wdf_wren(app_wdf_wren),

        .S_AXI_ACLK   (M_AXI_ACLK),
        .S_AXI_ARESETN(M_AXI_ARESETN),

        .S_AXI_AWID   (M_AXI_AWID),
        .S_AXI_AWADDR (M_AXI_AWADDR),
        .S_AXI_AWLEN  (M_AXI_AWLEN),
        .S_AXI_AWSIZE (M_AXI_AWSIZE),
        .S_AXI_AWBURST(M_AXI_AWBURST),
        .S_AXI_AWLOCK (M_AXI_AWLOCK),
        .S_AXI_AWCACHE(M_AXI_AWCACHE),
        .S_AXI_AWPROT (M_AXI_AWPROT),
        .S_AXI_AWQOS  (M_AXI_AWQOS),
        .S_AXI_AWREGION(),
        .S_AXI_AWUSER (M_AXI_AWUSER),
        .S_AXI_AWVALID(M_AXI_AWVALID),
        .S_AXI_AWREADY(M_AXI_AWREADY),

        .S_AXI_WDATA  (M_AXI_WDATA),
        .S_AXI_WSTRB  (M_AXI_WSTRB),
        .S_AXI_WLAST  (M_AXI_WLAST),
        .S_AXI_WUSER  (M_AXI_WUSER),
        .S_AXI_WVALID (M_AXI_WVALID),
        .S_AXI_WREADY (M_AXI_WREADY),

        .S_AXI_BID    (M_AXI_BID),
        .S_AXI_BRESP  (M_AXI_BRESP),
        .S_AXI_BUSER  (M_AXI_BUSER),
        .S_AXI_BVALID (M_AXI_BVALID),
        .S_AXI_BREADY (M_AXI_BREADY),

        .S_AXI_ARID   (M_AXI_ARID),
        .S_AXI_ARADDR (M_AXI_ARADDR),
        .S_AXI_ARLEN  (M_AXI_ARLEN),
        .S_AXI_ARSIZE (M_AXI_ARSIZE),
        .S_AXI_ARBURST(M_AXI_ARBURST),
        .S_AXI_ARLOCK (M_AXI_ARLOCK),
        .S_AXI_ARCACHE(M_AXI_ARCACHE),
        .S_AXI_ARPROT (M_AXI_ARPROT),
        .S_AXI_ARQOS  (M_AXI_ARQOS),
        .S_AXI_ARREGION(),
        .S_AXI_ARUSER (M_AXI_ARUSER),
        .S_AXI_ARVALID(M_AXI_ARVALID),
        .S_AXI_ARREADY(M_AXI_ARREADY),

        .S_AXI_RID    (M_AXI_RID),
        .S_AXI_RDATA  (M_AXI_RDATA),
        .S_AXI_RRESP  (M_AXI_RRESP),
        .S_AXI_RLAST  (M_AXI_RLAST),
        .S_AXI_RUSER  (M_AXI_RUSER),
        .S_AXI_RVALID (M_AXI_RVALID),
        .S_AXI_RREADY (M_AXI_RREADY)
    );
endmodule
