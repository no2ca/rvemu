	.file	"virtio_net_min.c"
	.option pic
	.attribute arch, "rv64i2p1_m2p0_a2p1_f2p2_d2p2_c2p0_zicsr2p0_zifencei2p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
#APP
	.globl _start
_start:
  li sp, 0xc0000000
  call main
1:
  j 1b

#NO_APP
	.local	rx_queue_pages
	.comm	rx_queue_pages,8192,4096
	.local	tx_queue_pages
	.comm	tx_queue_pages,8192,4096
	.section	.data.rel.ro.local,"aw"
	.align	3
	.type	rx_desc, @object
	.size	rx_desc, 8
rx_desc:
	.dword	rx_queue_pages
	.align	3
	.type	rx_avail, @object
	.size	rx_avail, 8
rx_avail:
	.dword	rx_queue_pages+128
	.align	3
	.type	rx_used, @object
	.size	rx_used, 8
rx_used:
	.dword	rx_queue_pages+4096
	.align	3
	.type	tx_desc, @object
	.size	tx_desc, 8
tx_desc:
	.dword	tx_queue_pages
	.align	3
	.type	tx_avail, @object
	.size	tx_avail, 8
tx_avail:
	.dword	tx_queue_pages+128
	.align	3
	.type	tx_used, @object
	.size	tx_used, 8
tx_used:
	.dword	tx_queue_pages+4096
	.local	tx_frame
	.comm	tx_frame,14,8
	.local	rx_frame
	.comm	rx_frame,74,8
	.text
	.align	1
	.type	uart, @function
uart:
.LFB0:
	.cfi_startproc
	addi	sp,sp,-16
	.cfi_def_cfa_offset 16
	sd	s0,8(sp)
	.cfi_offset 8, -8
	addi	s0,sp,16
	.cfi_def_cfa 8, 0
	li	a5,268435456
	mv	a0,a5
	ld	s0,8(sp)
	.cfi_restore 8
	.cfi_def_cfa 2, 16
	addi	sp,sp,16
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE0:
	.size	uart, .-uart
	.align	1
	.type	uart_putc, @function
uart_putc:
.LFB1:
	.cfi_startproc
	addi	sp,sp,-48
	.cfi_def_cfa_offset 48
	sd	ra,40(sp)
	sd	s0,32(sp)
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	addi	s0,sp,48
	.cfi_def_cfa 8, 0
	mv	a5,a0
	sb	a5,-33(s0)
	call	uart
	sd	a0,-24(s0)
	nop
.L4:
	ld	a5,-24(s0)
	addi	a5,a5,5
	lbu	a5,0(a5)
	andi	a5,a5,0xff
	sext.w	a5,a5
	andi	a5,a5,32
	sext.w	a5,a5
	beq	a5,zero,.L4
	ld	a5,-24(s0)
	lbu	a4,-33(s0)
	sb	a4,0(a5)
	nop
	ld	ra,40(sp)
	.cfi_restore 1
	ld	s0,32(sp)
	.cfi_restore 8
	.cfi_def_cfa 2, 48
	addi	sp,sp,48
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE1:
	.size	uart_putc, .-uart_putc
	.align	1
	.type	uart_puts, @function
uart_puts:
.LFB2:
	.cfi_startproc
	addi	sp,sp,-32
	.cfi_def_cfa_offset 32
	sd	ra,24(sp)
	sd	s0,16(sp)
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	addi	s0,sp,32
	.cfi_def_cfa 8, 0
	sd	a0,-24(s0)
	j	.L6
.L7:
	ld	a5,-24(s0)
	lbu	a5,0(a5)
	mv	a0,a5
	call	uart_putc
	ld	a5,-24(s0)
	addi	a5,a5,1
	sd	a5,-24(s0)
.L6:
	ld	a5,-24(s0)
	lbu	a5,0(a5)
	bne	a5,zero,.L7
	nop
	nop
	ld	ra,24(sp)
	.cfi_restore 1
	ld	s0,16(sp)
	.cfi_restore 8
	.cfi_def_cfa 2, 32
	addi	sp,sp,32
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE2:
	.size	uart_puts, .-uart_puts
	.section	.rodata
	.align	3
.LC0:
	.string	"[virtio-net-min] FAIL: "
	.align	3
.LC1:
	.string	"\n"
	.text
	.align	1
	.type	fail, @function
