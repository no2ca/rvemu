//! The virtio_net module implements a virtio network device.
//!
//! The spec for Virtual I/O Device (VIRTIO) Version 1.1:
//! https://docs.oasis-open.org/virtio/virtio/v1.1/virtio-v1.1.html
//! 5.1 Network Device:
//! https://docs.oasis-open.org/virtio/virtio/v1.1/cs01/virtio-v1.1-cs01.html#x1-2100001

use std::cmp;
use std::collections::VecDeque;

use crate::bus::VIRTIO_NET_BASE;
use crate::cpu::{Cpu, BYTE, DOUBLEWORD, HALFWORD, WORD};
use crate::exception::Exception;

/// The interrupt request of virtio-net.
pub const VIRTIO_NET_IRQ: u64 = 2;

/// The size of `VRingDesc` struct.
const VRING_DESC_SIZE: u64 = 16;
/// The number of virtio descriptors. It must be a power of two.
const QUEUE_SIZE: u64 = 8;
/// The number of RX/TX queues supported by this implementation.
const QUEUE_COUNT: usize = 2;
/// Legacy virtio-net header size in bytes.
const VIRTIO_NET_HDR_SIZE: usize = 10;
/// Ethernet II header length.
const ETHERNET_HEADER_SIZE: usize = 14;
/// Ethernet broadcast address.
const BROADCAST_MAC: [u8; 6] = [0xff; 6];
/// Device MAC address exposed in config space.
const DEVICE_MAC: [u8; 6] = [0x52, 0x54, 0x00, 0x12, 0x34, 0x56];
/// ASCII response body for broadcast packets.
const BROADCAST_REPLY_BODY: &[u8] = b"rvemu: broadcast received";

/// This marks a buffer as continuing via the next field.
const VIRTQ_DESC_F_NEXT: u64 = 1;
/// This marks a buffer as device write-only (otherwise device read-only).
const VIRTQ_DESC_F_WRITE: u64 = 2;
/// This means the buffer contains a list of buffer descriptors.
const _VIRTQ_DESC_F_INDIRECT: u64 = 4;

// 4.2.2 MMIO Device Register Layout
// https://docs.oasis-open.org/virtio/virtio/v1.1/csprd01/virtio-v1.1-csprd01.html#x1-1460002
/// Magic value. Always return 0x74726976 (a Little Endian equivalent of the "virt" string).
const MAGIC: u64 = VIRTIO_NET_BASE;
const MAGIC_END: u64 = VIRTIO_NET_BASE + 0x3;

/// Device version number. 1 is legacy.
const VERSION: u64 = VIRTIO_NET_BASE + 0x4;
const VERSION_END: u64 = VIRTIO_NET_BASE + 0x7;

/// Virtio Subsystem Device ID. 1 is network, 2 is block device.
const DEVICE_ID: u64 = VIRTIO_NET_BASE + 0x8;
const DEVICE_ID_END: u64 = VIRTIO_NET_BASE + 0xb;

/// Virtio Subsystem Vendor ID. Always return 0x554d4551.
const VENDOR_ID: u64 = VIRTIO_NET_BASE + 0xc;
const VENDOR_ID_END: u64 = VIRTIO_NET_BASE + 0xf;

/// Flags representing features the device supports. Access to this register returns bits
/// DeviceFeaturesSel * 32 to (DeviceFeaturesSel * 32) + 31.
const DEVICE_FEATURES: u64 = VIRTIO_NET_BASE + 0x10;
const DEVICE_FEATURES_END: u64 = VIRTIO_NET_BASE + 0x13;

/// Device (host) features word selection.
const DEVICE_FEATURES_SEL: u64 = VIRTIO_NET_BASE + 0x14;
const DEVICE_FEATURES_SEL_END: u64 = VIRTIO_NET_BASE + 0x17;

/// Flags representing device features understood and activated by the driver. Access to this
/// register sets bits DriverFeaturesSel * 32 to (DriverFeaturesSel * 32) + 31.
const DRIVER_FEATURES: u64 = VIRTIO_NET_BASE + 0x20;
const DRIVER_FEATURES_END: u64 = VIRTIO_NET_BASE + 0x23;

/// Activated (guest) features word selection.
const DRIVER_FEATURES_SEL: u64 = VIRTIO_NET_BASE + 0x24;
const DRIVER_FEATURES_SEL_END: u64 = VIRTIO_NET_BASE + 0x27;

