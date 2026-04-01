#include "xil_io.h"
#include "xparameters.h"
#include "xstatus.h"
#include "xil_printf.h"

#ifndef XPAR_AXI_I2C_EEPROM_CTRL_0_S_AXI_BASEADDR
#define XPAR_AXI_I2C_EEPROM_CTRL_0_S_AXI_BASEADDR XPAR_AXI_I2C_EEPROM_CTRL_0_S00_AXI_BASEADDR
#endif

#define EEPROM_CTRL_BASE XPAR_AXI_I2C_EEPROM_CTRL_0_S_AXI_BASEADDR

#define REG_CONTROL 0x00U
#define REG_STATUS  0x04U
#define REG_ADDR    0x08U
#define REG_WDATA   0x0CU
#define REG_RDATA   0x10U
#define REG_DEBUG   0x14U

#define CTRL_START  (1U << 0)
#define CTRL_READ   (1U << 1)

#define ST_BUSY             (1U << 0)
#define ST_ERROR            (1U << 1)
#define ST_ACK_POLL_ACTIVE  (1U << 2)
#define ST_ACK_POLL_SEEN    (1U << 3)
#define ST_LAST_ACK         (1U << 4)
#define ST_DONE             (1U << 5)

extern char inbyte(void);
extern void outbyte(char c);

static void print_menu(void)
{
    xil_printf("\r\n24LC04 access menu\r\n");
    xil_printf("  w : single-byte write\r\n");
    xil_printf("  r : single-byte read\r\n");
    xil_printf("  q : quit loop (soft reset needed to rerun)\r\n");
    xil_printf("> ");
}

static char read_char(void)
{
    char c;

    c = inbyte();
    outbyte(c);
    if (c == '\r') {
        outbyte('\n');
    }
    return c;
}

static int read_hex_number(unsigned int *value)
{
    char buf[16];
    int idx = 0;
    unsigned int result = 0;
    char c;

    while (1) {
        c = read_char();
        if (c == '\r' || c == '\n') {
            break;
        }
        if (idx < (int)(sizeof(buf) - 1)) {
            buf[idx++] = c;
        }
    }
    buf[idx] = '\0';

    if (idx == 0) {
        return XST_FAILURE;
    }

    /* skip optional "0x" / "0X" prefix */
    int start_idx = 0;
    if (idx >= 2 && buf[0] == '0' && (buf[1] == 'x' || buf[1] == 'X')) {
        start_idx = 2;
    }

    for (idx = start_idx; buf[idx] != '\0'; ++idx) {
        char ch = buf[idx];
        result <<= 4;
        if (ch >= '0' && ch <= '9') {
            result |= (unsigned int)(ch - '0');
        } else if (ch >= 'a' && ch <= 'f') {
            result |= (unsigned int)(ch - 'a' + 10);
        } else if (ch >= 'A' && ch <= 'F') {
            result |= (unsigned int)(ch - 'A' + 10);
        } else {
            return XST_FAILURE;
        }
    }

    *value = result;
    return XST_SUCCESS;
}

static int wait_complete(void)
{
    u32 status;
    u32 timeout = 0U;

    do {
        status = Xil_In32(EEPROM_CTRL_BASE + REG_STATUS);
        timeout++;
        if ((status & ST_DONE) != 0U) {
            if ((status & ST_ERROR) != 0U) {
                xil_printf("transaction failed, status=0x%08lx\r\n", (unsigned long)status);
                return XST_FAILURE;
            }

            xil_printf("done, status=0x%08lx", (unsigned long)status);
            if ((status & ST_ACK_POLL_SEEN) != 0U) {
                xil_printf(" (ACK polling completed)");
            }
            xil_printf("\r\n");
            return XST_SUCCESS;
        }
    } while (timeout < 50000000U);

    xil_printf("timeout waiting for controller\r\n");
    return XST_FAILURE;
}

static void do_write(void)
{
    unsigned int addr;
    unsigned int data;

    xil_printf("address (hex, 000-1FF): ");
    if (read_hex_number(&addr) != XST_SUCCESS || addr > 0x1FFU) {
        xil_printf("invalid address\r\n");
        return;
    }

    xil_printf("byte (hex, 00-FF): ");
    if (read_hex_number(&data) != XST_SUCCESS || data > 0xFFU) {
        xil_printf("invalid data\r\n");
        return;
    }

    Xil_Out32(EEPROM_CTRL_BASE + REG_ADDR, addr);
    Xil_Out32(EEPROM_CTRL_BASE + REG_WDATA, data);
    Xil_Out32(EEPROM_CTRL_BASE + REG_CONTROL, CTRL_START);

    if (wait_complete() == XST_SUCCESS) {
        xil_printf("write 0x%02x -> [0x%03x]\r\n", data & 0xFFU, addr & 0x1FFU);
    }
}

static void do_read(void)
{
    unsigned int addr;
    u32 value;

    xil_printf("address (hex, 000-1FF): ");
    if (read_hex_number(&addr) != XST_SUCCESS || addr > 0x1FFU) {
        xil_printf("invalid address\r\n");
        return;
    }

    Xil_Out32(EEPROM_CTRL_BASE + REG_ADDR, addr);
    Xil_Out32(EEPROM_CTRL_BASE + REG_CONTROL, CTRL_START | CTRL_READ);

    if (wait_complete() == XST_SUCCESS) {
        value = Xil_In32(EEPROM_CTRL_BASE + REG_RDATA);
        xil_printf("read [0x%03x] = 0x%02lx\r\n", addr & 0x1FFU, (unsigned long)(value & 0xFFU));
    }
}

int main(void)
{
    char cmd;

    xil_printf("\r\nAXKU042 24LC04 demo\r\n");
    xil_printf("Controller base address: 0x%08lx\r\n", (unsigned long)EEPROM_CTRL_BASE);

    while (1) {
        print_menu();
        cmd = read_char();
        xil_printf("\r\n");

        if (cmd == 'w' || cmd == 'W') {
            do_write();
        } else if (cmd == 'r' || cmd == 'R') {
            do_read();
        } else if (cmd == 'q' || cmd == 'Q') {
            xil_printf("exit\r\n");
            break;
        } else {
            xil_printf("unknown command\r\n");
        }
    }

    return 0;
}