fail:
.LFB3:
	.cfi_startproc
	addi	sp,sp,-32
	.cfi_def_cfa_offset 32
	sd	ra,24(sp)
	sd	s0,16(sp)
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	addi	s0,sp,32
	.cfi_def_cfa 8, 0
	sd	a0,-24(s0)
	lla	a0,.LC0
	call	uart_puts
	ld	a0,-24(s0)
	call	uart_puts
	lla	a0,.LC1
	call	uart_puts
.L9:
	nop
	j	.L9
	.cfi_endproc
.LFE3:
	.size	fail, .-fail
	.align	1
	.type	mmio_read32, @function
mmio_read32:
.LFB4:
	.cfi_startproc
	addi	sp,sp,-32
	.cfi_def_cfa_offset 32
	sd	s0,24(sp)
	.cfi_offset 8, -8
	addi	s0,sp,32
	.cfi_def_cfa 8, 0
	sd	a0,-24(s0)
	ld	a4,-24(s0)
	li	a5,268443648
	add	a5,a4,a5
	lw	a5,0(a5)
	sext.w	a5,a5
	mv	a0,a5
	ld	s0,24(sp)
	.cfi_restore 8
	.cfi_def_cfa 2, 32
	addi	sp,sp,32
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE4:
	.size	mmio_read32, .-mmio_read32
	.align	1
	.type	mmio_write32, @function
mmio_write32:
.LFB5:
	.cfi_startproc
	addi	sp,sp,-32
	.cfi_def_cfa_offset 32
	sd	s0,24(sp)
	.cfi_offset 8, -8
	addi	s0,sp,32
	.cfi_def_cfa 8, 0
	sd	a0,-24(s0)
	mv	a5,a1
	sw	a5,-28(s0)
	ld	a4,-24(s0)
	li	a5,268443648
	add	a5,a4,a5
	mv	a4,a5
	lw	a5,-28(s0)
	sw	a5,0(a4)
	nop
	ld	s0,24(sp)
	.cfi_restore 8
	.cfi_def_cfa 2, 32
	addi	sp,sp,32
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE5:
	.size	mmio_write32, .-mmio_write32
	.align	1
	.type	fence_rw_rw, @function
fence_rw_rw:
.LFB6:
	.cfi_startproc
	addi	sp,sp,-16
	.cfi_def_cfa_offset 16
	sd	s0,8(sp)
	.cfi_offset 8, -8
	addi	s0,sp,16
	.cfi_def_cfa 8, 0
#APP
# 127 "virtio_net_min.c" 1
	fence rw, rw
# 0 "" 2
#NO_APP
	nop
	ld	s0,8(sp)
	.cfi_restore 8
	.cfi_def_cfa 2, 16
	addi	sp,sp,16
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE6:
	.size	fence_rw_rw, .-fence_rw_rw
	.align	1
	.type	enable_mstatus_mie, @function
enable_mstatus_mie:
.LFB7:
	.cfi_startproc
	addi	sp,sp,-16
	.cfi_def_cfa_offset 16
	sd	s0,8(sp)
	.cfi_offset 8, -8
	addi	s0,sp,16
	.cfi_def_cfa 8, 0
	li	a5,8
#APP
# 133 "virtio_net_min.c" 1
	csrs mstatus, a5
# 0 "" 2
#NO_APP
	nop
	ld	s0,8(sp)
	.cfi_restore 8
	.cfi_def_cfa 2, 16
	addi	sp,sp,16
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE7:
	.size	enable_mstatus_mie, .-enable_mstatus_mie
	.align	1
	.type	disable_mie_bits, @function
disable_mie_bits:
.LFB8:
	.cfi_startproc
	addi	sp,sp,-16
	.cfi_def_cfa_offset 16
	sd	s0,8(sp)
	.cfi_offset 8, -8
	addi	s0,sp,16
	.cfi_def_cfa 8, 0
	li	a5,0
#APP
# 138 "virtio_net_min.c" 1
	csrw mie, a5
# 0 "" 2
#NO_APP
	nop
	ld	s0,8(sp)
	.cfi_restore 8
	.cfi_def_cfa 2, 16
	addi	sp,sp,16
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE8:
	.size	disable_mie_bits, .-disable_mie_bits
	.align	1
	.type	wait_used_idx, @function
