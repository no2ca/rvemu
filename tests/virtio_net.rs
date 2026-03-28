use rvemu::bus::{DRAM_BASE, VIRTIO_NET_BASE};
use rvemu::cpu::{Cpu, BYTE, DOUBLEWORD, HALFWORD, WORD};
use rvemu::devices::virtio_net::VirtioNet;

const VIRTIO_NET_HDR_SIZE: usize = 10;
const QUEUE_SIZE: u64 = 8;
const QUEUE_ALIGN: u64 = 0x1000;
const GUEST_PAGE_SIZE: u64 = 0x1000;
const VIRTQ_DESC_F_WRITE: u64 = 2;
const DEVICE_MAC: [u8; 6] = [0x52, 0x54, 0x00, 0x12, 0x34, 0x56];
const BROADCAST_REPLY_BODY: &[u8] = b"rvemu: broadcast received";

const VERSION: u64 = VIRTIO_NET_BASE + 0x4;
const DEVICE_ID: u64 = VIRTIO_NET_BASE + 0x8;
const VENDOR_ID: u64 = VIRTIO_NET_BASE + 0xc;
const GUEST_PAGE_SIZE_REG: u64 = VIRTIO_NET_BASE + 0x28;
const QUEUE_SEL: u64 = VIRTIO_NET_BASE + 0x30;
const QUEUE_NUM: u64 = VIRTIO_NET_BASE + 0x38;
const QUEUE_ALIGN_REG: u64 = VIRTIO_NET_BASE + 0x3c;
const QUEUE_PFN: u64 = VIRTIO_NET_BASE + 0x40;
const QUEUE_NOTIFY: u64 = VIRTIO_NET_BASE + 0x50;
const INTERRUPT_STATUS: u64 = VIRTIO_NET_BASE + 0x60;
const STATUS: u64 = VIRTIO_NET_BASE + 0x70;
const CONFIG: u64 = VIRTIO_NET_BASE + 0x100;

fn mmio_write(cpu: &mut Cpu, addr: u64, value: u64) {
    cpu.bus.write(addr, value, WORD).unwrap();
}

fn write_desc(cpu: &mut Cpu, desc_table_addr: u64, index: u64, addr: u64, len: u64, flags: u64) {
    let entry = desc_table_addr + index * 16;
    cpu.bus.write(entry, addr, DOUBLEWORD).unwrap();
    cpu.bus.write(entry + 8, len, WORD).unwrap();
    cpu.bus.write(entry + 12, flags, HALFWORD).unwrap();
    cpu.bus.write(entry + 14, 0, HALFWORD).unwrap();
}

fn virtqueue_layout(base_addr: u64) -> (u64, u64, u64) {
    let desc_addr = base_addr;
    let avail_addr = desc_addr + 16 * QUEUE_SIZE;
    let avail_end = avail_addr + 6 + 2 * QUEUE_SIZE;
    let used_addr = (avail_end.wrapping_div(QUEUE_ALIGN) + 1).wrapping_mul(QUEUE_ALIGN);
    (desc_addr, avail_addr, used_addr)
}

#[test]
fn virtio_net_mmio_identity_and_config() {
    let mut cpu = Cpu::new();

    assert_eq!(0x7472_6976, cpu.bus.read(VIRTIO_NET_BASE, WORD).unwrap());
    assert_eq!(1, cpu.bus.read(VERSION, WORD).unwrap());
    assert_eq!(1, cpu.bus.read(DEVICE_ID, WORD).unwrap());
    assert_eq!(0x554d_4551, cpu.bus.read(VENDOR_ID, WORD).unwrap());

    assert_eq!(0x52, cpu.bus.read(CONFIG, BYTE).unwrap());
    assert_eq!(0x54, cpu.bus.read(CONFIG + 1, BYTE).unwrap());
    assert_eq!(0x00, cpu.bus.read(CONFIG + 2, BYTE).unwrap());
    assert_eq!(0x12, cpu.bus.read(CONFIG + 3, BYTE).unwrap());
    assert_eq!(0x34, cpu.bus.read(CONFIG + 4, BYTE).unwrap());
    assert_eq!(0x56, cpu.bus.read(CONFIG + 5, BYTE).unwrap());
}