// 4.2.4 Legacy interface
// https://docs.oasis-open.org/virtio/virtio/v1.1/csprd01/virtio-v1.1-csprd01.html#x1-1560004
/// Guest page size.
const GUEST_PAGE_SIZE: u64 = VIRTIO_NET_BASE + 0x28;
const GUEST_PAGE_SIZE_END: u64 = VIRTIO_NET_BASE + 0x2b;

/// Virtual queue index.
const QUEUE_SEL: u64 = VIRTIO_NET_BASE + 0x30;
const QUEUE_SEL_END: u64 = VIRTIO_NET_BASE + 0x33;

/// Maximum virtual queue size.
const QUEUE_NUM_MAX: u64 = VIRTIO_NET_BASE + 0x34;
const QUEUE_NUM_MAX_END: u64 = VIRTIO_NET_BASE + 0x37;

/// Virtual queue size.
const QUEUE_NUM: u64 = VIRTIO_NET_BASE + 0x38;
const QUEUE_NUM_END: u64 = VIRTIO_NET_BASE + 0x3b;

/// Used Ring alignment in the virtual queue.
const QUEUE_ALIGN: u64 = VIRTIO_NET_BASE + 0x3c;
const QUEUE_ALIGN_END: u64 = VIRTIO_NET_BASE + 0x3f;

/// Guest physical page number of the virtual queue.
const QUEUE_PFN: u64 = VIRTIO_NET_BASE + 0x40;
const QUEUE_PFN_END: u64 = VIRTIO_NET_BASE + 0x43;

/// Queue notifier.
const QUEUE_NOTIFY: u64 = VIRTIO_NET_BASE + 0x50;
const QUEUE_NOTIFY_END: u64 = VIRTIO_NET_BASE + 0x53;

/// Interrupt status.
const INTERRUPT_STATUS: u64 = VIRTIO_NET_BASE + 0x60;
const INTERRUPT_STATUS_END: u64 = VIRTIO_NET_BASE + 0x63;

/// Interrupt acknowledge.
const INTERRUPT_ACK: u64 = VIRTIO_NET_BASE + 0x64;
const INTERRUPT_ACK_END: u64 = VIRTIO_NET_BASE + 0x67;

/// Device status.
const STATUS: u64 = VIRTIO_NET_BASE + 0x70;
const STATUS_END: u64 = VIRTIO_NET_BASE + 0x73;

/// Configuration space.
const CONFIG: u64 = VIRTIO_NET_BASE + 0x100;
const CONFIG_END: u64 = VIRTIO_NET_BASE + 0x107;

#[derive(Debug, Copy, Clone)]
struct VirtqueueAddr {
    /// The address that starts actual descriptors (16 bytes each).
    desc_addr: u64,
    /// The address that starts a ring of available descriptors.
    avail_addr: u64,
    /// The address that starts a ring of used descriptors.
    used_addr: u64,
}

impl VirtqueueAddr {
    fn new(queue_pfn: u32, guest_page_size: u32, queue_align: u32, queue_num: u32) -> Self {
        if queue_pfn == 0 || guest_page_size == 0 || queue_num == 0 {
            return Self {
                desc_addr: 0,
                avail_addr: 0,
                used_addr: 0,
            };
        }

        let base_addr = queue_pfn as u64 * guest_page_size as u64;
        let align = queue_align as u64;
        let size = queue_num as u64;
        let avail_ring_end = base_addr + (16 * size) + (6 + 2 * size);
        let used_addr = if align == 0 {
            avail_ring_end
        } else {
            (avail_ring_end.wrapping_div(align) + 1).wrapping_mul(align)
        };

        Self {
            desc_addr: base_addr,
            avail_addr: base_addr + 16 * size,
            used_addr,
        }
    }
}

#[derive(Debug)]
struct VirtqDesc {
    /// Address (guest-physical).
    addr: u64,
    /// Length.
    len: u64,
    /// The flags as indicated VIRTQ_DESC_F_NEXT/VIRTQ_DESC_F_WRITE/VIRTQ_DESC_F_INDIRECT.
    flags: u64,
    /// Next field if flags & NEXT.
    next: u64,
}

impl VirtqDesc {
    fn new(cpu: &mut Cpu, addr: u64) -> Result<Self, Exception> {
        Ok(Self {
            addr: cpu.bus.read(addr, DOUBLEWORD)?,
            len: cpu.bus.read(addr.wrapping_add(8), WORD)?,
            flags: cpu.bus.read(addr.wrapping_add(12), HALFWORD)?,
            next: cpu.bus.read(addr.wrapping_add(14), HALFWORD)?,
        })
    }
}

