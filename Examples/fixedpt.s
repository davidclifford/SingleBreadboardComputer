FP_A = $FB
FP_B = $FD
FP_C = $F0
FP_R = $F2

CP_A = $10
CP_B = $18
CP_ML = $00
CP_MH = $01
CP_MD = $02
CP_DV = $03
CP_S0 = $04
CP_S1 = $05
CP_S2 = $06
CP_S3 = $07

fp_lda_byte:  ;FP_A = A
   sta FP_A+1
   stz FP_A
   rts

fp_ldb_byte: ; FP_B = A
   sta FP_B+1
   stz FP_B
   rts

FP_LDA .macro addr
   lda \addr
   sta FP_A
   lda \addr+1
   sta FP_A+1
.endmacro

FP_LDB .macro addr
   lda \addr
   sta FP_B
   lda \addr+1
   sta FP_B+1
.endmacro

FP_LDA_IMM .macro  val
   lda #<\val
   sta FP_A
   lda #>\val
   sta FP_A+1
.endmacro

FP_LDB_IMM .macro  val
   lda #<\val
   sta FP_B
   lda #>\val
   sta FP_B+1
.endmacro

FP_LDA_IMM_INT .macro  val
   stz FP_A
   lda #\val
   sta FP_A+1
.endmacro

FP_LDB_IMM_INT .macro  val
   stz FP_B
   lda #\val
   sta FP_B+1
.endmacro

FP_STC .macro addr
   lda FP_C
   sta \addr
   lda FP_C+1
   sta \addr+1
.endmacro

fp_floor_byte: ; A = floor(FP_C)
   lda FP_C+1
   and #$80
   beq return$
   lda FP_C
   cmp #0
   bne decc$
   lda FP_C+1
   rts
decc$:
   lda FP_C
   dec
return$:
   rts

fp_floor: ; FP_C = floor(FP_C)
   bit FP_C+1
   bpl zerofrac$
   lda FP_C
   cmp #0
   beq zerofrac$
   dec FP_C+1
zerofrac$:
   stz FP_C
   rts

FP_TCA .macro  ; FP_A = FP_C
   lda FP_C
   sta FP_A
   lda FP_C+1
   sta FP_A+1
.endmacro

FP_TCB .macro  ; FP_B = FP_C
   lda FP_C
   sta FP_B
   lda FP_C+1
   sta FP_B+1
.endmacro

fp_subtract: ; FP_C = FP_A - FP_B
   lda FP_A
   sec
   sbc FP_B
   sta FP_C
   lda FP_A+1
   sbc FP_B+1
   sta FP_C+1
   rts

fp_add: ; FP_C = FP_A + FP_B
   lda FP_A
   clc
   adc FP_B
   sta FP_C
   lda FP_A+1
   adc FP_B+1
   sta FP_C+1
   rts

fp_divide: ; FP_C = FP_A / FP_B; FP_R = FP_A % FP_B
   phx
   phy
   lda FP_B
   pha
   lda FP_B+1
   pha ; preserve original B on stack
   bit FP_A+1
   bmi abs_a$
   lda FP_A
   sta FP_C
   lda FP_A+1
   sta FP_C+1
   bra check_sign_b$
abs_a$:
   lda #0
   sec
   sbc FP_A
   sta FP_C
   lda #0
   sbc FP_A+1
   sta FP_C+1 ; C = |A|
check_sign_b$:
   bit FP_B+1
   bpl shift_b$
   lda #0
   sec
   sbc FP_B
   sta FP_B
   lda #0
   sbc FP_B+1
   sta FP_B+1
shift_b$:
   lda FP_B+1
   sta FP_B
   lda #0
   sta FP_B+1
   stz FP_R
   stz FP_R+1
   ldx #16     ;There are 16 bits in C
loop1$:
   asl FP_C    ;Shift hi bit of C into REM
   rol FP_C+1  ;(vacating the lo bit, which will be used for the quotient)
   rol FP_R
   rol FP_R+1
   lda FP_R
   sec         ;Trial subtraction
   sbc FP_B
   tay
   lda FP_R+1
   sbc FP_B+1
   bcc loop2$  ;Did subtraction succeed?
   sta FP_R+1   ;If yes, save it
   sty FP_R
   inc FP_C    ;and record a 1 in the quotient
loop2$:
   dex
   bne loop1$
   pla
   sta FP_B+1
   pla
   sta FP_B
   bit FP_B+1
   bmi check_cancel$
   bit FP_A+1
   bmi negative$
   bra return$
check_cancel$:
   bit FP_A+1
   bmi return$
negative$:
   lda #0
   sec
   sbc FP_C
   sta FP_C
   lda #0
   sbc FP_C+1
   sta FP_C+1
return$:
   ply
   plx
   rts

fp_multiply: ; FP_C = FP_A * FP_B; FP_R overflow
   phx
   phy
   ; push original A and B to stack
   lda FP_A
   pha
   lda FP_A+1
   pha
   lda FP_B
   pha
   lda FP_B+1
   pha
   bit FP_A+1
   bpl check_sign_b$
   lda #0
   sec
   sbc FP_A
   sta FP_A
   lda #0
   sbc FP_A+1
   sta FP_A+1 ; A = |A|
check_sign_b$:
   bit FP_B+1
   bpl init_c$
   lda #0
   sec
   sbc FP_B
   sta FP_B
   lda #0
   sbc FP_B+1
   sta FP_B+1 ; B = |B|
