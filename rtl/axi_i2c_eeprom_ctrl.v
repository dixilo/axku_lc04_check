`timescale 1ns / 1ps

module axi_i2c_eeprom_ctrl #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6,
    parameter integer I2C_CLK_DIVIDER    = 250
) (
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI:ASSOCIATED_RESET s_axi_aresetn:FREQ_HZ 100000000" *)
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_aclk CLK" *)
    input  wire                              s_axi_aclk,
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 s_axi_aresetn RST" *)
    input  wire                              s_axi_aresetn,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *)
    input  wire [2:0]                        s_axi_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
    input  wire                              s_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
    output reg                               s_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
    input  wire                              s_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
    output reg                               s_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
    output reg  [1:0]                        s_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
    output reg                               s_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
    input  wire                              s_axi_bready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *)
    input  wire [2:0]                        s_axi_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
    input  wire                              s_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
    output reg                               s_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
    output reg  [C_S_AXI_DATA_WIDTH-1:0]     s_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
    output reg  [1:0]                        s_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
    output reg                               s_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
    input  wire                              s_axi_rready,
    input  wire                              iic_scl_i,
    output wire                              iic_scl_o,
    output wire                              iic_scl_t,
    input  wire                              iic_sda_i,
    output wire                              iic_sda_o,
    output wire                              iic_sda_t,
    output wire [3:0]                        user_led,
    output wire [5:0]                        dbg_fsm_state,
    output wire [4:0]                        dbg_bit_state,
    output wire                              dbg_ack_poll_active,
    output wire                              dbg_ack_poll_seen,
    output wire                              dbg_last_ack,
    output wire [15:0]                       dbg_ack_poll_count,
    output wire                              dbg_scl_sample,
    output wire                              dbg_sda_sample
);

    localparam integer ADDR_LSB = 2;

    reg [31:0] control_reg = 32'd0;
    reg [31:0] addr_reg = 32'd0;
    reg [31:0] write_reg = 32'd0;
    reg [31:0] status_reg = 32'd0;
    reg [31:0] read_reg = 32'd0;
    reg        start_pulse = 1'b0;

    wire core_busy;
    wire core_done;
    wire core_error;
    wire [7:0] core_read_data;
    wire scl_drive_low;
    wire sda_drive_low;

    assign iic_scl_o = 1'b0;
    assign iic_scl_t = ~scl_drive_low;
    assign iic_sda_o = 1'b0;
    assign iic_sda_t = ~sda_drive_low;

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready <= 1'b0;
            s_axi_bresp <= 2'b00;
            s_axi_bvalid <= 1'b0;
            s_axi_arready <= 1'b0;
            s_axi_rdata <= 32'd0;
            s_axi_rresp <= 2'b00;
            s_axi_rvalid <= 1'b0;
            control_reg <= 32'd0;
            addr_reg <= 32'd0;
            write_reg <= 32'd0;
            start_pulse <= 1'b0;
        end else begin
            start_pulse <= 1'b0;

            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready <= 1'b1;
                case (s_axi_awaddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB])
                    4'h0: begin
                        control_reg <= s_axi_wdata;
                        if (s_axi_wdata[0] && !core_busy) begin
                            start_pulse <= 1'b1;
                        end
                    end
                    4'h2: addr_reg <= s_axi_wdata;
                    4'h3: write_reg <= s_axi_wdata;
                    default: begin
                    end
                endcase
                s_axi_bvalid <= 1'b1;
                s_axi_bresp <= 2'b00;
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready <= 1'b0;
            end

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end

            if (!s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                s_axi_rvalid <= 1'b1;
                s_axi_rresp <= 2'b00;
                case (s_axi_araddr[C_S_AXI_ADDR_WIDTH-1:ADDR_LSB])
                    4'h0: s_axi_rdata <= control_reg;
                    4'h1: s_axi_rdata <= status_reg;
                    4'h2: s_axi_rdata <= addr_reg;
                    4'h3: s_axi_rdata <= write_reg;
                    4'h4: s_axi_rdata <= read_reg;
                    4'h5: s_axi_rdata <= {10'd0, dbg_ack_poll_count, dbg_last_ack, dbg_ack_poll_seen, dbg_ack_poll_active, dbg_bit_state, dbg_fsm_state};
                    default: s_axi_rdata <= 32'd0;
                endcase
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end

            status_reg <= {
                26'd0,
                core_done,
                dbg_last_ack,
                dbg_ack_poll_seen,
                dbg_ack_poll_active,
                core_error,
                core_busy
            };
            read_reg <= {24'd0, core_read_data};
        end
    end

    i2c_eeprom_master #(
        .CLK_DIVIDER(I2C_CLK_DIVIDER)
    ) u_core (
        .clk(s_axi_aclk),
        .rst(~s_axi_aresetn),
        .start(start_pulse),
        .op_read(control_reg[1]),
        .mem_addr(addr_reg[8:0]),
        .write_data(write_reg[7:0]),
        .read_data(core_read_data),
        .busy(core_busy),
        .done(core_done),
        .error(core_error),
        .scl_i(iic_scl_i),
        .sda_i(iic_sda_i),
        .scl_drive_low(scl_drive_low),
        .sda_drive_low(sda_drive_low),
        .status_led(user_led),
        .dbg_fsm_state(dbg_fsm_state),
        .dbg_bit_state(dbg_bit_state),
        .dbg_ack_poll_active(dbg_ack_poll_active),
        .dbg_ack_poll_seen(dbg_ack_poll_seen),
        .dbg_last_ack(dbg_last_ack),
        .dbg_ack_poll_count(dbg_ack_poll_count),
        .dbg_scl_sample(dbg_scl_sample),
        .dbg_sda_sample(dbg_sda_sample)
    );

endmodule