#[derive(Debug)]
struct VirtqAvail {
    idx: u16,
    ring_start_addr: u64,
}

impl VirtqAvail {
    fn new(cpu: &mut Cpu, addr: u64) -> Result<Self, Exception> {
        Ok(Self {
            idx: cpu.bus.read(addr.wrapping_add(2), HALFWORD)? as u16,
            ring_start_addr: addr.wrapping_add(4),
        })
    }
}

/// Paravirtualized network IO device over virtio-mmio.
pub struct VirtioNet {
    device_features: [u32; 2],
    device_features_sel: u32,
    driver_features: [u32; 2],
    driver_features_sel: u32,
    guest_page_size: u32,
    queue_sel: u32,
    queue_num: [u32; QUEUE_COUNT],
    queue_align: [u32; QUEUE_COUNT],
    queue_pfn: [u32; QUEUE_COUNT],
    queue_notify: u32,
    last_notified_queue: u32,
    interrupt_status: u32,
    status: u32,
    config: [u8; 8],
    virtqueue: [Option<VirtqueueAddr>; QUEUE_COUNT],
    avail_idx: [u16; QUEUE_COUNT],
    used_idx: [u16; QUEUE_COUNT],
    rx_queue: VecDeque<Vec<u8>>,
    tx_queue: VecDeque<Vec<u8>>,
}

impl VirtioNet {
    /// Creates a new virtio-net object.
    pub fn new() -> Self {
        let mut config = [0; 8];

        // struct virtio_net_config {
        //   u8 mac[6];
        //   le16 status;
        // }
        config[..6].copy_from_slice(&DEVICE_MAC);
        // VIRTIO_NET_S_LINK_UP (bit 0)
        config[6] = 0x1;

        Self {
            device_features: VirtioNet::device_features(),
            device_features_sel: 0,
            driver_features: [0; 2],
            driver_features_sel: 0,
            guest_page_size: 0,
            queue_sel: 0,
            queue_num: [0; QUEUE_COUNT],
            queue_align: [0x1000; QUEUE_COUNT],
            queue_pfn: [0; QUEUE_COUNT],
            queue_notify: u32::MAX,
            last_notified_queue: 0,
            interrupt_status: 0,
            status: 0,
            config,
            virtqueue: [None; QUEUE_COUNT],
            avail_idx: [0; QUEUE_COUNT],
            used_idx: [0; QUEUE_COUNT],
            rx_queue: VecDeque::new(),
            tx_queue: VecDeque::new(),
        }
    }

    /// Returns device features.
    fn device_features() -> [u32; 2] {
        let mut features = [0; 2];

        // VIRTIO_NET_F_MAC (bit 5): mac field is available in config space.
        features[0] |= 1 << 5;
        // VIRTIO_NET_F_STATUS (bit 16): status field is available in config space.
        features[0] |= 1 << 16;
        // VIRTIO_F_IN_ORDER (bit 35).
        features[1] |= 1 << 3;

        features
    }

    /// Initializes a virtqueue address from current queue registers.
    fn init_virtqueue(&mut self, queue_index: usize) {
        if queue_index >= QUEUE_COUNT {
            return;
        }
        self.virtqueue[queue_index] = Some(VirtqueueAddr::new(
            self.queue_pfn[queue_index],
            self.guest_page_size,
            self.queue_align[queue_index],
            self.queue_num[queue_index],
        ));
    }

    /// Gets `VirtqueueAddr` for `queue_index`. If not initialized, computes from queue registers.
    fn virtqueue(&self, queue_index: usize) -> VirtqueueAddr {
        if queue_index >= QUEUE_COUNT {
            return VirtqueueAddr {
                desc_addr: 0,
                avail_addr: 0,
                used_addr: 0,
            };
        }

        match self.virtqueue[queue_index] {
            Some(queue) => queue,
            None => VirtqueueAddr::new(
                self.queue_pfn[queue_index],
                self.guest_page_size,
                self.queue_align[queue_index],
                self.queue_num[queue_index],
            ),
        }
    }

    /// Resets the device when `status` is written to 0.
    fn reset(&mut self) {
        self.queue_notify = u32::MAX;
        self.last_notified_queue = 0;
        self.interrupt_status = 0;
        self.queue_sel = 0;
        self.queue_num = [0; QUEUE_COUNT];
        self.queue_align = [0x1000; QUEUE_COUNT];
        self.queue_pfn = [0; QUEUE_COUNT];
        self.virtqueue = [None; QUEUE_COUNT];
        self.avail_idx = [0; QUEUE_COUNT];
        self.used_idx = [0; QUEUE_COUNT];
        self.rx_queue.clear();
        self.tx_queue.clear();
    }