wait_used_idx:
.LFB9:
	.cfi_startproc
	addi	sp,sp,-48
	.cfi_def_cfa_offset 48
	sd	s0,40(sp)
	.cfi_offset 8, -8
	addi	s0,sp,48
	.cfi_def_cfa 8, 0
	sd	a0,-40(s0)
	mv	a5,a1
	sh	a5,-42(s0)
	li	a5,20000768
	addi	a5,a5,-768
	sw	a5,-20(s0)
	j	.L17
.L20:
	ld	a5,-40(s0)
	lhu	a5,0(a5)
	slli	a5,a5,48
	srli	a5,a5,48
	lhu	a4,-42(s0)
	sext.w	a4,a4
	sext.w	a5,a5
	bne	a4,a5,.L18
	li	a5,0
	j	.L19
.L18:
	lw	a5,-20(s0)
	addiw	a5,a5,-1
	sw	a5,-20(s0)
.L17:
	lw	a5,-20(s0)
	sext.w	a5,a5
	bne	a5,zero,.L20
	li	a5,-1
.L19:
	mv	a0,a5
	ld	s0,40(sp)
	.cfi_restore 8
	.cfi_def_cfa 2, 48
	addi	sp,sp,48
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE9:
	.size	wait_used_idx, .-wait_used_idx
	.section	.rodata
	.align	3
.LC2:
	.string	"queue_num_max is too small"
	.text
	.align	1
	.type	setup_queue, @function
setup_queue:
.LFB10:
	.cfi_startproc
	addi	sp,sp,-48
	.cfi_def_cfa_offset 48
	sd	ra,40(sp)
	sd	s0,32(sp)
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	addi	s0,sp,48
	.cfi_def_cfa 8, 0
	mv	a5,a0
	sd	a1,-48(s0)
	sw	a5,-36(s0)
	lw	a5,-36(s0)
	mv	a1,a5
	li	a0,48
	call	mmio_write32
	li	a0,52
	call	mmio_read32
	mv	a5,a0
	sw	a5,-20(s0)
	lw	a5,-20(s0)
	sext.w	a4,a5
	li	a5,7
	bgtu	a4,a5,.L22
	lla	a0,.LC2
	call	fail
.L22:
	li	a1,8
	li	a0,56
	call	mmio_write32
	li	a1,4096
	li	a0,60
	call	mmio_write32
	ld	a5,-48(s0)
	srli	a5,a5,12
	sext.w	a5,a5
	mv	a1,a5
	li	a0,64
	call	mmio_write32
	nop
	ld	ra,40(sp)
	.cfi_restore 1
	ld	s0,32(sp)
	.cfi_restore 8
	.cfi_def_cfa 2, 48
	addi	sp,sp,48
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE10:
	.size	setup_queue, .-setup_queue
	.section	.rodata
	.align	3
.LC3:
	.string	"bad magic"
	.align	3
.LC4:
	.string	"bad version"
	.align	3
.LC5:
	.string	"bad device id"
	.align	3
.LC6:
	.string	"bad vendor id"
	.align	3
.LC7:
	.string	"FEATURES_OK rejected"
	.text
	.align	1
	.type	init_virtio_net, @function
init_virtio_net:
.LFB11:
	.cfi_startproc
	addi	sp,sp,-32
	.cfi_def_cfa_offset 32
	sd	ra,24(sp)
	sd	s0,16(sp)
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	addi	s0,sp,32
	.cfi_def_cfa 8, 0
	li	a0,0
	call	mmio_read32
	mv	a5,a0
	sext.w	a5,a5
	mv	a4,a5
	li	a5,1953656832
	addi	a5,a5,-1674
	beq	a4,a5,.L24
	lla	a0,.LC3
	call	fail
.L24:
	li	a0,4
	call	mmio_read32
	mv	a5,a0
	sext.w	a5,a5
	mv	a4,a5
	li	a5,1
	beq	a4,a5,.L25
	lla	a0,.LC4
	call	fail
.L25:
	li	a0,8
	call	mmio_read32
	mv	a5,a0
	sext.w	a5,a5
	mv	a4,a5
	li	a5,1
	beq	a4,a5,.L26
	lla	a0,.LC5
	call	fail
.L26:
	li	a0,12
	call	mmio_read32
	mv	a5,a0
	sext.w	a5,a5
	mv	a4,a5
	li	a5,1431126016
	addi	a5,a5,1361
	beq	a4,a5,.L27
	lla	a0,.LC6
	call	fail
