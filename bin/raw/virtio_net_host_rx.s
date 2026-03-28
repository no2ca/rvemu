	.file	"virtio_net_host_rx.c"
	.option nopic
	.attribute arch, "rv64i2p1_m2p0_a2p1_c2p0_zicsr2p0"
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
	.align	1
	.type	uart_puts, @function
uart_puts:
.LFB2:
	.cfi_startproc
	lbu	a3,0(a0)
	beq	a3,zero,.L1
	li	a4,268435456
	li	a2,268435456
	addi	a4,a4,5
.L3:
	lbu	a5,0(a4)
	andi	a5,a5,32
	beq	a5,zero,.L3
	sb	a3,0(a2)
	lbu	a3,1(a0)
	addi	a0,a0,1
	bne	a3,zero,.L3
.L1:
	ret
	.cfi_endproc
.LFE2:
	.size	uart_puts, .-uart_puts
	.section	.rodata.str1.8,"aMS",@progbits,1
	.align	3
.LC0:
	.string	"[host-rx] FAIL: "
	.align	3
.LC1:
	.string	"\n"
	.text
	.align	1
	.type	fail, @function
fail:
.LFB4:
	.cfi_startproc
	addi	sp,sp,-16
	.cfi_def_cfa_offset 16
	sd	s0,0(sp)
	.cfi_offset 8, -16
	mv	s0,a0
	lla	a0,.LC0
	sd	ra,8(sp)
	.cfi_offset 1, -8
	call	uart_puts
	mv	a0,s0
	call	uart_puts
	lla	a0,.LC1
	call	uart_puts
.L13:
	j	.L13
	.cfi_endproc
.LFE4:
	.size	fail, .-fail
	.section	.rodata.str1.8
	.align	3
.LC2:
	.string	"[host-rx] short frame len="
	.align	3
.LC3:
	.string	"0x"
	.align	3
.LC4:
	.string	"[host-rx] "
	.align	3
.LC5:
	.string	"[host-rx] start\n"
	.align	3
.LC6:
	.string	"bad magic"
	.align	3
.LC7:
	.string	"bad version"
	.align	3
.LC8:
	.string	"bad device id"
	.align	3
.LC9:
	.string	"bad vendor id"
	.align	3
.LC10:
	.string	"FEATURES_OK rejected"
	.align	3
.LC11:
	.string	"queue_num_max is too small"
	.align	3
.LC12:
	.string	"rx timeout"
	.section	.text.startup,"ax",@progbits
	.align	1
	.globl	main
	.type	main, @function
main:
.LFB15:
	.cfi_startproc
	addi	sp,sp,-64
	.cfi_def_cfa_offset 64
	lla	a0,.LC5
	sd	ra,56(sp)
	.cfi_offset 1, -8
	call	uart_puts
	li	a5,0
#APP
# 139 "bin/raw/virtio_net_host_rx.c" 1
	csrw mie, a5
# 0 "" 2
#NO_APP
	li	a5,8
#APP
# 135 "bin/raw/virtio_net_host_rx.c" 1
	csrs mstatus, a5
