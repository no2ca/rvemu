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
.LFB5:
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
.LFE5:
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
	.string	"[host-rx] payload_len="
	.align	3
.LC5:
	.string	" hex="
	.align	3
.LC6:
	.string	" ..."
	.align	3
.LC7:
	.string	"[host-rx] start\n"
	.align	3
.LC8:
	.string	"bad magic"
	.align	3
.LC9:
	.string	"bad version"
	.align	3
.LC10:
	.string	"bad device id"
	.align	3
.LC11:
	.string	"bad vendor id"
	.align	3
.LC12:
	.string	"FEATURES_OK rejected"
	.align	3
.LC13:
	.string	"queue_num_max is too small"
	.align	3
.LC14:
	.string	"rx timeout"
	.section	.text.startup,"ax",@progbits
	.align	1
	.globl	main
	.type	main, @function
main:
.LFB16:
	.cfi_startproc
	addi	sp,sp,-96
	.cfi_def_cfa_offset 96
	lla	a0,.LC7
	sd	ra,88(sp)
	.cfi_offset 1, -8
	call	uart_puts
	li	a5,0
#APP
# 145 "/mnt/c/Users/taise/Documents/exp/rvemu-xv6-net/rvemu/bin/raw/virtio_net_host_rx.c" 1
	csrw mie, a5
# 0 "" 2
#NO_APP
	li	a5,8
#APP
# 141 "/mnt/c/Users/taise/Documents/exp/rvemu-xv6-net/rvemu/bin/raw/virtio_net_host_rx.c" 1
	csrs mstatus, a5
# 0 "" 2
#NO_APP
	li	a5,268443648
	lw	a4,0(a5)
	li	a5,1953656832
	addi	a5,a5,-1674
	bne	a4,a5,.L97
	li	a5,268443648
	lw	a4,4(a5)
	li	a2,1
	sext.w	a3,a4
	bne	a4,a2,.L98
	li	a5,268443648
	lw	a4,8(a5)
	sext.w	a6,a4
	bne	a4,a3,.L99
	li	a4,268443648
	lw	a3,12(a4)
	li	a5,1431126016
	addi	a5,a5,1361
	bne	a3,a5,.L100
	li	a4,268443648
	sw	zero,112(a4)
	sw	a6,112(a4)
	li	a5,3
	sw	a5,112(a4)
	li	a2,268443648
	sw	zero,20(a2)
	li	a3,268443648
	lw	a7,16(a3)
	sw	a6,20(a2)
	lw	a0,16(a3)
	li	a5,268443648
	sw	zero,36(a5)
	li	a1,268443648
	sext.w	a7,a7
	sw	a7,32(a1)
	sw	a6,36(a5)
	sext.w	a0,a0
	sw	a0,32(a1)
	li	a1,11
	sw	a1,112(a4)
	lw	a1,112(a4)
	addi	a4,a4,112
	andi	a2,a1,8
	beq	a2,zero,.L101
	li	a3,268443648
	li	a0,4096
	sw	a0,40(a3)
	li	a5,268443648
	sw	zero,48(a5)
	li	a3,268443648
	lw	a2,52(a3)
	li	a3,7
	sd	s0,80(sp)
	sd	s1,72(sp)
	sd	s2,64(sp)
	sd	s3,56(sp)
	sd	s4,48(sp)
	sd	s5,40(sp)
	sd	s6,32(sp)
	sd	s7,24(sp)
	sd	s8,16(sp)
	sd	s9,8(sp)
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	.cfi_offset 23, -72
	.cfi_offset 24, -80
	.cfi_offset 25, -88
	bleu	a2,a3,.L102
	li	a5,268443648
	li	a3,8
	lla	t3,rx_queue_pages
	sw	a3,56(a5)
	li	a2,268443648
	srli	a1,t3,12
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
	li	a5,268435456
	sw	a3,0(a4)
	lla	t4,.LANCHOR0
	li	t1,1
	lla	a3,.LANCHOR0+522
	lla	t6,rx_queue_pages+4096
	addi	t0,t0,522
	addi	t2,t2,512
	addi	ra,ra,96
	addi	s1,s1,100
	li	s3,1
	li	s0,24
	li	s2,64
	li	a2,268435456
	addi	a5,a5,5
	lla	a7,.LANCHOR1
	li	a6,-4
	li	t5,32
	lla	a1,hex.0
	li	a0,10
.L52:
	addiw	s6,t1,-1
	slli	s4,s6,48
	srli	s4,s4,48
	mv	a4,t4