.L27:
	li	a1,0
	li	a0,112
	call	mmio_write32
	li	a5,1
	sw	a5,-20(s0)
	lw	a5,-20(s0)
	mv	a1,a5
	li	a0,112
	call	mmio_write32
	lw	a5,-20(s0)
	ori	a5,a5,2
	sw	a5,-20(s0)
	lw	a5,-20(s0)
	mv	a1,a5
	li	a0,112
	call	mmio_write32
	li	a1,0
	li	a0,20
	call	mmio_write32
	li	a0,16
	call	mmio_read32
	mv	a5,a0
	sw	a5,-24(s0)
	li	a1,1
	li	a0,20
	call	mmio_write32
	li	a0,16
	call	mmio_read32
	mv	a5,a0
	sw	a5,-28(s0)
	li	a1,0
	li	a0,36
	call	mmio_write32
	lw	a5,-24(s0)
	mv	a1,a5
	li	a0,32
	call	mmio_write32
	li	a1,1
	li	a0,36
	call	mmio_write32
	lw	a5,-28(s0)
	mv	a1,a5
	li	a0,32
	call	mmio_write32
	lw	a5,-20(s0)
	ori	a5,a5,8
	sw	a5,-20(s0)
	lw	a5,-20(s0)
	mv	a1,a5
	li	a0,112
	call	mmio_write32
	li	a0,112
	call	mmio_read32
	mv	a5,a0
	sext.w	a5,a5
	andi	a5,a5,8
	sext.w	a5,a5
	bne	a5,zero,.L28
	lla	a0,.LC7
	call	fail
.L28:
	li	a1,4096
	li	a0,40
	call	mmio_write32
	lla	a1,rx_queue_pages
	li	a0,0
	call	setup_queue
	lla	a1,tx_queue_pages
	li	a0,1
	call	setup_queue
	lw	a5,-20(s0)
	ori	a5,a5,4
	sw	a5,-20(s0)
	lw	a5,-20(s0)
	mv	a1,a5
	li	a0,112
	call	mmio_write32
	nop
	ld	ra,24(sp)
	.cfi_restore 1
	ld	s0,16(sp)
	.cfi_restore 8
	.cfi_def_cfa 2, 32
	addi	sp,sp,32
	.cfi_def_cfa_offset 0
	jr	ra
	.cfi_endproc
.LFE11:
	.size	init_virtio_net, .-init_virtio_net
	.section	.rodata
	.align	3
.LC8:
	.string	"[virtio-net-min] start\n"
	.align	3
.LC9:
	.string	"tx used idx timeout"
	.align	3
.LC10:
	.string	"rx used idx timeout"
	.align	3
.LC11:
	.string	"rx header mismatch"
	.align	3
.LC12:
	.string	"rx payload mismatch"
	.align	3
.LC13:
	.string	"[virtio-net-min] PASS\n"
	.text
	.align	1
	.globl	main
	.type	main, @function
main:
.LFB12:
	.cfi_startproc
	addi	sp,sp,-32
	.cfi_def_cfa_offset 32
	sd	ra,24(sp)
	sd	s0,16(sp)
	.cfi_offset 1, -8
	.cfi_offset 8, -16
	addi	s0,sp,32
	.cfi_def_cfa 8, 0
	li	a5,-272715776
	addi	a5,a5,-546
	sw	a5,-24(s0)
	lla	a0,.LC8
	call	uart_puts
	call	disable_mie_bits
	call	enable_mstatus_mie
	call	init_virtio_net
	sw	zero,-20(s0)
	j	.L30
.L31:
	lla	a4,tx_frame
	lw	a5,-20(s0)
	add	a5,a4,a5
	sb	zero,0(a5)
	lw	a5,-20(s0)
	addiw	a5,a5,1
	sw	a5,-20(s0)
.L30:
	lw	a5,-20(s0)
	sext.w	a4,a5
	li	a5,13
	ble	a4,a5,.L31
	sw	zero,-20(s0)
	j	.L32
.L33:
	lw	a5,-20(s0)
	addiw	a5,a5,10
	sext.w	a5,a5
	lw	a4,-20(s0)
	addi	a4,a4,-16
	add	a4,a4,s0
	lbu	a4,-8(a4)
	lla	a3,tx_frame
	add	a5,a3,a5
	sb	a4,0(a5)
	lw	a5,-20(s0)
	addiw	a5,a5,1
	sw	a5,-20(s0)
