.setcpu "65C02"
.debuginfo
.segment "BIOS"

; Needs to be included in a user-code program (see examples)
; Serial communication is done with 115200 baud @ 10 Mhz CPU speed
; (each bit takes 87 clock cycles).

.macro DELAY2
    NOP
.endmacro
.macro DELAY5
    JMP :+
:   NOP
.endmacro
.macro DELAY10
    NOP
    NOP
    NOP
    NOP
    NOP
.endmacro

boot:
    SEI       ; disable interrupts
    CMP $00   ; set output to high
    ; initial delay to await reset bouncing
    LDX #0
:   INX
    BNE :-
    ; set up stack in case it was damaged
    LDX #$FF
    TXS
    ; call user code
    JSR main
    ; delay
    LDX #0
    LDY #0
:   INY
    BNE :-
    INX
    BNE :-
    JMP boot


    ; send null-terminated string
    ; parameter: Y,X = address of string (X = high byte)
    ; overwrite zero page $00,$01
sendstr:
    ; pointer
    STY $00
    STX $01
sendstrloop:
    LDY #0
    LDA ($00),Y
    BEQ sendstrend
    JSR send
    INC $00
    BNE sendstrloop
    INC $01
    JMP sendstrloop
sendstrend:
    RTS


    ; send 2-digit hexadecimal representation of a number
    ; parameter: A = number
sendhex:
    LDX #16
    JSR sendhighdigit
    LDX #1
    JMP sendhighdigit


    ; send decimal representation of a number
    ; parameter: A = number
sendnum:
    CMP #10
    BCC sendnum1digits
    CMP #100
    BCC sendnum2digits
    LDX #100
    JSR sendhighdigit
sendnum2digits:
    LDX #10
    JSR sendhighdigit
sendnum1digits:
    LDX #1
    JMP sendhighdigit


    ; send highest digit of a number and return the number
    ; without this digit
    ; parameter: A = number
    ;            X = value of one digit (e.g. 100)
    ; return:    A = number without highest digit
sendhighdigit:
    LDY $00  ; keep temporarily
    STX $00
    LDX #48  ; ascii '0'
:   CMP $00
    BCC highestdigitcomputed     ; if A < digit
    SEC
    SBC $00
    INX
    JMP :-
highestdigitcomputed:
    STY $00  ;  repair zero page
    PHA
    TXA
    CMP #58
    BCC :+          ; if A < 58
    CLC
    ADC #7
:   JSR send
    PLA
    RTS


    ; send one byte via serial
    ; does not damage any zero page data
    ; parameter: A
ECHO:
send:
    PHX
    PHA
    EOR #$FF ; use inverted bits, so stop-bit matches up
    LDX #10  ; send 10 bits total
    SEC      ; prepare inverted start bit
sendloop:                               ;  total cycles
    BCC setoutputhigh                   ;  0     2/3
setoutputlow:                           ;
    INC $8000  ; multibyte-operation    ;  2     6
    JMP setoutputdone                   ;  8     3
setoutputhigh:
    CMP $00    ; any access to RAM      ;  3     3
    CMP $00                             ;  6     3
    DELAY2                              ;  9     2
setoutputdone:                          ;  11
    DELAY10                             ;  11    10
    DELAY10                             ;  21    10
    DELAY10                             ;  31    10
    DELAY10                             ;  41    10
    DELAY10                             ;  51    10
    DELAY10                             ;  61    10
    DELAY5                              ;  71    5
    DELAY2                              ;  76    2
    DELAY2                              ;  78    2
    LSR  ; next bit (when empty, 0)     ;  80    2
    DEX                                 ;  82    2
    BNE sendloop                        ;  84    3
                                        ;  87
    PLA
    PLX
    RTS


    ; receive a burst of serial data.
    ; parameter: Y,X = address of buffer (X = high byte)
    ;            A = length of buffer
    ; return A = number of bytes received
    ; overwrite zero page $00 - $03
receiveburst:
    STY $00  ; buffer address lo
    STX $01  ; buffer address high
    STA $02  ; buffer size
    LDA #0
    STA $03  ; bytes received
    CMP $02
    BEQ receiveburstend  ; buffer full?
    LDA #0   ; wait indefinitely for 1. byte
    JSR receive
    LDY #0
    STA ($00),Y
    INC $03
continuereceiveburst:
    LDA $03
    CMP $02
    BEQ receiveburstend
    LDA #100 ; wait some time to see if burst continues
    JSR receive
    CPX #0
    BEQ receiveburstend
    LDY $03
    STA ($00),Y
    INC $03
    JMP continuereceiveburst
receiveburstend:
    LDA $03
    RTS


    ; receive serial data.
    ; parameter: A = time to wait for data (when 0: indefinite)
    ; return:    A = received byte
    ;            X = number of bytes received (1 or 0 in case of timeout)
CHRIN:
    LDA #0
receive:
    PHX
    PHY
    TAX
    ; wait for low state (start of start bit)
    CLC
    CLI
waitforstartbit:
    BCS startbitfound
    TXA
    BCS startbitfound
    BEQ waitforstartbit
    BCS startbitfound
    DEX
    BCS startbitfound
    BNE waitforstartbit
    BCS startbitfound
    SEI
    BCS startbitfound
    LDX #0
    PLY
    PLX
    RTS
startbitfound:                 ; approx. 30 after edge
    SEI                        ; 30    2
    LDA #0  ; buffer           ; 32    3
    LDX #8  ; bit counter      ; 35    3
    DELAY10                    ; 38    10
    DELAY10                    ; 48    10
    DELAY10                    ; 58    10
    DELAY10                    ; 68    10
    DELAY10                    ; 78    10
    DELAY10                    ; 88    10
    DELAY10                    ; 98    10
    DELAY10                    ; 108   10
       ; <- middle of 1. bit   ; 118
bitreceiveloop:                ;
    CLC                        ; 0     2
    CLI                        ; 2     2
      ; <- possible interrupt     4     0/26
    SEI                        ; 4/30  2
    BCS @skip                  ; 6/32  2/3
    DELAY10                    ; 8     10
    DELAY10                    ; 18    10
    DELAY5                     ; 28    5
    DELAY2                     ; 33    2
@skip:
    ROR                        ; 35    2
    DELAY10                    ; 37    10
    DELAY10                    ; 47    10
    DELAY10                    ; 57    10
    DELAY10                    ; 67    10
    DELAY2                     ; 77    2
    DELAY2                     ; 79    2
    DEX                        ; 81    2
    BNE bitreceiveloop         ; 83    3/2
                               ; 86  ???
    ; revert input bits
    EOR #$FF
    LDX #1
waitforstopbit:
    CLC
    CLI
      ; <- possible interrupt
    SEI
    BCS waitforstopbit
    PLY
    PLX
    RTS

; Dummy routines for loading and saving
SAVE:
    RTS
LOAD:
    RTS

    ; Interrupt handler to trigger when the IRQB pin is low.
    ; It will just set the C flag (and overwrite the Y register).
    ; Also it will disable interrupts upon exit.
    ; Other flags remain unchanged
irqhandler:                     ;
    TAY                         ; 7     2
    PLA                         ; 9     4
    ORA #$05                    ; 13    2
    PHA                         ; 15    3
    TYA                         ; 18    2
    RTI                         ; 20    6
                                ; 26

.include "wozmon.s"

    ; vector table
.segment "RESETVEC"
    .word boot       ; NMIB
    .word boot       ; RESB
    .word irqhandler ; BRK/IRQB
