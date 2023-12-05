`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"
`include "wide_alu_pkg.sv"


module wide_alu_top
    #(
      parameter int unsigned AXI_ADDR_WIDTH = 32,
      localparam int unsigned AXI_DATA_WIDTH = 32,
      parameter int unsigned AXI_ID_WIDTH,
      parameter int unsigned AXI_USER_WIDTH
      )
    (
     input logic clk_i,
     input logic rst_ni,
     input logic test_mode_i,

     AXI_BUS.Slave axi_slave
     );

    import wide_alu_reg_pkg::wide_alu_reg2hw_t;
    import wide_alu_reg_pkg::wide_alu_hw2reg_t;

    //Wiring Signals
    REG_BUS #(.ADDR_WIDTH(32), .DATA_WIDTH(32)) axi_to_regfile();
    wide_alu_reg2hw_t reg_file_to_ip;
    wide_alu_hw2reg_t ip_to_reg_file;

    axi_to_reg_intf #(
                      .ADDR_WIDTH(AXI_ADDR_WIDTH),
                      .DATA_WIDTH(AXI_DATA_WIDTH),
                      .ID_WIDTH(AXI_ID_WIDTH),
                      .USER_WIDTH(AXI_USER_WIDTH),
                      .DECOUPLE_W(0)
    ) i_axi2reg (
                 .clk_i,
                 .rst_ni,
                 .testmode_i(test_mode_i),
                 .in(axi_slave),
                 .reg_o(axi_to_regfile)
    );

    //Convert the REG_BUS interface to the struct signals used by autogenerated register file
    typedef logic [AXI_ADDR_WIDTH-1:0] addr_t;
    typedef logic [AXI_DATA_WIDTH-1:0] data_t;
    typedef logic [AXI_DATA_WIDTH/8-1:0] strb_t;
    `REG_BUS_TYPEDEF_REQ(reg_req_t, addr_t, data_t, strb_t);
    `REG_BUS_TYPEDEF_RSP(reg_rsp_t, data_t);
    reg_req_t to_reg_file_req;
    reg_rsp_t from_reg_file_rsp;

    `REG_BUS_ASSIGN_TO_REQ(to_reg_file_req, axi_to_regfile);
    `REG_BUS_ASSIGN_FROM_RSP(axi_to_regfile, from_reg_file_rsp);


    wide_alu_reg_top #(
    .reg_req_t(reg_req_t),
    .reg_rsp_t(reg_rsp_t)
    ) i_regfile (
                 .clk_i,
                 .rst_ni,
                 .devmode_i(1'b1),

                 //From the protocol converters to regfile
                 .reg_req_i(to_reg_file_req),
                 .reg_rsp_o(from_reg_file_rsp),

                 //Signals to wide_alu IP
                 .reg2hw(reg_file_to_ip),
                 .hw2reg(ip_to_reg_file)
    );

    wide_alu i_wide_alu (
                         .clk_i,
                         .rst_ni,
                         .trigger_i(reg_file_to_ip.ctrl1.trigger.q & reg_file_to_ip.ctrl1.trigger.qe),
                         .clear_err_i(reg_file_to_ip.ctrl1.clear_err.q & reg_file_to_ip.ctrl1.clear_err.qe),
                         .op_a_i(reg_file_to_ip.op_a),
                         .op_b_i(reg_file_to_ip.op_b),
                         .deaccel_factor_we_i(reg_file_to_ip.ctrl2.delay.qe),
                         .deaccel_factor_i(reg_file_to_ip.ctrl2.delay.q),
                         .deaccel_factor_o(ip_to_reg_file.ctrl2.delay.d),
                         .op_sel_we_i(reg_file_to_ip.ctrl2.opsel.qe),
                         .op_sel_i(wide_alu_pkg::optype_e'(reg_file_to_ip.ctrl2.opsel.q)),
                         .op_sel_o(ip_to_reg_file.ctrl2.opsel.d),
                         .result_o(ip_to_reg_file.result),
                         .status_o(ip_to_reg_file.status.d)
                         );

endmodule : wide_alu_top