# 0 "" 2
#NO_APP
	li	a5,268443648
	lw	a4,0(a5)
	li	a5,1953656832
	addi	a5,a5,-1674
	bne	a4,a5,.L74
	li	a5,268443648
	lw	a4,4(a5)
	li	a2,1
	sext.w	a3,a4
	bne	a4,a2,.L75
	li	a5,268443648
	lw	a4,8(a5)
	sext.w	a6,a4
	bne	a4,a3,.L76
	li	a4,268443648
	lw	a3,12(a4)
	li	a5,1431126016
	addi	a5,a5,1361
	bne	a3,a5,.L77
	li	a5,268443648
	sw	zero,112(a5)
	sw	a6,112(a5)
	li	a4,3
	sw	a4,112(a5)
	li	a2,268443648
	sw	zero,20(a2)
	li	a3,268443648
	lw	a7,16(a3)
	sw	a6,20(a2)
	lw	a0,16(a3)
	li	a4,268443648
	sw	zero,36(a4)
	li	a1,268443648
	sext.w	a7,a7
	sw	a7,32(a1)
	sw	a6,36(a4)
	sext.w	a0,a0
	sw	a0,32(a1)
	li	a1,11
	sw	a1,112(a5)
	lw	a1,112(a5)
	addi	a5,a5,112
	andi	a2,a1,8
	beq	a2,zero,.L78
	li	a3,268443648
	li	a0,4096
	sw	a0,40(a3)
	li	a4,268443648
	sw	zero,48(a4)
	li	a3,268443648
	lw	a2,52(a3)
	li	a3,7
	sd	s0,48(sp)
	sd	s1,40(sp)
	sd	s2,32(sp)
	sd	s3,24(sp)
	sd	s4,16(sp)
	sd	s5,8(sp)
	sd	s6,0(sp)
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	bleu	a2,a3,.L79
	li	a4,268443648
	li	a3,8
	lla	a7,rx_queue_pages
	sw	a3,56(a4)
	li	a2,268443648
	srli	a1,a7,12
	sw	a0,60(a2)
	li	a3,268443648
	sext.w	a1,a1
	li	t0,1
	sw	a1,64(a3)
	slli	t0,t0,33
	li	a3,15
	li	t2,199999488
	li	ra,268443648
	li	s1,268443648
	li	a4,268435456
	sw	a3,0(a5)
	lla	t5,.LANCHOR0
	li	a0,1
	lla	a3,.LANCHOR0+522
	lla	t6,rx_queue_pages+4096
	addi	t0,t0,522
	addi	t2,t2,512
	addi	ra,ra,96
	addi	s1,s1,100
	li	s3,1
	li	s0,24
	li	a2,268435456
	addi	a4,a4,5
	lla	s2,.LANCHOR0+25
	li	a6,94
	li	t4,46
	li	a1,10
	lla	t3,.LANCHOR1
	li	t1,-4
.L41:
	addiw	s6,a0,-1
	slli	s4,s6,48
	srli	s4,s4,48
	mv	a5,t5
.L22:
	sb	zero,0(a5)
	addi	a5,a5,1
	bne	a3,a5,.L22
	andi	a5,s4,7
	slli	a5,a5,1
	add	a5,a7,a5
	sd	t5,0(a7)
	sd	t0,8(a7)
	sh	zero,132(a5)
#APP
# 131 "bin/raw/virtio_net_host_rx.c" 1
	fence rw, rw
# 0 "" 2
#NO_APP
	sh	a0,130(a7)
#APP
# 131 "bin/raw/virtio_net_host_rx.c" 1
	fence rw, rw
# 0 "" 2
#NO_APP
	lhu	s5,2(t6)
	mv	a5,t2
	sext.w	s4,a0
.L24:
	beq	s4,s5,.L23
	addiw	a5,a5,-1
	bne	a5,zero,.L24
	lla	a0,.LC12
	call	fail
.L23:
	lw	a5,0(ra)
	andi	a5,a5,1
	beq	a5,zero,.L25
	sw	s3,0(s1)
.L25:
	sraiw	s4,s6,31
	srliw	s4,s4,29
	addw	a5,s6,s4
	andi	a5,a5,7
	subw	a5,a5,s4
	slli	a5,a5,3
	add	a5,t6,a5
	lw	s4,8(a5)
	lla	s6,.LC4
	li	s5,91
	bleu	s4,s0,.L80
.L35:
	lbu	a5,0(a4)
	andi	a5,a5,32
	beq	a5,zero,.L35
	sb	s5,0(a2)
	lbu	s5,1(s6)
	addi	s6,s6,1
	bne	s5,zero,.L35
	addiw	s5,s4,-25
	slli	s5,s5,32
	srli	s5,s5,32
	lla	s4,.LANCHOR0+24
	add	s5,s2,s5
.L39:
	lbu	s6,0(s4)
	addiw	a5,s6,-32
	andi	a5,a5,0xff
	bgtu	a5,a6,.L36
.L37:
	lbu	a5,0(a4)
	andi	a5,a5,32
	beq	a5,zero,.L37
	sb	s6,0(a2)
	addi	s4,s4,1
	bne	s5,s4,.L39
.L40:
	lbu	a5,0(a4)
	andi	a5,a5,32
	beq	a5,zero,.L40
.L72:
	addiw	a0,a0,1
	slli	a0,a0,48
	sb	a1,0(a2)
	srli	a0,a0,48
	j	.L41
