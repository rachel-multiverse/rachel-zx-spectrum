; =============================================================================
; INPUT MODULE
; =============================================================================
; Keyboard handling for Rachel ZX Spectrum client
;
; Spectrum keyboard is a matrix read via port $FE:
;   Address lines A8-A15 select half-rows
;   Data bits 0-4 return key states (0 = pressed)
;
; We also use the ROM routine at $028E for simpler key reading

; System variables
LAST_K          equ 23560       ; Last key pressed (ASCII)
FLAGS           equ 23611       ; Bit 5 = key available

; =============================================================================
; INPUT ROUTINES
; =============================================================================

; -----------------------------------------------------------------------------
; Wait for any key press (blocking)
; Returns: A = ASCII code of key
; -----------------------------------------------------------------------------
wait_key:
        ; Clear any pending key
        xor a
        ld (LAST_K), a
        res 5, (iy+1)           ; Clear key available flag

wk_loop:
        halt                    ; Wait for interrupt (keyboard scan)
        bit 5, (iy+1)           ; Key available?
        jr z, wk_loop

        ld a, (LAST_K)
        ret

; -----------------------------------------------------------------------------
; Check for key press (non-blocking)
; Returns: A = ASCII code if pressed, 0 if no key
; -----------------------------------------------------------------------------
check_key:
        bit 5, (iy+1)           ; Key available?
        jr z, ck_none

        res 5, (iy+1)           ; Clear flag
        ld a, (LAST_K)
        ret

ck_none:
        xor a
        ret

; -----------------------------------------------------------------------------
; Check specific key (non-blocking)
; Input: Half-row port in B, bit mask in C
; Returns: Z flag set if key pressed
; -----------------------------------------------------------------------------
check_specific_key:
        ld a, b
        in a, ($FE)
        and c
        ret                     ; Z if pressed (bit was 0)

; -----------------------------------------------------------------------------
; Check cursor keys
; Returns: A = direction (0=none, 1=left, 2=right, 3=up, 4=down)
; -----------------------------------------------------------------------------
check_cursor:
        ; Cursor keys on Spectrum:
        ; CAPS+5 = Left, CAPS+6 = Down, CAPS+7 = Up, CAPS+8 = Right
        ; Or just 5,6,7,8 without CAPS

        ; Check row 6-0 (port $EF): 6,7,8,9,0
        ld a, $EF
        in a, ($FE)

        bit 4, a                ; Key 6 (down)
        jr z, cc_down
        bit 3, a                ; Key 7 (up)
        jr z, cc_up
        bit 2, a                ; Key 8 (right)
        jr z, cc_right

        ; Check row 1-5 (port $F7): 1,2,3,4,5
        ld a, $F7
        in a, ($FE)
        bit 4, a                ; Key 5 (left)
        jr z, cc_left

        ; Also check O/P for left/right (common in games)
        ld a, $DF               ; Row Q-T (port $DF): Q,W,E,R,T
        in a, ($FE)
        ; No cursor keys here

        ld a, $BF               ; Row P-Y (port $BF): P,O,I,U,Y
        in a, ($FE)
        bit 0, a                ; P = right
        jr z, cc_right
        bit 1, a                ; O = left
        jr z, cc_left

        xor a                   ; No cursor key
        ret

cc_left:
        ld a, 1
        ret
cc_right:
        ld a, 2
        ret
cc_up:
        ld a, 3
        ret
cc_down:
        ld a, 4
        ret

; -----------------------------------------------------------------------------
; Check for SPACE (select)
; Returns: Z flag set if pressed
; -----------------------------------------------------------------------------
check_space:
        ld a, $7F               ; Row SPACE-B (port $7F)
        in a, ($FE)
        bit 0, a                ; SPACE is bit 0
        ret                     ; Z if pressed

; -----------------------------------------------------------------------------
; Check for ENTER
; Returns: Z flag set if pressed
; -----------------------------------------------------------------------------
check_enter:
        ld a, $BF               ; Row ENTER-H (port $BF)
        in a, ($FE)
        bit 0, a                ; ENTER is bit 0
        ret                     ; Z if pressed

; -----------------------------------------------------------------------------
; Input a line of text
; Input: HL = buffer address, B = max length
; Returns: A = actual length entered
; Clobbers: HL, BC, DE
; -----------------------------------------------------------------------------
input_line:
        push hl
        pop de                  ; DE = buffer start
        ld c, 0                 ; C = current length

        ; Show cursor
        ld a, '_'
        rst $10

il_loop:
        call wait_key

        ; Check for ENTER (done)
        cp 13
        jr z, il_done

        ; Check for DELETE
        cp 12                   ; DELETE key
        jr z, il_delete

        ; Check for printable
        cp 32
        jr c, il_loop           ; Ignore control chars
        cp 128
        jr nc, il_loop          ; Ignore high chars

        ; Check buffer full
        ld a, c
        cp b
        jr nc, il_loop          ; Buffer full

        ; Store character
        call wait_key           ; Re-read the key
        cp 13
        jr z, il_done
        cp 12
        jr z, il_delete
        cp 32
        jr c, il_loop

        ld (hl), a
        inc hl
        inc c

        ; Erase cursor, print char, new cursor
        ld a, 8                 ; Backspace
        rst $10
        ld a, (hl)
        dec hl
        ld a, (hl)
        inc hl
        rst $10
        ld a, '_'
        rst $10

        jr il_loop

il_delete:
        ; Check if anything to delete
        ld a, c
        or a
        jr z, il_loop

        dec hl
        dec c

        ; Erase cursor and character
        ld a, 8                 ; Backspace
        rst $10
        ld a, 8
        rst $10
        ld a, ' '
        rst $10
        ld a, 8
        rst $10
        ld a, '_'
        rst $10

        jr il_loop

il_done:
        ; Null terminate
        ld (hl), 0

        ; Erase cursor
        ld a, 8
        rst $10
        ld a, ' '
        rst $10

        ld a, c                 ; Return length
        ret