.L22:
	sb	zero,0(a4)
	addi	a4,a4,1
	bne	a3,a4,.L22
	andi	a4,s4,7
	slli	a4,a4,1
	add	a4,t3,a4
	sd	t4,0(t3)
	sd	t0,8(t3)
	sh	zero,132(a4)
#APP
# 137 "/mnt/c/Users/taise/Documents/exp/rvemu-xv6-net/rvemu/bin/raw/virtio_net_host_rx.c" 1
	fence rw, rw
# 0 "" 2
#NO_APP
	sh	t1,130(t3)
#APP
# 137 "/mnt/c/Users/taise/Documents/exp/rvemu-xv6-net/rvemu/bin/raw/virtio_net_host_rx.c" 1
	fence rw, rw
# 0 "" 2
#NO_APP
	lhu	s5,2(t6)
	mv	a4,t2
	sext.w	s4,t1
.L24:
	beq	s4,s5,.L23
	addiw	a4,a4,-1
	bne	a4,zero,.L24
	lla	a0,.LC14
	call	fail
.L23:
	lw	a4,0(ra)
	andi	a4,a4,1
	beq	a4,zero,.L25
	sw	s3,0(s1)
.L25:
	sraiw	s4,s6,31
	srliw	s4,s4,29
	addw	a4,s6,s4
	andi	a4,a4,7
	subw	a4,a4,s4
	slli	a4,a4,3
	add	a4,t6,a4
	lw	s4,8(a4)
	bleu	s4,s0,.L103
	addiw	s5,s4,-24
	mv	s4,s5
	bleu	s5,s2,.L35
	li	s4,64
.L35:
	lla	s7,.LC4
	li	s6,91
.L36:
	lbu	a4,0(a5)
	andi	a4,a4,32
	beq	a4,zero,.L36
	sb	s6,0(a2)
	lbu	s6,1(s7)
	addi	s7,s7,1
	bne	s6,zero,.L36
	lla	s7,.LC3
	li	s6,48
.L38:
	lbu	a4,0(a5)
	andi	a4,a4,32
	beq	a4,zero,.L38
	sb	s6,0(a2)
	lbu	s6,1(s7)
	addi	s7,s7,1
	bne	s6,zero,.L38
	li	s6,28
.L41:
	srlw	a4,s5,s6
	andi	a4,a4,15
	add	a4,a7,a4
	lbu	s7,0(a4)
.L40:
	lbu	a4,0(a5)
	andi	a4,a4,32
	beq	a4,zero,.L40
	sb	s7,0(a2)
	addiw	s6,s6,-4
	bne	s6,a6,.L41
	lla	s7,.LC5
	li	s6,32
.L42:
	lbu	a4,0(a5)
	andi	a4,a4,32
	beq	a4,zero,.L42
	sb	s6,0(a2)
	lbu	s6,1(s7)
	addi	s7,s7,1
	bne	s6,zero,.L42
	lla	s7,.LANCHOR0+24
.L44:
	lbu	s8,0(s7)
	srli	a4,s8,4
	add	a4,a1,a4
	lbu	s9,0(a4)
.L46:
	lbu	a4,0(a5)
	andi	a4,a4,32
	beq	a4,zero,.L46
	andi	s8,s8,15
	add	s8,a1,s8
	lbu	s8,0(s8)
	sb	s9,0(a2)
.L47:
	lbu	a4,0(a5)
	andi	a4,a4,32
	beq	a4,zero,.L47
	sb	s8,0(a2)
	addiw	s6,s6,1
	beq	s4,s6,.L104
.L45:
	lbu	a4,0(a5)
	andi	a4,a4,32
	beq	a4,zero,.L45
	addi	s7,s7,1
	sb	t5,0(a2)
	j	.L44
.L104:
	bgtu	s5,s4,.L105
.L49:
	lbu	a4,0(a5)
	andi	a4,a4,32
	beq	a4,zero,.L49
.L95:
	addiw	t1,t1,1
	slli	t1,t1,48
	sb	a0,0(a2)
	srli	t1,t1,48
	j	.L52
.L103:
	lla	s6,.LC2
	li	s5,91
.L27:
	lbu	a4,0(a5)
	andi	a4,a4,32
	beq	a4,zero,.L27
	sb	s5,0(a2)
	lbu	s5,1(s6)
	addi	s6,s6,1
	bne	s5,zero,.L27
	lla	s6,.LC3
	li	s5,48
.L29:
	lbu	a4,0(a5)
	andi	a4,a4,32
	beq	a4,zero,.L29
	sb	s5,0(a2)
	lbu	s5,1(s6)
	addi	s6,s6,1
	bne	s5,zero,.L29
	li	s5,28
