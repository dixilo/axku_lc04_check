`timescale 1ns / 1ps

module i2c_eeprom_master #(
    parameter integer CLK_DIVIDER = 250
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire        op_read,
    input  wire [8:0]  mem_addr,
    input  wire [7:0]  write_data,
    output reg  [7:0]  read_data,
    output reg         busy,
    output reg         done,
    output reg         error,
    inout  wire        scl_io,
    inout  wire        sda_io,
    output wire [3:0]  status_led,
    output reg  [5:0]  dbg_fsm_state,
    output reg  [4:0]  dbg_bit_state,
    output reg         dbg_ack_poll_active,
    output reg         dbg_ack_poll_seen,
    output reg         dbg_last_ack,
    output reg  [15:0] dbg_ack_poll_count,
    output wire        dbg_scl_sample,
    output wire        dbg_sda_sample
);

    localparam [7:0] EEPROM_BASE_ADDR = 8'hA0;

    localparam [5:0]
        HL_IDLE                = 6'd0,
        HL_START_ISSUE         = 6'd1,
        HL_START_WAIT          = 6'd2,
        HL_SEND_CTRLW_ISSUE    = 6'd3,
        HL_SEND_CTRLW_WAIT     = 6'd4,
        HL_SEND_MEM_ISSUE      = 6'd5,
        HL_SEND_MEM_WAIT       = 6'd6,
        HL_SEND_DATA_ISSUE     = 6'd7,
        HL_SEND_DATA_WAIT      = 6'd8,
        HL_RESTART_ISSUE       = 6'd9,
        HL_RESTART_WAIT        = 6'd10,
        HL_SEND_CTRLR_ISSUE    = 6'd11,
        HL_SEND_CTRLR_WAIT     = 6'd12,
        HL_READ_BYTE_ISSUE     = 6'd13,
        HL_READ_BYTE_WAIT      = 6'd14,
        HL_STOP_ISSUE          = 6'd15,
        HL_STOP_WAIT           = 6'd16,
        HL_ACK_START_ISSUE     = 6'd17,
        HL_ACK_START_WAIT      = 6'd18,
        HL_ACK_CTRL_ISSUE      = 6'd19,
        HL_ACK_CTRL_WAIT       = 6'd20,
        HL_ACK_STOP_ISSUE      = 6'd21,
        HL_ACK_STOP_WAIT       = 6'd22,
        HL_DONE                = 6'd23,
        HL_ERROR               = 6'd24;

    localparam [4:0]
        BIT_IDLE         = 5'd0,
        BIT_START_A      = 5'd1,
        BIT_START_B      = 5'd2,
        BIT_START_C      = 5'd3,
        BIT_STOP_A       = 5'd4,
        BIT_STOP_B       = 5'd5,
        BIT_STOP_C       = 5'd6,
        BIT_TX_SETUP     = 5'd7,
        BIT_TX_HIGH      = 5'd8,
        BIT_TX_HOLD      = 5'd9,
        BIT_ACK_SETUP    = 5'd10,
        BIT_ACK_HIGH     = 5'd11,
        BIT_ACK_HOLD     = 5'd12,
        BIT_RX_SETUP     = 5'd13,
        BIT_RX_HIGH      = 5'd14,
        BIT_RX_HOLD      = 5'd15,
        BIT_RX_ACK_SETUP = 5'd16,
        BIT_RX_ACK_HIGH  = 5'd17,
        BIT_RX_ACK_HOLD  = 5'd18;

    localparam [2:0]
        CMD_NONE  = 3'd0,
        CMD_START = 3'd1,
        CMD_STOP  = 3'd2,
        CMD_SEND  = 3'd3,
        CMD_READ  = 3'd4;

    reg [5:0] hl_state = HL_IDLE;
    reg [4:0] bit_state = BIT_IDLE;
    reg [15:0] clk_div_cnt = 16'd0;
    reg tick = 1'b0;

    reg scl_drive_low = 1'b0;
    reg sda_drive_low = 1'b0;
    wire scl_in;
    wire sda_in;

    reg [2:0]  bit_cmd = CMD_NONE;
    reg        bit_req = 1'b0;
    reg        bit_busy = 1'b0;
    reg        bit_done = 1'b0;
    reg        bit_ack_ok = 1'b0;
    reg [7:0]  bit_tx_data = 8'h00;
    reg [7:0]  bit_rx_data = 8'h00;
    reg [7:0]  bit_shift = 8'h00;
    reg [2:0]  bit_count = 3'd0;
    reg        read_send_nack = 1'b0;

    reg        op_read_latched = 1'b0;
    reg [8:0]  mem_addr_latched = 9'd0;
    reg [7:0]  write_data_latched = 8'd0;
    reg [7:0]  ctrl_write_byte = 8'hA0;
    reg [7:0]  ctrl_read_byte = 8'hA1;

    assign scl_io = scl_drive_low ? 1'b0 : 1'bz;
    assign sda_io = sda_drive_low ? 1'b0 : 1'bz;
    assign scl_in = scl_io;
    assign sda_in = sda_io;

    assign dbg_scl_sample = scl_in;
    assign dbg_sda_sample = sda_in;
    assign status_led = {error, busy, dbg_ack_poll_active, done};

    always @(posedge clk) begin
        if (rst) begin
            clk_div_cnt <= 16'd0;
            tick <= 1'b0;
        end else if (clk_div_cnt == (CLK_DIVIDER - 1)) begin
            clk_div_cnt <= 16'd0;
            tick <= 1'b1;
        end else begin
            clk_div_cnt <= clk_div_cnt + 16'd1;
            tick <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            bit_state <= BIT_IDLE;
            bit_busy <= 1'b0;
            bit_done <= 1'b0;
            bit_ack_ok <= 1'b0;
            bit_shift <= 8'h00;
            bit_rx_data <= 8'h00;
            bit_count <= 3'd0;
            scl_drive_low <= 1'b0;
            sda_drive_low <= 1'b0;
        end else begin
            bit_done <= 1'b0;

            if (!bit_busy && bit_req) begin
                bit_busy <= 1'b1;
                case (bit_cmd)
                    CMD_START: begin
                        bit_state <= BIT_START_A;
                    end
                    CMD_STOP: begin
                        bit_state <= BIT_STOP_A;
                    end
                    CMD_SEND: begin
                        bit_shift <= bit_tx_data;
                        bit_count <= 3'd7;
                        bit_state <= BIT_TX_SETUP;
                    end
                    CMD_READ: begin
                        bit_shift <= 8'h00;
                        bit_count <= 3'd7;
                        bit_state <= BIT_RX_SETUP;
                    end
                    default: begin
                        bit_busy <= 1'b0;
                        bit_state <= BIT_IDLE;
                    end
                endcase
            end else if (bit_busy && tick) begin
                case (bit_state)
                    BIT_START_A: begin
                        scl_drive_low <= 1'b0;
                        sda_drive_low <= 1'b0;
                        bit_state <= BIT_START_B;
                    end
                    BIT_START_B: begin
                        scl_drive_low <= 1'b0;
                        sda_drive_low <= 1'b1;
                        bit_state <= BIT_START_C;
                    end
                    BIT_START_C: begin
                        scl_drive_low <= 1'b1;
                        sda_drive_low <= 1'b1;
                        bit_state <= BIT_IDLE;
                        bit_busy <= 1'b0;
                        bit_done <= 1'b1;
                    end
                    BIT_STOP_A: begin
                        scl_drive_low <= 1'b1;
                        sda_drive_low <= 1'b1;
                        bit_state <= BIT_STOP_B;
                    end
                    BIT_STOP_B: begin
                        scl_drive_low <= 1'b0;
                        sda_drive_low <= 1'b1;
                        bit_state <= BIT_STOP_C;
                    end
                    BIT_STOP_C: begin
                        scl_drive_low <= 1'b0;
                        sda_drive_low <= 1'b0;
                        bit_state <= BIT_IDLE;
                        bit_busy <= 1'b0;
                        bit_done <= 1'b1;
                    end
                    BIT_TX_SETUP: begin
                        scl_drive_low <= 1'b1;
                        sda_drive_low <= ~bit_shift[7];
                        bit_state <= BIT_TX_HIGH;
                    end
                    BIT_TX_HIGH: begin
                        scl_drive_low <= 1'b0;
                        bit_state <= BIT_TX_HOLD;
                    end
                    BIT_TX_HOLD: begin
                        scl_drive_low <= 1'b1;
                        bit_shift <= {bit_shift[6:0], 1'b0};
                        if (bit_count == 3'd0) begin
                            bit_state <= BIT_ACK_SETUP;
                        end else begin
                            bit_count <= bit_count - 3'd1;
                            bit_state <= BIT_TX_SETUP;
                        end
                    end
                    BIT_ACK_SETUP: begin
                        scl_drive_low <= 1'b1;
                        sda_drive_low <= 1'b0;
                        bit_state <= BIT_ACK_HIGH;
                    end
                    BIT_ACK_HIGH: begin
                        scl_drive_low <= 1'b0;
                        bit_state <= BIT_ACK_HOLD;
                    end
                    BIT_ACK_HOLD: begin
                        bit_ack_ok <= (sda_in == 1'b0);
                        scl_drive_low <= 1'b1;
                        bit_state <= BIT_IDLE;
                        bit_busy <= 1'b0;
                        bit_done <= 1'b1;
                    end
                    BIT_RX_SETUP: begin
                        scl_drive_low <= 1'b1;
                        sda_drive_low <= 1'b0;
                        bit_state <= BIT_RX_HIGH;
                    end
                    BIT_RX_HIGH: begin
                        scl_drive_low <= 1'b0;
                        bit_state <= BIT_RX_HOLD;
                    end
                    BIT_RX_HOLD: begin
                        scl_drive_low <= 1'b1;
                        bit_shift <= {bit_shift[6:0], sda_in};
                        if (bit_count == 3'd0) begin
                            bit_state <= BIT_RX_ACK_SETUP;
                        end else begin
                            bit_count <= bit_count - 3'd1;
                            bit_state <= BIT_RX_SETUP;
                        end
                    end
                    BIT_RX_ACK_SETUP: begin
                        scl_drive_low <= 1'b1;
                        sda_drive_low <= ~read_send_nack;
                        bit_state <= BIT_RX_ACK_HIGH;
                    end
                    BIT_RX_ACK_HIGH: begin
                        scl_drive_low <= 1'b0;
                        bit_state <= BIT_RX_ACK_HOLD;
                    end
                    BIT_RX_ACK_HOLD: begin
                        scl_drive_low <= 1'b1;
                        sda_drive_low <= 1'b0;
                        bit_rx_data <= bit_shift;
                        bit_state <= BIT_IDLE;
                        bit_busy <= 1'b0;
                        bit_done <= 1'b1;
                    end
                    default: begin
                        bit_state <= BIT_IDLE;
                        bit_busy <= 1'b0;
                    end
                endcase
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            hl_state <= HL_IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            read_data <= 8'h00;
            op_read_latched <= 1'b0;
            mem_addr_latched <= 9'd0;
            write_data_latched <= 8'h00;
            ctrl_write_byte <= EEPROM_BASE_ADDR;
            ctrl_read_byte <= EEPROM_BASE_ADDR | 8'h01;
            dbg_ack_poll_active <= 1'b0;
            dbg_ack_poll_seen <= 1'b0;
            dbg_last_ack <= 1'b0;
            dbg_ack_poll_count <= 16'd0;
            dbg_fsm_state <= HL_IDLE;
            dbg_bit_state <= BIT_IDLE;
            bit_req <= 1'b0;
            bit_cmd <= CMD_NONE;
            bit_tx_data <= 8'h00;
            read_send_nack <= 1'b0;
        end else begin
            bit_req <= 1'b0;
            dbg_fsm_state <= hl_state;
            dbg_bit_state <= bit_state;

            if (hl_state == HL_IDLE && start && !busy) begin
                op_read_latched <= op_read;
                mem_addr_latched <= mem_addr;
                write_data_latched <= write_data;
                ctrl_write_byte <= EEPROM_BASE_ADDR | {mem_addr[8], 1'b0};
                ctrl_read_byte <= EEPROM_BASE_ADDR | {mem_addr[8], 1'b1};
                busy <= 1'b1;
                done <= 1'b0;
                error <= 1'b0;
                dbg_ack_poll_active <= 1'b0;
                dbg_ack_poll_seen <= 1'b0;
                dbg_last_ack <= 1'b0;
                dbg_ack_poll_count <= 16'd0;
                hl_state <= HL_START_ISSUE;
            end

            case (hl_state)
                HL_IDLE: begin
                end

                HL_START_ISSUE: begin
                    if (!bit_busy) begin
                        bit_cmd <= CMD_START;
                        bit_req <= 1'b1;
                        hl_state <= HL_START_WAIT;
                    end
                end

                HL_START_WAIT: begin
                    if (bit_done) begin
                        hl_state <= HL_SEND_CTRLW_ISSUE;
                    end
                end

                HL_SEND_CTRLW_ISSUE: begin
                    if (!bit_busy) begin
                        bit_cmd <= CMD_SEND;
                        bit_tx_data <= ctrl_write_byte;
                        bit_req <= 1'b1;
                        hl_state <= HL_SEND_CTRLW_WAIT;
                    end
                end

                HL_SEND_CTRLW_WAIT: begin
                    if (bit_done) begin
                        dbg_last_ack <= bit_ack_ok;
                        if (!bit_ack_ok) begin
                            error <= 1'b1;
                            hl_state <= HL_STOP_ISSUE;
                        end else begin
                            hl_state <= HL_SEND_MEM_ISSUE;
                        end
                    end
                end

                HL_SEND_MEM_ISSUE: begin
                    if (!bit_busy) begin
                        bit_cmd <= CMD_SEND;
                        bit_tx_data <= {mem_addr_latched[7:0]};
                        bit_req <= 1'b1;
                        hl_state <= HL_SEND_MEM_WAIT;
                    end
                end

                HL_SEND_MEM_WAIT: begin
                    if (bit_done) begin
                        dbg_last_ack <= bit_ack_ok;
                        if (!bit_ack_ok) begin
                            error <= 1'b1;
                            hl_state <= HL_STOP_ISSUE;
                        end else if (op_read_latched) begin
                            hl_state <= HL_RESTART_ISSUE;
                        end else begin
                            hl_state <= HL_SEND_DATA_ISSUE;
                        end
                    end
                end

                HL_SEND_DATA_ISSUE: begin
                    if (!bit_busy) begin
                        bit_cmd <= CMD_SEND;
                        bit_tx_data <= write_data_latched;
                        bit_req <= 1'b1;
                        hl_state <= HL_SEND_DATA_WAIT;
                    end
                end

                HL_SEND_DATA_WAIT: begin
                    if (bit_done) begin
                        dbg_last_ack <= bit_ack_ok;
                        if (!bit_ack_ok) begin
                            error <= 1'b1;
                        end
                        hl_state <= HL_STOP_ISSUE;
                    end
                end

                HL_RESTART_ISSUE: begin
                    if (!bit_busy) begin
                        bit_cmd <= CMD_START;
                        bit_req <= 1'b1;
                        hl_state <= HL_RESTART_WAIT;
                    end
                end

                HL_RESTART_WAIT: begin
                    if (bit_done) begin
                        hl_state <= HL_SEND_CTRLR_ISSUE;
                    end
                end

                HL_SEND_CTRLR_ISSUE: begin
                    if (!bit_busy) begin
                        bit_cmd <= CMD_SEND;
                        bit_tx_data <= ctrl_read_byte;
                        bit_req <= 1'b1;
                        hl_state <= HL_SEND_CTRLR_WAIT;
                    end
                end

                HL_SEND_CTRLR_WAIT: begin
                    if (bit_done) begin
                        dbg_last_ack <= bit_ack_ok;
                        if (!bit_ack_ok) begin
                            error <= 1'b1;
                            hl_state <= HL_STOP_ISSUE;
                        end else begin
                            hl_state <= HL_READ_BYTE_ISSUE;
                        end
                    end
                end

                HL_READ_BYTE_ISSUE: begin
                    if (!bit_busy) begin
                        bit_cmd <= CMD_READ;
                        read_send_nack <= 1'b1;
                        bit_req <= 1'b1;
                        hl_state <= HL_READ_BYTE_WAIT;
                    end
                end

                HL_READ_BYTE_WAIT: begin
                    if (bit_done) begin
                        read_data <= bit_rx_data;
                        hl_state <= HL_STOP_ISSUE;
                    end
                end

                HL_STOP_ISSUE: begin
                    if (!bit_busy) begin
                        bit_cmd <= CMD_STOP;
                        bit_req <= 1'b1;
                        hl_state <= HL_STOP_WAIT;
                    end
                end

                HL_STOP_WAIT: begin
                    if (bit_done) begin
                        if (!op_read_latched && !error) begin
                            dbg_ack_poll_active <= 1'b1;
                            hl_state <= HL_ACK_START_ISSUE;
                        end else if (error) begin
                            hl_state <= HL_ERROR;
                        end else begin
                            hl_state <= HL_DONE;
                        end
                    end
                end

                HL_ACK_START_ISSUE: begin
                    if (!bit_busy) begin
                        dbg_ack_poll_count <= dbg_ack_poll_count + 16'd1;
                        bit_cmd <= CMD_START;
                        bit_req <= 1'b1;
                        hl_state <= HL_ACK_START_WAIT;
                    end
                end

                HL_ACK_START_WAIT: begin
                    if (bit_done) begin
                        hl_state <= HL_ACK_CTRL_ISSUE;
                    end
                end

                HL_ACK_CTRL_ISSUE: begin
                    if (!bit_busy) begin
                        bit_cmd <= CMD_SEND;
                        bit_tx_data <= ctrl_write_byte;
                        bit_req <= 1'b1;
                        hl_state <= HL_ACK_CTRL_WAIT;
                    end
                end

                HL_ACK_CTRL_WAIT: begin
                    if (bit_done) begin
                        dbg_last_ack <= bit_ack_ok;
                        if (bit_ack_ok) begin
                            dbg_ack_poll_seen <= 1'b1;
                        end
                        hl_state <= HL_ACK_STOP_ISSUE;
                    end
                end

                HL_ACK_STOP_ISSUE: begin
                    if (!bit_busy) begin
                        bit_cmd <= CMD_STOP;
                        bit_req <= 1'b1;
                        hl_state <= HL_ACK_STOP_WAIT;
                    end
                end

                HL_ACK_STOP_WAIT: begin
                    if (bit_done) begin
                        if (dbg_last_ack) begin
                            dbg_ack_poll_active <= 1'b0;
                            hl_state <= HL_DONE;
                        end else begin
                            hl_state <= HL_ACK_START_ISSUE;
                        end
                    end
                end

                HL_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    hl_state <= HL_IDLE;
                end

                HL_ERROR: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    dbg_ack_poll_active <= 1'b0;
                    hl_state <= HL_IDLE;
                end

                default: begin
                    hl_state <= HL_IDLE;
                end
            endcase
        end
    end

endmodule