#[test]
fn virtio_net_tx_rx_loopback_updates_used_ring() {
    let mut cpu = Cpu::new();

    let rx_queue_base = DRAM_BASE + 0x1000;
    let tx_queue_base = DRAM_BASE + 0x3000;
    let tx_buffer_addr = DRAM_BASE + 0x5000;
    let rx_buffer_addr = DRAM_BASE + 0x6000;

    let (_rx_desc, rx_avail, rx_used) = virtqueue_layout(rx_queue_base);
    let (tx_desc, tx_avail, tx_used) = virtqueue_layout(tx_queue_base);

    mmio_write(&mut cpu, GUEST_PAGE_SIZE_REG, GUEST_PAGE_SIZE);

    // Configure RX queue (0).
    mmio_write(&mut cpu, QUEUE_SEL, 0);
    mmio_write(&mut cpu, QUEUE_NUM, QUEUE_SIZE);
    mmio_write(&mut cpu, QUEUE_ALIGN_REG, QUEUE_ALIGN);
    mmio_write(&mut cpu, QUEUE_PFN, rx_queue_base / GUEST_PAGE_SIZE);

    // Configure TX queue (1).
    mmio_write(&mut cpu, QUEUE_SEL, 1);
    mmio_write(&mut cpu, QUEUE_NUM, QUEUE_SIZE);
    mmio_write(&mut cpu, QUEUE_ALIGN_REG, QUEUE_ALIGN);
    mmio_write(&mut cpu, QUEUE_PFN, tx_queue_base / GUEST_PAGE_SIZE);

    // DRIVER_OK
    mmio_write(&mut cpu, STATUS, 0x4);

    let payload = vec![1_u8, 2, 3, 4];
    let mut tx_frame = vec![0_u8; VIRTIO_NET_HDR_SIZE];
    tx_frame.extend_from_slice(&payload);

    for (i, byte) in tx_frame.iter().enumerate() {
        cpu.bus
            .write(tx_buffer_addr + i as u64, *byte as u64, BYTE)
            .unwrap();
    }

    // TX: guest -> device.
    write_desc(
        &mut cpu,
        tx_desc,
        0,
        tx_buffer_addr,
        tx_frame.len() as u64,
        0,
    );
    cpu.bus.write(tx_avail + 2, 1, HALFWORD).unwrap(); // avail.idx
    cpu.bus.write(tx_avail + 4, 0, HALFWORD).unwrap(); // ring[0] = desc 0

    mmio_write(&mut cpu, QUEUE_NOTIFY, 1);
    assert!(cpu.bus.virtio_net.is_interrupting());
    VirtioNet::net_access(&mut cpu).unwrap();

    assert_eq!(Some(payload.clone()), cpu.bus.virtio_net.pop_tx_packet());
    assert_eq!(1, cpu.bus.read(tx_used + 2, HALFWORD).unwrap()); // used.idx

    // RX: device -> guest.
    write_desc(
        &mut cpu,
        rx_queue_base,
        0,
        rx_buffer_addr,
        (VIRTIO_NET_HDR_SIZE + payload.len()) as u64,
        VIRTQ_DESC_F_WRITE,
    );
    cpu.bus.write(rx_avail + 2, 1, HALFWORD).unwrap(); // avail.idx
    cpu.bus.write(rx_avail + 4, 0, HALFWORD).unwrap(); // ring[0] = desc 0

    mmio_write(&mut cpu, QUEUE_NOTIFY, 0);
    assert!(cpu.bus.virtio_net.is_interrupting());
    VirtioNet::net_access(&mut cpu).unwrap();

    for i in 0..VIRTIO_NET_HDR_SIZE {
        assert_eq!(0, cpu.bus.read(rx_buffer_addr + i as u64, BYTE).unwrap());
    }
    for (i, byte) in payload.iter().enumerate() {
        let addr = rx_buffer_addr + VIRTIO_NET_HDR_SIZE as u64 + i as u64;
        assert_eq!(*byte as u64, cpu.bus.read(addr, BYTE).unwrap());
    }

    assert_eq!(1, cpu.bus.read(rx_used + 2, HALFWORD).unwrap()); // used.idx
    assert_eq!(1, cpu.bus.read(INTERRUPT_STATUS, WORD).unwrap() & 0x1);
}

