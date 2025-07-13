ISCNTC:
        LDA #10
        jsr receive
        cmp #3
        bne not_cntc
        jmp is_cntc
not_cntc:
        rts
is_cntc:
        ; Fall through
