typedef unsigned char u8;
typedef unsigned short u16;
typedef unsigned int u32;
typedef unsigned long long u64;

__asm__(
    ".globl _start\n"
    "_start:\n"
    "  li sp, 0xc0000000\n"
    "  call main\n"
    "1:\n"
    "  j 1b\n"
);

#define UART_BASE 0x10000000ULL
#define UART_THR 0
#define UART_LSR 5
#define UART_LSR_TX_IDLE 0x20

#define VIRTIO_NET_BASE 0x10002000ULL

#define MMIO_MAGIC_VALUE 0x000
#define MMIO_VERSION 0x004
#define MMIO_DEVICE_ID 0x008
#define MMIO_VENDOR_ID 0x00c
#define MMIO_DEVICE_FEATURES 0x010
#define MMIO_DEVICE_FEATURES_SEL 0x014
#define MMIO_DRIVER_FEATURES 0x020
#define MMIO_DRIVER_FEATURES_SEL 0x024
#define MMIO_GUEST_PAGE_SIZE 0x028
#define MMIO_QUEUE_SEL 0x030
#define MMIO_QUEUE_NUM_MAX 0x034
#define MMIO_QUEUE_NUM 0x038
#define MMIO_QUEUE_ALIGN 0x03c
#define MMIO_QUEUE_PFN 0x040
#define MMIO_QUEUE_NOTIFY 0x050
#define MMIO_INTERRUPT_STATUS 0x060
#define MMIO_INTERRUPT_ACK 0x064
#define MMIO_STATUS 0x070

#define STATUS_ACKNOWLEDGE 1
#define STATUS_DRIVER 2
#define STATUS_DRIVER_OK 4
#define STATUS_FEATURES_OK 8

#define VIRTQ_DESC_F_WRITE 2

#define PAGE_SIZE 4096
#define QUEUE_SIZE 8
#define VIRTIO_NET_HDR_SIZE 10
#define ETH_HEADER_SIZE 14

struct virtq_desc {
    u64 addr;
    u32 len;
    u16 flags;
    u16 next;
};

struct virtq_avail {
    u16 flags;
    u16 idx;
    u16 ring[QUEUE_SIZE];
    u16 used_event;
};

struct virtq_used_elem {
    u32 id;
    u32 len;
};

struct virtq_used {
    u16 flags;
    u16 idx;
    struct virtq_used_elem ring[QUEUE_SIZE];
    u16 avail_event;
};

__attribute__((aligned(PAGE_SIZE))) static u8 rx_queue_pages[PAGE_SIZE * 2];

static struct virtq_desc *const rx_desc = (struct virtq_desc *) rx_queue_pages;
static struct virtq_avail *const rx_avail = (struct virtq_avail *) (rx_queue_pages + 16 * QUEUE_SIZE);
static struct virtq_used *const rx_used = (struct virtq_used *) (rx_queue_pages + PAGE_SIZE);

static u8 rx_frame[VIRTIO_NET_HDR_SIZE + 512];

static inline volatile u8 *uart(void) {
    return (volatile u8 *) UART_BASE;
}

static inline void uart_putc(char c) {
    volatile u8 *u = uart();
    while ((u[UART_LSR] & UART_LSR_TX_IDLE) == 0) {
    }
    u[UART_THR] = (u8) c;
}

static void uart_puts(const char *s) {
    while (*s != '\0') {
        uart_putc(*s);
        s++;
    }
}

static void uart_put_u32_hex(u32 v) {
    static const char hex[] = "0123456789abcdef";
    int i;
    uart_puts("0x");
    for (i = 7; i >= 0; i--) {
        uart_putc(hex[(v >> (i * 4)) & 0xf]);
    }
}

static void fail(const char *msg) {
    uart_puts("[host-rx] FAIL: ");
    uart_puts(msg);
    uart_puts("\n");
    while (1) {
    }
}

static inline u32 mmio_read32(u64 offset) {
    return *(volatile u32 *) (VIRTIO_NET_BASE + offset);
}

static inline void mmio_write32(u64 offset, u32 value) {
    *(volatile u32 *) (VIRTIO_NET_BASE + offset) = value;
}

static inline void fence_rw_rw(void) {
    __asm__ volatile("fence rw, rw" ::: "memory");
}

static inline void enable_mstatus_mie(void) {
    __asm__ volatile("csrs mstatus, %0" : : "r"(0x8) : "memory");
}

static inline void disable_mie_bits(void) {
    __asm__ volatile("csrw mie, %0" : : "r"(0));
}