.L32:
	srlw	a4,s4,s5
	andi	a4,a4,15
	add	a4,a7,a4
	lbu	s6,0(a4)
.L31:
	lbu	a4,0(a5)
	andi	a4,a4,32
	beq	a4,zero,.L31
	sb	s6,0(a2)
	addiw	s5,s5,-4
	bne	s5,a6,.L32
.L33:
	lbu	a4,0(a5)
	andi	a4,a4,32
	bne	a4,zero,.L95
	lbu	a4,0(a5)
	andi	a4,a4,32
	beq	a4,zero,.L33
	j	.L95
.L105:
	lla	s5,.LC6
	li	s4,32
.L50:
	lbu	a4,0(a5)
	andi	a4,a4,32
	beq	a4,zero,.L50
	sb	s4,0(a2)
	lbu	s4,1(s5)
	addi	s5,s5,1
	bne	s4,zero,.L50
	j	.L49
.L97:
	.cfi_restore 8
	.cfi_restore 9
	.cfi_restore 18
	.cfi_restore 19
	.cfi_restore 20
	.cfi_restore 21
	.cfi_restore 22
	.cfi_restore 23
	.cfi_restore 24
	.cfi_restore 25
	lla	a0,.LC8
	sd	s0,80(sp)
	sd	s1,72(sp)
	sd	s2,64(sp)
	sd	s3,56(sp)
	sd	s4,48(sp)
	sd	s5,40(sp)
	sd	s6,32(sp)
	sd	s7,24(sp)
	sd	s8,16(sp)
	sd	s9,8(sp)
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	.cfi_offset 23, -72
	.cfi_offset 24, -80
	.cfi_offset 25, -88
	call	fail
.L102:
	lla	a0,.LC13
	call	fail
.L101:
	.cfi_restore 8
	.cfi_restore 9
	.cfi_restore 18
	.cfi_restore 19
	.cfi_restore 20
	.cfi_restore 21
	.cfi_restore 22
	.cfi_restore 23
	.cfi_restore 24
	.cfi_restore 25
	lla	a0,.LC12
	sd	s0,80(sp)
	sd	s1,72(sp)
	sd	s2,64(sp)
	sd	s3,56(sp)
	sd	s4,48(sp)
	sd	s5,40(sp)
	sd	s6,32(sp)
	sd	s7,24(sp)
	sd	s8,16(sp)
	sd	s9,8(sp)
	.cfi_remember_state
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	.cfi_offset 23, -72
	.cfi_offset 24, -80
	.cfi_offset 25, -88
	call	fail
.L100:
	.cfi_restore_state
	lla	a0,.LC11
	sd	s0,80(sp)
	sd	s1,72(sp)
	sd	s2,64(sp)
	sd	s3,56(sp)
	sd	s4,48(sp)
	sd	s5,40(sp)
	sd	s6,32(sp)
	sd	s7,24(sp)
	sd	s8,16(sp)
	sd	s9,8(sp)
	.cfi_remember_state
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	.cfi_offset 23, -72
	.cfi_offset 24, -80
	.cfi_offset 25, -88
	call	fail
.L99:
	.cfi_restore_state
	lla	a0,.LC10
	sd	s0,80(sp)
	sd	s1,72(sp)
	sd	s2,64(sp)
	sd	s3,56(sp)
	sd	s4,48(sp)
	sd	s5,40(sp)
	sd	s6,32(sp)
	sd	s7,24(sp)
	sd	s8,16(sp)
	sd	s9,8(sp)
	.cfi_remember_state
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	.cfi_offset 23, -72
	.cfi_offset 24, -80
	.cfi_offset 25, -88
	call	fail
.L98:
	.cfi_restore_state
	lla	a0,.LC9
	sd	s0,80(sp)
	sd	s1,72(sp)
	sd	s2,64(sp)
	sd	s3,56(sp)
	sd	s4,48(sp)
	sd	s5,40(sp)
	sd	s6,32(sp)
	sd	s7,24(sp)
	sd	s8,16(sp)
	sd	s9,8(sp)
	.cfi_offset 8, -16
	.cfi_offset 9, -24
	.cfi_offset 18, -32
	.cfi_offset 19, -40
	.cfi_offset 20, -48
	.cfi_offset 21, -56
	.cfi_offset 22, -64
	.cfi_offset 23, -72
	.cfi_offset 24, -80
	.cfi_offset 25, -88
	call	fail
	.cfi_endproc
.LFE16:
	.size	main, .-main
	.set	hex.0,hex.1
	.section	.rodata
	.align	3
	.set	.LANCHOR1,. + 0
	.type	hex.1, @object
	.size	hex.1, 17
hex.1:
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