init_c$:
   lda #0
   sta FP_R
   sta FP_C
   sta FP_C+1
   ldx #16
loop1$:
   lsr FP_B+1
   ror FP_B
   bcc loop2$
   tay
   clc
   lda FP_A
   adc FP_R
   sta FP_R
   tya
   adc FP_A+1
loop2$:
   ror
   ror FP_R
   ror FP_C+1
   ror FP_C
   dex
   bne loop1$
   sta FP_R+1
   ldx #8
loop3$:
   lsr FP_R+1
   ror FP_R
   ror FP_C+1
   ror FP_C
   dex
   bne loop3$
   ; restore A and B
   pla
   sta FP_B+1
   pla
   sta FP_B
   pla
   sta FP_A+1
   pla
   sta FP_A
   bit FP_B+1
   bmi check_cancel$
   bit FP_A+1
   bmi negative$
   bra return$
check_cancel$:
   bit FP_A+1
   bmi return$
negative$:
   lda #0
   sec
   sbc FP_C
   sta FP_C
   lda #0
   sbc FP_C+1
   sta FP_C+1
return$:
   ply
   plx
   rts

; Optimised version of SQUARE FP_A, only have to check neg at start, no need to neg at end as squares are ALWAYS positve
fp_square: ; FP_C = FP_A * FP_A; FP_R overflow
   phx
   phy
   ; push original FP_A to stack & copy to FP_B
   lda FP_A
   sta FP_B
   pha
   lda FP_A+1
   sta FP_B+1
   pha
   bit FP_A+1
   bpl init_c$
   lda #0
   sec
   sbc FP_A
   sta FP_A
   sta FP_B
   lda #0
   sbc FP_A+1
   sta FP_A+1 ; A = |A|
   sta FP_B+1 ; B = |A|
init_c$:
   lda #0
   sta FP_R
   sta FP_C
   sta FP_C+1
   ldx #16
loop1$:
   lsr FP_B+1
   ror FP_B
   bcc loop2$
   tay
   clc
   lda FP_A
   adc FP_R
   sta FP_R
   tya
   adc FP_A+1
loop2$:
   ror
   ror FP_R
   ror FP_C+1
   ror FP_C
   dex
   bne loop1$
   sta FP_R+1
   ldx #8
loop3$:
   lsr FP_R+1
   ror FP_R
   ror FP_C+1
   ror FP_C
   dex
   bne loop3$
   ; restore A
   pla
   sta FP_A+1
   pla
   sta FP_A
return$:
   ply
   plx
   rts

cp_multiply: ; FP_C = FP_A * FP_B; FP_R overflow
   phx
   phy
   ; push original A and B to stack
   lda FP_A
   pha
   lda FP_A+1
   pha
   lda FP_B
   pha
   lda FP_B+1
   pha
   bit FP_A+1
   bpl check_sign_b$
   lda #0
   sec
   sbc FP_A
   sta FP_A
   lda #0
   sbc FP_A+1
   sta FP_A+1 ; A = |A|
check_sign_b$:
   bit FP_B+1
   bpl init_c$
   lda #0
   sec
   sbc FP_B
   sta FP_B
   lda #0
   sbc FP_B+1
   sta FP_B+1 ; B = |B|
init_c$:
; The magic happens here
   ; Init C and R
   lda FP_A
   sta CP_A
   lda FP_B
   sta CP_B
   lda CP_MH
   sta FP_C

   lda FP_A+1
   sta CP_A
   clc
   lda FP_C
   adc CP_ML
   sta FP_C
   lda #0
   adc CP_MH
   sta FP_C+1

   lda FP_A
   sta CP_A
   lda FP_B+1
   sta CP_B
   clc
   lda FP_C
   adc CP_ML
   sta FP_C
   lda FP_C+1
   adc CP_MH
   sta FP_C+1

   lda FP_A+1
   sta CP_A
   clc
   lda FP_C+1
   adc CP_ML
   sta FP_C+1
   lda #0
   adc CP_MH
   sta FP_R
   ; restore A and B
   pla
   sta FP_B+1
   pla
   sta FP_B
   pla
   sta FP_A+1
   pla
   sta FP_A
   bit FP_B+1
   bmi check_cancel$
   bit FP_A+1
   bmi negative$
   bra return$
check_cancel$:
   bit FP_A+1
   bmi return$
negative$:
   lda #0
   sec
   sbc FP_C
   sta FP_C
   lda #0
   sbc FP_C+1
   sta FP_C+1
return$:
   ply
   plx
   rts

; Use co-pro lookup for squares: $10 MSB $18 LSB. result $04,$05,$06,$07 LSB to MSB
cp_square:
   phx
   phy
   ; push original FP_A to stack & copy to FP_B
   lda FP_A
   pha
   lda FP_A+1
   pha
   ; Make A positive
   bit FP_A+1
   bpl square_c$
   lda #0
   sec
   sbc FP_A
   sta FP_A
   lda #0
   sbc FP_A+1
   sta FP_A+1 ; A = |A|
square_c$:
   lda FP_A
   sta CP_B
   lda FP_A+1
   sta CP_A

   lda CP_S1
   sta FP_C
   lda CP_S2
   sta FP_C+1
   lda CP_S3
   sta FP_R

   pla
   sta FP_A+1
   pla
   sta FP_A
return$:
   ply
   plx
   rts