.L36:
	lbu	a5,0(a4)
	andi	a5,a5,32
	beq	a5,zero,.L36
	sb	t4,0(a2)
	addi	s4,s4,1
	bne	s5,s4,.L39
	lbu	a5,0(a4)
	andi	a5,a5,32
	beq	a5,zero,.L40
	j	.L72
.L80:
	lla	s6,.LC2
.L27:
	lbu	a5,0(a4)
	andi	a5,a5,32
	beq	a5,zero,.L27
	sb	s5,0(a2)
	lbu	s5,1(s6)
	addi	s6,s6,1
	bne	s5,zero,.L27
	lla	s6,.LC3
	li	s5,48
.L29:
	lbu	a5,0(a4)
	andi	a5,a5,32
	beq	a5,zero,.L29
	sb	s5,0(a2)
	lbu	s5,1(s6)
	addi	s6,s6,1
	bne	s5,zero,.L29
	li	s5,28
.L32:
	srlw	a5,s4,s5
	andi	a5,a5,15
	add	a5,t3,a5
	lbu	s6,0(a5)
.L31:
	lbu	a5,0(a4)
	andi	a5,a5,32
	beq	a5,zero,.L31
	sb	s6,0(a2)
	addiw	s5,s5,-4
	bne	s5,t1,.L32
.L33:
	lbu	a5,0(a4)
	andi	a5,a5,32
	bne	a5,zero,.L72
	lbu	a5,0(a4)
	andi	a5,a5,32
	beq	a5,zero,.L33
	j	.L72
.L74:
	.cfi_restore 8
	.cfi_restore 9
	.cfi_restore 18
	.cfi_restore 19
	.cfi_restore 20
	.cfi_restore 21
	.cfi_restore 22
	lla	a0,.LC6
	sd	s0,48(sp)
	sd	s1,40(sp)
	sd	s2,32(sp)
	sd	s3,24(sp)
	sd	s4,16(sp)
	sd	s5,8(sp)
	sd	s6,0(sp)
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	call	fail
.L79:
	lla	a0,.LC11
	call	fail
.L78:
	.cfi_restore 8
	.cfi_restore 9
	.cfi_restore 18
	.cfi_restore 19
	.cfi_restore 20
	.cfi_restore 21
	.cfi_restore 22
	lla	a0,.LC10
	sd	s0,48(sp)
	sd	s1,40(sp)
	sd	s2,32(sp)
	sd	s3,24(sp)
	sd	s4,16(sp)
	sd	s5,8(sp)
	sd	s6,0(sp)
	.cfi_remember_state
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	call	fail
.L77:
	.cfi_restore_state
	lla	a0,.LC9
	sd	s0,48(sp)
	sd	s1,40(sp)
	sd	s2,32(sp)
	sd	s3,24(sp)
	sd	s4,16(sp)
	sd	s5,8(sp)
	sd	s6,0(sp)
	.cfi_remember_state
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	call	fail
.L76:
	.cfi_restore_state
	lla	a0,.LC8
	sd	s0,48(sp)
	sd	s1,40(sp)
	sd	s2,32(sp)
	sd	s3,24(sp)
	sd	s4,16(sp)
	sd	s5,8(sp)
	sd	s6,0(sp)
	.cfi_remember_state
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	call	fail
.L75:
	.cfi_restore_state
	lla	a0,.LC7
	sd	s0,48(sp)
	sd	s1,40(sp)
	sd	s2,32(sp)
	sd	s3,24(sp)
	sd	s4,16(sp)
	sd	s5,8(sp)
	sd	s6,0(sp)
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	call	fail
	.cfi_endproc
.LFE15:
	.size	main, .-main
	.section	.rodata
	.align	3
	.set	.LANCHOR1,. + 0
	.type	hex.0, @object
	.size	hex.0, 17
hex.0:
	.string	"0123456789abcdef"
	.bss
	.align	12
	.set	.LANCHOR0,. + 0
	.type	rx_frame, @object
	.size	rx_frame, 522
rx_frame:
	.zero	522
	.zero	3574
	.type	rx_queue_pages, @object
	.size	rx_queue_pages, 8192
rx_queue_pages:
	.zero	8192
	.ident	"GCC: (Ubuntu 13.3.0-6ubuntu2~24.04) 13.3.0"
	.section	.note.GNU-stack,"",@progbits