    /// Returns true if an interrupt is pending.
    pub fn is_interrupting(&mut self) -> bool {
        if self.queue_notify != u32::MAX {
            self.last_notified_queue = self.queue_notify;
            self.queue_notify = u32::MAX;
            return true;
        }
        false
    }

    /// Pushes an incoming payload packet into the RX queue.
    pub fn push_rx_packet(&mut self, payload: Vec<u8>) {
        self.rx_queue.push_back(payload);
    }

    /// Pops one packet transmitted by the guest.
    pub fn pop_tx_packet(&mut self) -> Option<Vec<u8>> {
        self.tx_queue.pop_front()
    }

    /// Loads `size`-bit data from a register located at `addr` in the virtio network device.
    pub fn read(&self, addr: u64, size: u8) -> Result<u64, Exception> {
        let (reg, offset) = match addr {
            MAGIC..=MAGIC_END => (0x74726976, addr - MAGIC),
            VERSION..=VERSION_END => (0x1, addr - VERSION),
            // Network device.
            DEVICE_ID..=DEVICE_ID_END => (0x1, addr - DEVICE_ID),
            VENDOR_ID..=VENDOR_ID_END => (0x554d4551, addr - VENDOR_ID),
            DEVICE_FEATURES..=DEVICE_FEATURES_END => (
                self.device_features[self.device_features_sel as usize],
                addr - DEVICE_FEATURES,
            ),
            QUEUE_NUM_MAX..=QUEUE_NUM_MAX_END => {
                let max = if self.queue_sel < QUEUE_COUNT as u32 {
                    QUEUE_SIZE as u32
                } else {
                    0
                };
                (max, addr - QUEUE_NUM_MAX)
            }
            QUEUE_PFN..=QUEUE_PFN_END => {
                let pfn = if self.queue_sel < QUEUE_COUNT as u32 {
                    self.queue_pfn[self.queue_sel as usize]
                } else {
                    0
                };
                (pfn, addr - QUEUE_PFN)
            }
            INTERRUPT_STATUS..=INTERRUPT_STATUS_END => {
                (self.interrupt_status, addr - INTERRUPT_STATUS)
            }
            STATUS..=STATUS_END => (self.status, addr - STATUS),
            CONFIG..=CONFIG_END => {
                if size != BYTE {
                    return Err(Exception::StoreAMOAccessFault);
                }
                let index = addr - CONFIG;
                (self.config[index as usize] as u32, 0)
            }
            _ => return Err(Exception::LoadAccessFault),
        };

        let value = match size {
            BYTE => (reg >> (offset * 8)) & 0xff,
            HALFWORD => (reg >> (offset * 8)) & 0xffff,
            WORD => (reg >> (offset * 8)) & 0xffff_ffff,
            _ => return Err(Exception::LoadAccessFault),
        };

        Ok(value as u64)
    }