.L32:
	lw	a5,-20(s0)
	sext.w	a4,a5
	li	a5,3
	ble	a4,a5,.L33
	lla	a5,tx_queue_pages
	lla	a4,tx_frame
	sd	a4,0(a5)
	lla	a5,tx_queue_pages
	li	a4,14
	sw	a4,8(a5)
	lla	a5,tx_queue_pages
	sh	zero,12(a5)
	lla	a5,tx_queue_pages
	sh	zero,14(a5)
	lla	a5,tx_queue_pages+128
	sh	zero,4(a5)
	call	fence_rw_rw
	lla	a5,tx_queue_pages+128
	li	a4,1
	sh	a4,2(a5)
	call	fence_rw_rw
	li	a1,1
	li	a0,80
	call	mmio_write32
	lla	a5,tx_queue_pages+4096
	addi	a5,a5,2
	li	a1,1
	mv	a0,a5
	call	wait_used_idx
	mv	a5,a0
	beq	a5,zero,.L34
	lla	a0,.LC9
	call	fail
.L34:
	li	a0,96
	call	mmio_read32
	mv	a5,a0
	sext.w	a5,a5
	andi	a5,a5,1
	sext.w	a5,a5
	beq	a5,zero,.L35
	li	a1,1
	li	a0,100
	call	mmio_write32
.L35:
	sw	zero,-20(s0)
	j	.L36
.L37:
	lla	a4,rx_frame
	lw	a5,-20(s0)
	add	a5,a4,a5
	sb	zero,0(a5)
	lw	a5,-20(s0)
	addiw	a5,a5,1
	sw	a5,-20(s0)
.L36:
	lw	a5,-20(s0)
	sext.w	a4,a5
	li	a5,73
	ble	a4,a5,.L37
	lla	a5,rx_queue_pages
	lla	a4,rx_frame
	sd	a4,0(a5)
	lla	a5,rx_queue_pages
	li	a4,74
	sw	a4,8(a5)
	lla	a5,rx_queue_pages
	li	a4,2
	sh	a4,12(a5)
	lla	a5,rx_queue_pages
	sh	zero,14(a5)
	lla	a5,rx_queue_pages+128
	sh	zero,4(a5)
	call	fence_rw_rw
	lla	a5,rx_queue_pages+128
	li	a4,1
	sh	a4,2(a5)
	call	fence_rw_rw
	li	a1,0
	li	a0,80
	call	mmio_write32
	lla	a5,rx_queue_pages+4096
	addi	a5,a5,2
	li	a1,1
	mv	a0,a5
	call	wait_used_idx
	mv	a5,a0
	beq	a5,zero,.L38
	lla	a0,.LC10
	call	fail
.L38:
	li	a0,96
	call	mmio_read32
	mv	a5,a0
	sext.w	a5,a5
	andi	a5,a5,1
	sext.w	a5,a5
	beq	a5,zero,.L39
	li	a1,1
	li	a0,100
	call	mmio_write32
.L39:
	sw	zero,-20(s0)
	j	.L40
.L42:
	lla	a4,rx_frame
	lw	a5,-20(s0)
	add	a5,a4,a5
	lbu	a5,0(a5)
	beq	a5,zero,.L41
	lla	a0,.LC11
	call	fail
.L41:
	lw	a5,-20(s0)
	addiw	a5,a5,1
	sw	a5,-20(s0)
.L40:
	lw	a5,-20(s0)
	sext.w	a4,a5
	li	a5,9
	ble	a4,a5,.L42
	sw	zero,-20(s0)
	j	.L43
.L45:
	lw	a5,-20(s0)
	addiw	a5,a5,10
	sext.w	a5,a5
	lla	a4,rx_frame
	add	a5,a4,a5
	lbu	a4,0(a5)
	lw	a5,-20(s0)
	addi	a5,a5,-16
	add	a5,a5,s0
	lbu	a5,-8(a5)
	beq	a4,a5,.L44
	lla	a0,.LC12
	call	fail
.L44:
	lw	a5,-20(s0)
	addiw	a5,a5,1
	sw	a5,-20(s0)
.L43:
	lw	a5,-20(s0)
	sext.w	a4,a5
	li	a5,3
	ble	a4,a5,.L45
	lla	a0,.LC13
	call	uart_puts
.L46:
	nop
	j	.L46
	.cfi_endproc
.LFE12:
	.size	main, .-main
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