static void setup_rx_queue(void) {
    u32 max;

    mmio_write32(MMIO_QUEUE_SEL, 0);
    max = mmio_read32(MMIO_QUEUE_NUM_MAX);
    if (max < QUEUE_SIZE) {
        fail("queue_num_max is too small");
    }

    mmio_write32(MMIO_QUEUE_NUM, QUEUE_SIZE);
    mmio_write32(MMIO_QUEUE_ALIGN, PAGE_SIZE);
    mmio_write32(MMIO_QUEUE_PFN, (u32) (((u64) rx_queue_pages) / PAGE_SIZE));
}

static void init_virtio_net(void) {
    u32 status;
    u32 f0;
    u32 f1;

    if (mmio_read32(MMIO_MAGIC_VALUE) != 0x74726976) {
        fail("bad magic");
    }
    if (mmio_read32(MMIO_VERSION) != 1) {
        fail("bad version");
    }
    if (mmio_read32(MMIO_DEVICE_ID) != 1) {
        fail("bad device id");
    }
    if (mmio_read32(MMIO_VENDOR_ID) != 0x554d4551) {
        fail("bad vendor id");
    }

    mmio_write32(MMIO_STATUS, 0);

    status = STATUS_ACKNOWLEDGE;
    mmio_write32(MMIO_STATUS, status);

    status |= STATUS_DRIVER;
    mmio_write32(MMIO_STATUS, status);

    mmio_write32(MMIO_DEVICE_FEATURES_SEL, 0);
    f0 = mmio_read32(MMIO_DEVICE_FEATURES);
    mmio_write32(MMIO_DEVICE_FEATURES_SEL, 1);
    f1 = mmio_read32(MMIO_DEVICE_FEATURES);

    mmio_write32(MMIO_DRIVER_FEATURES_SEL, 0);
    mmio_write32(MMIO_DRIVER_FEATURES, f0);
    mmio_write32(MMIO_DRIVER_FEATURES_SEL, 1);
    mmio_write32(MMIO_DRIVER_FEATURES, f1);

    status |= STATUS_FEATURES_OK;
    mmio_write32(MMIO_STATUS, status);
    if ((mmio_read32(MMIO_STATUS) & STATUS_FEATURES_OK) == 0) {
        fail("FEATURES_OK rejected");
    }

    mmio_write32(MMIO_GUEST_PAGE_SIZE, PAGE_SIZE);
    setup_rx_queue();

    status |= STATUS_DRIVER_OK;
    mmio_write32(MMIO_STATUS, status);
}

static void post_one_rx_desc(u16 avail_index) {
    int i;
    for (i = 0; i < (int)sizeof(rx_frame); i++) {
        rx_frame[i] = 0;
    }

    rx_desc[0].addr = (u64) rx_frame;
    rx_desc[0].len = sizeof(rx_frame);
    rx_desc[0].flags = VIRTQ_DESC_F_WRITE;
    rx_desc[0].next = 0;

    rx_avail->ring[avail_index % QUEUE_SIZE] = 0;
    fence_rw_rw();
    rx_avail->idx = avail_index + 1;
    fence_rw_rw();
}

static int wait_used_idx(u16 expected) {
    u32 timeout = 200000000;
    while (timeout > 0) {
        if (rx_used->idx == expected) {
            return 0;
        }
        timeout--;
    }
    return -1;
}

static void print_received_payload(u32 used_len) {
    u32 i;
    u32 frame_len;
    u32 payload_offset = VIRTIO_NET_HDR_SIZE + ETH_HEADER_SIZE;

    if (used_len <= payload_offset) {
        uart_puts("[host-rx] short frame len=");
        uart_put_u32_hex(used_len);
        uart_puts("\n");
        return;
    }

    frame_len = used_len - payload_offset;
    uart_puts("[host-rx] ");
    for (i = 0; i < frame_len; i++) {
        u8 c = rx_frame[payload_offset + i];
        if (c >= 32 && c <= 126) {
            uart_putc((char) c);
        } else {
            uart_putc('.');
        }
    }
    uart_puts("\n");
}

int main(void) {
    u16 expect_used = 1;

    uart_puts("[host-rx] start\n");

    disable_mie_bits();
    enable_mstatus_mie();
    init_virtio_net();

    while (1) {
        post_one_rx_desc(expect_used - 1);

        if (wait_used_idx(expect_used) != 0) {
            fail("rx timeout");
        }

        if ((mmio_read32(MMIO_INTERRUPT_STATUS) & 1) != 0) {
            mmio_write32(MMIO_INTERRUPT_ACK, 1);
        }

        print_received_payload(rx_used->ring[(expect_used - 1) % QUEUE_SIZE].len);
        expect_used++;
    }

    return 0;
}