    /// Stores `size`-bit data to a register located at `addr` in the virtio network device.
    pub fn write(&mut self, addr: u64, value: u32, size: u8) -> Result<(), Exception> {
        match addr {
            DEVICE_FEATURES_SEL..=DEVICE_FEATURES_SEL_END => {
                self.device_features_sel = update_register(
                    self.device_features_sel,
                    addr - DEVICE_FEATURES_SEL,
                    value,
                    size,
                )?;
            }
            DRIVER_FEATURES..=DRIVER_FEATURES_END => {
                if self.driver_features_sel < self.driver_features.len() as u32 {
                    let index = self.driver_features_sel as usize;
                    self.driver_features[index] = update_register(
                        self.driver_features[index],
                        addr - DRIVER_FEATURES,
                        value,
                        size,
                    )?;
                }
            }
            DRIVER_FEATURES_SEL..=DRIVER_FEATURES_SEL_END => {
                self.driver_features_sel = update_register(
                    self.driver_features_sel,
                    addr - DRIVER_FEATURES_SEL,
                    value,
                    size,
                )?;
            }
            GUEST_PAGE_SIZE..=GUEST_PAGE_SIZE_END => {
                self.guest_page_size =
                    update_register(self.guest_page_size, addr - GUEST_PAGE_SIZE, value, size)?;
            }
            QUEUE_SEL..=QUEUE_SEL_END => {
                self.queue_sel = update_register(self.queue_sel, addr - QUEUE_SEL, value, size)?;
            }
            QUEUE_NUM..=QUEUE_NUM_END => {
                if self.queue_sel < QUEUE_COUNT as u32 {
                    let index = self.queue_sel as usize;
                    self.queue_num[index] =
                        update_register(self.queue_num[index], addr - QUEUE_NUM, value, size)?;
                }
            }
            QUEUE_ALIGN..=QUEUE_ALIGN_END => {
                if self.queue_sel < QUEUE_COUNT as u32 {
                    let index = self.queue_sel as usize;
                    self.queue_align[index] =
                        update_register(self.queue_align[index], addr - QUEUE_ALIGN, value, size)?;
                }
            }
            QUEUE_PFN..=QUEUE_PFN_END => {
                if self.queue_sel < QUEUE_COUNT as u32 {
                    let index = self.queue_sel as usize;
                    self.queue_pfn[index] =
                        update_register(self.queue_pfn[index], addr - QUEUE_PFN, value, size)?;
                    self.init_virtqueue(index);
                }
            }
            QUEUE_NOTIFY..=QUEUE_NOTIFY_END => {
                self.queue_notify =
                    update_register(self.queue_notify, addr - QUEUE_NOTIFY, value, size)?;
            }
            INTERRUPT_ACK..=INTERRUPT_ACK_END => {
                self.interrupt_status =
                    update_register(self.interrupt_status, addr - INTERRUPT_ACK, value, size)?;
            }
            STATUS..=STATUS_END => {
                self.status = update_register(self.status, addr - STATUS, value, size)?;
                if self.status == 0 {
                    self.reset();
                }
                if self.status & 0x4 != 0 {
                    for queue_index in 0..QUEUE_COUNT {
                        self.init_virtqueue(queue_index);
                    }
                }
                if self.status & 128 != 0 {
                    panic!("virtio-net: device status FAILED");
                }
            }
            CONFIG..=CONFIG_END => {
                if size != BYTE {
                    return Err(Exception::StoreAMOAccessFault);
                }
                let index = (addr - CONFIG) as usize;
                self.config[index] = (value & 0xff) as u8;
            }
            _ => return Err(Exception::StoreAMOAccessFault),
        }

        Ok(())
    }

    fn descriptor_chain(
        cpu: &mut Cpu,
        desc_addr: u64,
        head_index: u64,
    ) -> Result<Vec<VirtqDesc>, Exception> {
        let mut descs = Vec::new();
        let mut current = head_index;

        for _ in 0..QUEUE_SIZE {
            let desc = VirtqDesc::new(cpu, desc_addr + VRING_DESC_SIZE * current)?;
            let has_next = (desc.flags & VIRTQ_DESC_F_NEXT) != 0;
            current = desc.next;
            descs.push(desc);
            if !has_next {
                return Ok(descs);
            }
        }

        Err(Exception::StoreAMOAccessFault)
    }

    fn read_tx_payload(cpu: &mut Cpu, descs: &[VirtqDesc]) -> Result<Vec<u8>, Exception> {
        let mut packet = Vec::new();

        for desc in descs {
            if (desc.flags & VIRTQ_DESC_F_WRITE) != 0 {
                continue;
            }
            for i in 0..desc.len {
                packet.push(cpu.bus.read(desc.addr + i, BYTE)? as u8);
            }
        }

        if packet.len() <= VIRTIO_NET_HDR_SIZE {
            return Ok(Vec::new());
        }

        Ok(packet[VIRTIO_NET_HDR_SIZE..].to_vec())
    }

    fn write_rx_frame(cpu: &mut Cpu, descs: &[VirtqDesc], frame: &[u8]) -> Result<u32, Exception> {
        let mut written = 0usize;

        for desc in descs {
            if (desc.flags & VIRTQ_DESC_F_WRITE) == 0 {
                continue;
            }

            let remaining = frame.len().saturating_sub(written);
            if remaining == 0 {
                break;
            }

            let write_len = cmp::min(desc.len as usize, remaining);
            for i in 0..write_len {
                cpu.bus
                    .write(desc.addr + i as u64, frame[written + i] as u64, BYTE)?;
            }
            written += write_len;
        }

        Ok(written as u32)
    }

