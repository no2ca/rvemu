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
__attribute__((aligned(PAGE_SIZE))) static u8 tx_queue_pages[PAGE_SIZE * 2];

static struct virtq_desc *const rx_desc = (struct virtq_desc *) rx_queue_pages;
static struct virtq_avail *const rx_avail = (struct virtq_avail *) (rx_queue_pages + 16 * QUEUE_SIZE);
static struct virtq_used *const rx_used = (struct virtq_used *) (rx_queue_pages + PAGE_SIZE);

static struct virtq_desc *const tx_desc = (struct virtq_desc *) tx_queue_pages;
static struct virtq_avail *const tx_avail = (struct virtq_avail *) (tx_queue_pages + 16 * QUEUE_SIZE);
static struct virtq_used *const tx_used = (struct virtq_used *) (tx_queue_pages + PAGE_SIZE);

static u8 tx_frame[VIRTIO_NET_HDR_SIZE + 4];
static u8 rx_frame[VIRTIO_NET_HDR_SIZE + 64];

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

static void fail(const char *msg) {
    uart_puts("[virtio-net-min] FAIL: ");
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
    // rvemu は check_pending_interrupt() 冒頭で mstatus.MIE を見てから
    // virtio queue 処理を進めるため、ここを有効化する。
    __asm__ volatile("csrs mstatus, %0" : : "r"(0x8) : "memory");
}

static inline void disable_mie_bits(void) {
    // 例外トラップに入らないように、個別割り込みビットは落としておく。
    __asm__ volatile("csrw mie, %0" : : "r"(0));
}

static int wait_used_idx(volatile u16 *idx, u16 expected) {
    u32 timeout = 20000000;
    while (timeout > 0) {
        if (*idx == expected) {
            return 0;
        }
        timeout--;
    }
    return -1;
}

static void setup_queue(u32 queue_index, u8 *queue_pages) {
    u32 max;

    mmio_write32(MMIO_QUEUE_SEL, queue_index);
    max = mmio_read32(MMIO_QUEUE_NUM_MAX);
    if (max < QUEUE_SIZE) {
        fail("queue_num_max is too small");
    }

    mmio_write32(MMIO_QUEUE_NUM, QUEUE_SIZE);
    mmio_write32(MMIO_QUEUE_ALIGN, PAGE_SIZE);
    mmio_write32(MMIO_QUEUE_PFN, (u32) (((u64) queue_pages) / PAGE_SIZE));
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

    setup_queue(0, rx_queue_pages);
    setup_queue(1, tx_queue_pages);

    status |= STATUS_DRIVER_OK;
    mmio_write32(MMIO_STATUS, status);
}

int main(void) {
    u8 payload[4] = {0xde, 0xad, 0xbe, 0xef};
    int i;

    uart_puts("[virtio-net-min] start\n");

    disable_mie_bits();
    enable_mstatus_mie();

    init_virtio_net();

    for (i = 0; i < VIRTIO_NET_HDR_SIZE + 4; i++) {
        tx_frame[i] = 0;
    }
    for (i = 0; i < 4; i++) {
        tx_frame[VIRTIO_NET_HDR_SIZE + i] = payload[i];
    }

    // TX queue: one read-only descriptor.
    tx_desc[0].addr = (u64) tx_frame;
    tx_desc[0].len = VIRTIO_NET_HDR_SIZE + 4;
    tx_desc[0].flags = 0;
    tx_desc[0].next = 0;

    tx_avail->ring[0] = 0;
    fence_rw_rw();
    tx_avail->idx = 1;
    fence_rw_rw();

    mmio_write32(MMIO_QUEUE_NOTIFY, 1);
    if (wait_used_idx(&tx_used->idx, 1) != 0) {
        fail("tx used idx timeout");
    }

    // ACK interrupt if asserted.
    if ((mmio_read32(MMIO_INTERRUPT_STATUS) & 1) != 0) {
        mmio_write32(MMIO_INTERRUPT_ACK, 1);
    }

    // RX queue: one write-only descriptor.
    for (i = 0; i < VIRTIO_NET_HDR_SIZE + 64; i++) {
        rx_frame[i] = 0;
    }
    rx_desc[0].addr = (u64) rx_frame;
    rx_desc[0].len = VIRTIO_NET_HDR_SIZE + 64;
    rx_desc[0].flags = VIRTQ_DESC_F_WRITE;
    rx_desc[0].next = 0;

    rx_avail->ring[0] = 0;
    fence_rw_rw();
    rx_avail->idx = 1;
    fence_rw_rw();

    mmio_write32(MMIO_QUEUE_NOTIFY, 0);
    if (wait_used_idx(&rx_used->idx, 1) != 0) {
        fail("rx used idx timeout");
    }

    if ((mmio_read32(MMIO_INTERRUPT_STATUS) & 1) != 0) {
        mmio_write32(MMIO_INTERRUPT_ACK, 1);
    }

    for (i = 0; i < VIRTIO_NET_HDR_SIZE; i++) {
        if (rx_frame[i] != 0) {
            fail("rx header mismatch");
        }
    }

    for (i = 0; i < 4; i++) {
        if (rx_frame[VIRTIO_NET_HDR_SIZE + i] != payload[i]) {
            fail("rx payload mismatch");
        }
    }

    uart_puts("[virtio-net-min] PASS\n");

    while (1) {
    }

    return 0;
}
