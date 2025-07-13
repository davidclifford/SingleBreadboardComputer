.segment "CODE"
; ----------------------------------------------------------------------------
; SEE IF CONTROL-C TYPED
; ----------------------------------------------------------------------------
.ifdef EATER
.include "eater_iscntc.s"
.endif
.ifdef SBB
.include "sbb_iscntc.s"
.endif
;!!! runs into "STOP"