    /// Builds a response frame for incoming TX payloads.
    ///
    /// If destination MAC is broadcast, return a synthesized Ethernet frame with a fixed string
    /// body. Otherwise return the original payload for loopback behavior.
    fn response_payload(payload: &[u8]) -> Vec<u8> {
        if payload.len() < ETHERNET_HEADER_SIZE {
            return payload.to_vec();
        }

        // Ethernet II:
        //   dst[0..6], src[6..12], ether_type[12..14], payload[14..]
        if payload[..6] != BROADCAST_MAC {
            return payload.to_vec();
        }

        let mut frame = Vec::with_capacity(ETHERNET_HEADER_SIZE + BROADCAST_REPLY_BODY.len());
        // dst = original source
        frame.extend_from_slice(&payload[6..12]);
        // src = virtio-net device mac
        frame.extend_from_slice(&DEVICE_MAC);
        // preserve ether type
        frame.extend_from_slice(&payload[12..14]);
        // body
        frame.extend_from_slice(BROADCAST_REPLY_BODY);
        frame
    }

    fn process_queue(cpu: &mut Cpu, queue_index: usize) -> Result<(), Exception> {
        let virtq = cpu.bus.virtio_net.virtqueue(queue_index);
        if virtq.desc_addr == 0 {
            return Ok(());
        }

        let avail = VirtqAvail::new(cpu, virtq.avail_addr)?;

        while cpu.bus.virtio_net.avail_idx[queue_index] != avail.idx {
            let available_index = cpu.bus.virtio_net.avail_idx[queue_index] as u64 % QUEUE_SIZE;
            let ring_addr = avail.ring_start_addr + available_index * 2;
            let head_index = cpu.bus.read(ring_addr, HALFWORD)?;
            let descs = VirtioNet::descriptor_chain(cpu, virtq.desc_addr, head_index)?;

            let used_len = if queue_index == 1 {
                // TX queue: guest -> device.
                // Broadcast packets are answered with a fixed response frame.
                // Non-broadcast packets are looped back as-is.
                let payload = VirtioNet::read_tx_payload(cpu, &descs)?;
                if !payload.is_empty() {
                    let rx_payload = VirtioNet::response_payload(&payload);
                    cpu.bus.virtio_net.tx_queue.push_back(payload);
                    cpu.bus.virtio_net.rx_queue.push_back(rx_payload);
                }
                0
            } else {
                // RX queue: device -> guest. Prepend virtio-net header and copy payload.
                let payload = cpu.bus.virtio_net.rx_queue.pop_front().unwrap_or_default();
                let mut frame = vec![0; VIRTIO_NET_HDR_SIZE];
                frame.extend_from_slice(&payload);
                VirtioNet::write_rx_frame(cpu, &descs, &frame)?
            };

            let used_index = cpu.bus.virtio_net.used_idx[queue_index] as u64 % QUEUE_SIZE;
            let used_elem_addr = virtq.used_addr + 4 + used_index * 8;
            cpu.bus.write(used_elem_addr, head_index, WORD)?;
            cpu.bus
                .write(used_elem_addr.wrapping_add(4), used_len as u64, WORD)?;

            cpu.bus.virtio_net.used_idx[queue_index] =
                cpu.bus.virtio_net.used_idx[queue_index].wrapping_add(1);
            cpu.bus.virtio_net.avail_idx[queue_index] =
                cpu.bus.virtio_net.avail_idx[queue_index].wrapping_add(1);

            cpu.bus.write(
                virtq.used_addr.wrapping_add(2),
                cpu.bus.virtio_net.used_idx[queue_index] as u64,
                HALFWORD,
            )?;
        }

        Ok(())
    }

    /// Accesses the network queues via virtio. This is an associated function which takes a `cpu`
    /// object to read and write with a memory directly (DMA).
    pub fn net_access(cpu: &mut Cpu) -> Result<(), Exception> {
        // Used Buffer Notification (bit 0).
        cpu.bus.virtio_net.interrupt_status |= 0x1;

        let queue_index = cpu.bus.virtio_net.last_notified_queue as usize;
        if queue_index >= QUEUE_COUNT {
            return Ok(());
        }

        VirtioNet::process_queue(cpu, queue_index)
    }
}

fn update_register(mut reg: u32, offset: u64, value: u32, size: u8) -> Result<u32, Exception> {
    match size {
        BYTE => {
            reg &= !(0xff << (offset * 8));
            reg |= (value & 0xff) << (offset * 8);
        }
        HALFWORD => {
            reg &= !(0xffff << (offset * 8));
            reg |= (value & 0xffff) << (offset * 8);
        }
        WORD => {
            reg = value;
        }
        _ => return Err(Exception::StoreAMOAccessFault),
    }

    Ok(reg)
}
