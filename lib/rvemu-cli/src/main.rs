use clap::{App, Arg};
use std::fs::File;
use std::io;
use std::io::prelude::*;
use std::iter::FromIterator;
use std::time::{Duration, Instant};

use rvemu_core::bus::DRAM_BASE;
use rvemu_core::cpu::Cpu;
use rvemu_core::emulator::Emulator;
use rvemu_core::exception::Trap;

/// Output current registers to the console.
fn dump_registers(cpu: &Cpu) {
    println!("-------------------------------------------------------------------------------------------");
    println!("{}", cpu.xregs);
    println!("-------------------------------------------------------------------------------------------");
    println!("{}", cpu.fregs);
    println!("-------------------------------------------------------------------------------------------");
    println!("{}", cpu.state);
    println!("-------------------------------------------------------------------------------------------");
    println!("pc: {:#x}", cpu.pc);
}

/// Output the count of each instruction executed.
fn dump_count(cpu: &Cpu) {
    if cpu.is_count {
        println!("===========================================================================================");
        let mut sorted_counter = Vec::from_iter(&cpu.inst_counter);
        sorted_counter.sort_by(|&(_, a), &(_, b)| b.cmp(&a));
        for (inst, count) in sorted_counter.iter() {
            println!("{}, {}", inst, count);
        }
        println!("===========================================================================================");
    }
}

fn build_broadcast_frame(payload: &[u8]) -> Vec<u8> {
    let mut frame = Vec::with_capacity(14 + payload.len());
    // dst mac: ff:ff:ff:ff:ff:ff
    frame.extend_from_slice(&[0xff; 6]);
    // src mac: 02:00:00:00:00:01
    frame.extend_from_slice(&[0x02, 0x00, 0x00, 0x00, 0x00, 0x01]);
    // ethertype: 0x0800 (IPv4-ish for demo)
    frame.extend_from_slice(&[0x08, 0x00]);
    frame.extend_from_slice(payload);
    frame
}

fn start_with_periodic_host_packets(emu: &mut Emulator, period: Duration) {
    let mut tick: u64 = 0;
    let mut next_send = Instant::now() + period;

    if emu.is_debug || emu.cpu.is_count {
        println!("net-demo mode is enabled; injecting host packets periodically");
    }

    loop {
        // Run a cycle on peripheral devices.
        emu.cpu.devices_increment();

        let now = Instant::now();
        if now >= next_send {
            let msg = format!("host-tick-{}", tick);
            let frame = build_broadcast_frame(msg.as_bytes());
            emu.cpu.bus.virtio_net.inject_rx_packet(frame);
            tick = tick.wrapping_add(1);
            next_send = now + period;
        }

        // Take an interrupt.
        match emu.cpu.check_pending_interrupt() {
            Some(interrupt) => interrupt.take_trap(&mut emu.cpu),
            None => {}
        }

        // Execute an instruction.
        let trap = match emu.cpu.execute() {
            Ok(_) => Trap::Requested,
            Err(exception) => exception.take_trap(&mut emu.cpu),
        };

        match trap {
            Trap::Fatal => {
                println!("pc: {:#x}, trap {:#?}", emu.cpu.pc, trap);
                return;
            }
            _ => {}
        }
    }
}

/// Main function of RISC-V emulator for the CLI version.
fn main() -> io::Result<()> {
    let matches = App::new("rvemu: RISC-V emulator")
        .version("0.0.1")
        .author("Asami Doi <@d0iasm>")
        .arg(
            Arg::with_name("kernel")
                .short("k")
                .long("kernel")
                .takes_value(true)
                .required(true)
                .help("A kernel ELF image without headers"),
        )
        .arg(
            Arg::with_name("file")
                .short("f")
                .long("file")
                .takes_value(true)
                .help("A raw disk image"),
        )
        .arg(
            Arg::with_name("debug")
                .short("d")
                .long("debug")
                .help("Enables to output debug messages"),
        )
        .arg(
            Arg::with_name("count")
                .short("c")
                .long("count")
                .help("Enables to count each instruction executed"),
        )
        .arg(
            Arg::with_name("net-demo")
                .long("net-demo")
                .help("Injects one host->guest virtio-net frame every few seconds"),
        )
        .get_matches();

    let mut kernel_file = File::open(
        &matches
            .value_of("kernel")
            .expect("failed to get a kernel file from a command option"),
    )?;
    let mut kernel_data = Vec::new();
    kernel_file.read_to_end(&mut kernel_data)?;

    let mut img_data = Vec::new();
    if let Some(img_file) = matches.value_of("file") {
        File::open(img_file)?.read_to_end(&mut img_data)?;
    }

    let mut emu = Emulator::new();

    emu.initialize_dram(kernel_data);
    emu.initialize_disk(img_data);
    emu.initialize_pc(DRAM_BASE);

    if matches.occurrences_of("debug") == 1 {
        emu.is_debug = true;
    }

    if matches.occurrences_of("count") == 1 {
        emu.cpu.is_count = true;
    }

    if matches.occurrences_of("net-demo") == 1 {
        start_with_periodic_host_packets(&mut emu, Duration::from_secs(1));
    } else {
        emu.start();
    }

    dump_registers(&emu.cpu);
    dump_count(&emu.cpu);

    Ok(())
}
