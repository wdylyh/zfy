	.text
	.def	@feat.00;
	.scl	3;
	.type	0;
	.endef
	.globl	@feat.00
.set @feat.00, 0
	.file	"rt_jb2.c"
	.def	zfy_try_setup;
	.scl	2;
	.type	32;
	.endef
	.globl	zfy_try_setup                   # -- Begin function zfy_try_setup
	.p2align	4, 0x90
zfy_try_setup:                          # @zfy_try_setup
.seh_proc zfy_try_setup
# %bb.0:
	pushq	%rsi
	.seh_pushreg %rsi
	subq	$16, %rsp
	.seh_stackalloc 16
	.seh_endprologue
	movq	%rcx, 8(%rsp)
	movq	8(%rsp), %rax
	movq	$0, 248(%rax)
	movq	top(%rip), %rcx
	movq	8(%rsp), %rax
	movq	%rcx, 256(%rax)
	movq	8(%rsp), %rax
	movq	%rax, top(%rip)
	movq	8(%rsp), %rsi
	#APP
	movq	%rbx, (%rsi)
	movq	%rbp, 8(%rsi)
	movq	%rsi, 16(%rsi)
	movq	%rdi, 24(%rsi)
	movq	%r12, 32(%rsi)
	movq	%r13, 40(%rsi)
	movq	%r14, 48(%rsi)
	movq	%r15, 56(%rsi)
	movq	%rsp, 64(%rsi)
	leaq	.Ltmp0(%rip), %rax
	movq	%rax, 72(%rsi)
	stmxcsr	80(%rsi)
	fnstcw	84(%rsi)
	movdqu	%xmm6, 88(%rsi)
	movdqu	%xmm7, 104(%rsi)
	movdqu	%xmm8, 120(%rsi)
	movdqu	%xmm9, 136(%rsi)
	movdqu	%xmm10, 152(%rsi)
	movdqu	%xmm11, 168(%rsi)
	movdqu	%xmm12, 184(%rsi)
	movdqu	%xmm13, 200(%rsi)
	movdqu	%xmm14, 216(%rsi)
	movdqu	%xmm15, 232(%rsi)
	xorl	%eax, %eax
.Ltmp0:

	#NO_APP
	movl	%eax, 4(%rsp)
	movl	4(%rsp), %eax
	addq	$16, %rsp
	popq	%rsi
	retq
	.seh_endproc
                                        # -- End function
	.def	zfy_longjmp;
	.scl	2;
	.type	32;
	.endef
	.globl	zfy_longjmp                     # -- Begin function zfy_longjmp
	.p2align	4, 0x90
zfy_longjmp:                            # @zfy_longjmp
# %bb.0:
	#APP
	movq	(%rcx), %rbx
	movq	8(%rcx), %rbp
	movq	16(%rcx), %rsi
	movq	24(%rcx), %rdi
	movq	32(%rcx), %r12
	movq	40(%rcx), %r13
	movq	48(%rcx), %r14
	movq	56(%rcx), %r15
	movq	64(%rcx), %rsp
	ldmxcsr	80(%rcx)
	fldcw	84(%rcx)
	movdqu	88(%rcx), %xmm6
	movdqu	104(%rcx), %xmm7
	movdqu	120(%rcx), %xmm8
	movdqu	136(%rcx), %xmm9
	movdqu	152(%rcx), %xmm10
	movdqu	168(%rcx), %xmm11
	movdqu	184(%rcx), %xmm12
	movdqu	200(%rcx), %xmm13
	movdqu	216(%rcx), %xmm14
	movdqu	232(%rcx), %xmm15
	movl	%edx, %eax
	jmpq	*72(%rcx)
	#NO_APP
                                        # -- End function
	.def	do_throw;
	.scl	2;
	.type	32;
	.endef
	.globl	do_throw                        # -- Begin function do_throw
	.p2align	4, 0x90
do_throw:                               # @do_throw
.seh_proc do_throw
# %bb.0:
	subq	$40, %rsp
	.seh_stackalloc 40
	.seh_endprologue
	movq	%rcx, 32(%rsp)
	movq	32(%rsp), %rcx
	movq	top(%rip), %rax
	movq	%rcx, 248(%rax)
	movq	top(%rip), %rcx
	movl	$1, %edx
	callq	zfy_longjmp
	int3
	.seh_endproc
                                        # -- End function
	.def	main;
	.scl	2;
	.type	32;
	.endef
	.globl	main                            # -- Begin function main
	.p2align	4, 0x90
main:                                   # @main
.seh_proc main
# %bb.0:
	pushq	%rbp
	.seh_pushreg %rbp
	subq	$320, %rsp                      # imm = 0x140
	.seh_stackalloc 320
	leaq	128(%rsp), %rbp
	.seh_setframe %rbp, 128
	.seh_endprologue
	callq	__main
	movl	$0, 188(%rbp)
	leaq	-80(%rbp), %rcx
	callq	zfy_try_setup
	movl	%eax, -84(%rbp)
	cmpl	$0, -84(%rbp)
	je	.LBB3_2
# %bb.1:
	movq	168(%rbp), %rdx
	leaq	.L.str(%rip), %rcx
	callq	printf
	movl	$0, 188(%rbp)
	jmp	.LBB3_3
.LBB3_2:
	leaq	.L.str.1(%rip), %rcx
	callq	printf
	movl	$1, %ecx
	callq	*__imp___acrt_iob_func(%rip)
	movq	%rax, %rcx
	callq	fflush
	leaq	.L.str.2(%rip), %rcx
	callq	do_throw
	leaq	.L.str.3(%rip), %rcx
	callq	printf
	movl	$1, 188(%rbp)
.LBB3_3:
	movl	188(%rbp), %eax
	addq	$320, %rsp                      # imm = 0x140
	popq	%rbp
	retq
	.seh_endproc
                                        # -- End function
	.lcomm	top,8,8                         # @top
	.section	.rdata,"dr"
.L.str:                                 # @.str
	.asciz	"caught: %s\n"

.L.str.1:                               # @.str.1
	.asciz	"before\n"

.L.str.2:                               # @.str.2
	.asciz	"boom"

.L.str.3:                               # @.str.3
	.asciz	"BAD: returned from do_throw\n"

	.addrsig
	.addrsig_sym zfy_try_setup
	.addrsig_sym zfy_longjmp
	.addrsig_sym do_throw
	.addrsig_sym printf
	.addrsig_sym fflush
	.addrsig_sym top