#[test]
fn virtio_net_broadcast_packet_gets_fixed_response() {
    let mut cpu = Cpu::new();

    let rx_queue_base = DRAM_BASE + 0x7000;
    let tx_queue_base = DRAM_BASE + 0x9000;
    let tx_buffer_addr = DRAM_BASE + 0xb000;
    let rx_buffer_addr = DRAM_BASE + 0xc000;

    let (_rx_desc, rx_avail, _rx_used) = virtqueue_layout(rx_queue_base);
    let (tx_desc, tx_avail, _tx_used) = virtqueue_layout(tx_queue_base);

    mmio_write(&mut cpu, GUEST_PAGE_SIZE_REG, GUEST_PAGE_SIZE);

    // Configure RX queue (0).
    mmio_write(&mut cpu, QUEUE_SEL, 0);
    mmio_write(&mut cpu, QUEUE_NUM, QUEUE_SIZE);
    mmio_write(&mut cpu, QUEUE_ALIGN_REG, QUEUE_ALIGN);
    mmio_write(&mut cpu, QUEUE_PFN, rx_queue_base / GUEST_PAGE_SIZE);

    // Configure TX queue (1).
    mmio_write(&mut cpu, QUEUE_SEL, 1);
    mmio_write(&mut cpu, QUEUE_NUM, QUEUE_SIZE);
    mmio_write(&mut cpu, QUEUE_ALIGN_REG, QUEUE_ALIGN);
    mmio_write(&mut cpu, QUEUE_PFN, tx_queue_base / GUEST_PAGE_SIZE);

    // DRIVER_OK
    mmio_write(&mut cpu, STATUS, 0x4);

    let sender_mac = [0x02_u8, 0x00, 0x00, 0x00, 0x00, 0x01];
    let ether_type = [0x08_u8, 0x00];

    let mut payload = vec![0xff_u8; 6]; // broadcast dst mac
    payload.extend_from_slice(&sender_mac); // src mac
    payload.extend_from_slice(&ether_type); // ethertype
    payload.extend_from_slice(b"hello");

    let mut tx_frame = vec![0_u8; VIRTIO_NET_HDR_SIZE];
    tx_frame.extend_from_slice(&payload);

    for (i, byte) in tx_frame.iter().enumerate() {
        cpu.bus
            .write(tx_buffer_addr + i as u64, *byte as u64, BYTE)
            .unwrap();
    }

    // TX notification.
    write_desc(
        &mut cpu,
        tx_desc,
        0,
        tx_buffer_addr,
        tx_frame.len() as u64,
        0,
    );
    cpu.bus.write(tx_avail + 2, 1, HALFWORD).unwrap();
    cpu.bus.write(tx_avail + 4, 0, HALFWORD).unwrap();
    mmio_write(&mut cpu, QUEUE_NOTIFY, 1);
    assert!(cpu.bus.virtio_net.is_interrupting());
    VirtioNet::net_access(&mut cpu).unwrap();

    // RX notification.
    write_desc(
        &mut cpu,
        rx_queue_base,
        0,
        rx_buffer_addr,
        (VIRTIO_NET_HDR_SIZE + 128) as u64,
        VIRTQ_DESC_F_WRITE,
    );
    cpu.bus.write(rx_avail + 2, 1, HALFWORD).unwrap();
    cpu.bus.write(rx_avail + 4, 0, HALFWORD).unwrap();
    mmio_write(&mut cpu, QUEUE_NOTIFY, 0);
    assert!(cpu.bus.virtio_net.is_interrupting());
    VirtioNet::net_access(&mut cpu).unwrap();

    // virtio-net header (10 bytes) should be zero.
    for i in 0..VIRTIO_NET_HDR_SIZE {
        assert_eq!(0, cpu.bus.read(rx_buffer_addr + i as u64, BYTE).unwrap());
    }

    let frame_base = rx_buffer_addr + VIRTIO_NET_HDR_SIZE as u64;
    // dst = original sender MAC
    for (i, b) in sender_mac.iter().enumerate() {
        assert_eq!(
            *b as u64,
            cpu.bus.read(frame_base + i as u64, BYTE).unwrap()
        );
    }
    // src = device MAC
    for (i, b) in DEVICE_MAC.iter().enumerate() {
        assert_eq!(
            *b as u64,
            cpu.bus.read(frame_base + 6 + i as u64, BYTE).unwrap()
        );
    }
    // ethertype preserved
    assert_eq!(
        ether_type[0] as u64,
        cpu.bus.read(frame_base + 12, BYTE).unwrap()
    );
    assert_eq!(
        ether_type[1] as u64,
        cpu.bus.read(frame_base + 13, BYTE).unwrap()
    );
    // body fixed string
    for (i, b) in BROADCAST_REPLY_BODY.iter().enumerate() {
        let addr = frame_base + 14 + i as u64;
        assert_eq!(*b as u64, cpu.bus.read(addr, BYTE).unwrap());
    }
}
