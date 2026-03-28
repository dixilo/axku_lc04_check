`timescale 1ns / 1ps

module axku_lc04_top (
    input  wire       PL_CLK0_P,
    input  wire       PL_CLK0_N,
    input  wire       ext_resetn,
    inout  wire       iic_sda,
    inout  wire       iic_scl,
    output wire [3:0] user_led
);

    wire clk_200;
    wire iic_scl_i;
    wire iic_scl_o;
    wire iic_scl_t;
    wire iic_sda_i;
    wire iic_sda_o;
    wire iic_sda_t;

    (* mark_debug = "true" *) wire [5:0]  dbg_fsm_state;
    (* mark_debug = "true" *) wire [4:0]  dbg_bit_state;
    (* mark_debug = "true" *) wire        dbg_ack_poll_active;
    (* mark_debug = "true" *) wire        dbg_ack_poll_seen;
    (* mark_debug = "true" *) wire        dbg_last_ack;
    (* mark_debug = "true" *) wire [15:0] dbg_ack_poll_count;
    (* mark_debug = "true" *) wire        dbg_scl_sample;
    (* mark_debug = "true" *) wire        dbg_sda_sample;

    IBUFDS #(
        .DIFF_TERM("FALSE"),
        .IBUF_LOW_PWR("FALSE"),
        .IOSTANDARD("LVDS")
    ) u_ibufds_sysclk (
        .I(PL_CLK0_P),
        .IB(PL_CLK0_N),
        .O(clk_200)
    );

    IOBUF u_iobuf_scl (
        .I(iic_scl_o),
        .IO(iic_scl),
        .O(iic_scl_i),
        .T(iic_scl_t)
    );

    IOBUF u_iobuf_sda (
        .I(iic_sda_o),
        .IO(iic_sda),
        .O(iic_sda_i),
        .T(iic_sda_t)
    );

    mb_i2c_system_wrapper u_system (
        .clk_200(clk_200),
        .ext_resetn(ext_resetn),
        .iic_scl_i(iic_scl_i),
        .iic_scl_o(iic_scl_o),
        .iic_scl_t(iic_scl_t),
        .iic_sda_i(iic_sda_i),
        .iic_sda_o(iic_sda_o),
        .iic_sda_t(iic_sda_t),
        .user_led(user_led),
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
