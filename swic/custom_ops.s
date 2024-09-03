.equ regnum_q0, 0
.equ regnum_q1, 1
.equ regnum_q2, 2
.equ regnum_q3, 3

.equ regnum_x0, 0
.equ regnum_x1, 1
.equ regnum_x2, 2
.equ regnum_x3, 3
.equ regnum_x4, 4
.equ regnum_x5, 5
.equ regnum_x6, 6
.equ regnum_x7, 7
.equ regnum_x8, 8
.equ regnum_x9, 9
.equ regnum_x10, 10
.equ regnum_x11, 11
.equ regnum_x12, 12
.equ regnum_x13, 13
.equ regnum_x14, 14
.equ regnum_x15, 15
.equ regnum_x16, 16
.equ regnum_x17, 17
.equ regnum_x18, 18
.equ regnum_x19, 19
.equ regnum_x20, 20
.equ regnum_x21, 21
.equ regnum_x22, 22
.equ regnum_x23, 23
.equ regnum_x24, 24
.equ regnum_x25, 25
.equ regnum_x26, 26
.equ regnum_x27, 27
.equ regnum_x28, 28
.equ regnum_x29, 29
.equ regnum_x30, 30
.equ regnum_x31, 31

.equ regnum_zero, 0
.equ regnum_ra, 1
.equ regnum_sp, 2
.equ regnum_gp, 3
.equ regnum_tp, 4
.equ regnum_t0, 5
.equ regnum_t1, 6
.equ regnum_t2, 7
.equ regnum_s0, 8
.equ regnum_s1, 9
.equ regnum_a0, 10
.equ regnum_a1, 11
.equ regnum_a2, 12
.equ regnum_a3, 13
.equ regnum_a4, 14
.equ regnum_a5, 15
.equ regnum_a6, 16
.equ regnum_a7, 17
.equ regnum_s2, 18
.equ regnum_s3, 19
.equ regnum_s4, 20
.equ regnum_s5, 21
.equ regnum_s6, 22
.equ regnum_s7, 23
.equ regnum_s8, 24
.equ regnum_s9, 25
.equ regnum_s10, 26
.equ regnum_s11, 27
.equ regnum_t3, 28
.equ regnum_t4, 29
.equ regnum_t5, 30
.equ regnum_t6, 31

.equ regnum_fp, 8

.macro r_type_insn f7, rs2, rs1, f3, rd, opc
    .word (((\f7) << 25) | ((\rs2) << 20) | ((\rs1) << 15) | ((\f3) << 12) | ((\rd) << 7) | ((\opc) << 0))
.endm

.macro picorv32_getq_insn rd, qs
    r_type_insn 0b0000000, 0, regnum_\qs, 0b100, regnum_\rd, 0b0001011
.endm

.macro picorv32_setq_insn qd, rs
    r_type_insn 0b0000001, 0, regnum_\rs, 0b010, regnum_\qd, 0b0001011
.endm

.macro picorv32_retirq_insn
    r_type_insn 0b0000010, 0, 0, 0b000, 0, 0b0001011
.endm

.macro picorv32_maskirq_insn rd, rs
    r_type_insn 0b0000011, 0, regnum_\rs, 0b110, regnum_\rd, 0b0001011
.endm

.macro picorv32_waitirq_insn rd
    r_type_insn 0b0000100, 0, 0, 0b100, regnum_\rd, 0b0001011
.endm

.macro picorv32_timer_insn rd, rs
    r_type_insn 0b0000101, 0, regnum_\rs, 0b110, regnum_\rd, 0b0001011
.endm
