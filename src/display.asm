; =============================================================================
; DISPLAY MODULE
; =============================================================================
; Screen routines for Rachel ZX Spectrum client
;
; Uses ROM routines where possible:
;   RST $10 - Print character (respects current attributes)
;   ROM_CLS - Clear screen
;   CHAN_OPEN - Select output channel

; =============================================================================
; UDG CHARACTER DATA
; =============================================================================
; Four custom characters for card suits
; UDG characters are accessed as CHR$ 144-164 (A-U)
; We use A=Heart, B=Diamond, C=Club, D=Spade

udg_data:
; UDG A - Heart (♥)
udg_heart:
        defb %00000000
        defb %01101100
        defb %11111110
        defb %11111110
        defb %11111110
        defb %01111100
        defb %00111000
        defb %00010000

; UDG B - Diamond (♦)
udg_diamond:
        defb %00000000
        defb %00010000
        defb %00111000
        defb %01111100
        defb %11111110
        defb %01111100
        defb %00111000
        defb %00010000

; UDG C - Club (♣)
udg_club:
        defb %00000000
        defb %00010000
        defb %01111100
        defb %01111100
        defb %11111110
        defb %11111110
        defb %00010000
        defb %00111000

; UDG D - Spade (♠)
udg_spade:
        defb %00000000
        defb %00010000
        defb %00111000
        defb %01111100
        defb %11111110
        defb %11111110
        defb %00010000
        defb %00111000

UDG_HEART   equ 144             ; CHR$ code for UDG A
UDG_DIAMOND equ 145             ; CHR$ code for UDG B
UDG_CLUB    equ 146             ; CHR$ code for UDG C
UDG_SPADE   equ 147             ; CHR$ code for UDG D

; =============================================================================
; DISPLAY ROUTINES
; =============================================================================

; -----------------------------------------------------------------------------
; Initialize display - clear screen, set up UDGs
; -----------------------------------------------------------------------------
display_init:
        ; Set border to black
        xor a
        out ($FE), a

        ; Clear screen
        call ROM_CLS

        ; Copy UDG data to UDG area
        ld hl, udg_data
        ld de, (23675)          ; UDG system variable points to UDG area
        ld bc, 32               ; 4 characters * 8 bytes
        ldir

        ; Set default attributes (white on black)
        ld a, INK_WHITE | PAPER_BLACK
        ld (23693), a           ; ATTR_P system variable

        ; Open channel 2 (main screen)
        ld a, 2
        call CHAN_OPEN

        ret

; -----------------------------------------------------------------------------
; Clear screen
; -----------------------------------------------------------------------------
clear_screen:
        call ROM_CLS
        ret

; -----------------------------------------------------------------------------
; Print character in A at current position
; Uses RST $10 (ROM print routine)
; -----------------------------------------------------------------------------
print_char:
        rst $10
        ret

; -----------------------------------------------------------------------------
; Print null-terminated string at HL
; -----------------------------------------------------------------------------
print_string:
        ld a, (hl)
        or a
        ret z                   ; Return if null terminator
        rst $10
        inc hl
        jr print_string

; -----------------------------------------------------------------------------
; Set cursor position
; Input: B = row (0-23), C = column (0-31)
; -----------------------------------------------------------------------------
set_cursor:
        ld a, 22                ; AT control code
        rst $10
        ld a, b                 ; Row
        rst $10
        ld a, c                 ; Column
        rst $10
        ret

; -----------------------------------------------------------------------------
; Set ink colour
; Input: A = colour (0-7)
; -----------------------------------------------------------------------------
set_ink:
        push af
        ld a, 16                ; INK control code
        rst $10
        pop af
        rst $10
        ret

; -----------------------------------------------------------------------------
; Set paper colour
; Input: A = colour (0-7)
; -----------------------------------------------------------------------------
set_paper:
        push af
        ld a, 17                ; PAPER control code
        rst $10
        pop af
        rst $10
        ret

; -----------------------------------------------------------------------------
; Set bright on/off
; Input: A = 0 (off) or 1 (on)
; -----------------------------------------------------------------------------
set_bright:
        push af
        ld a, 19                ; BRIGHT control code
        rst $10
        pop af
        rst $10
        ret

; -----------------------------------------------------------------------------
; Reset to default colours (white on black)
; -----------------------------------------------------------------------------
reset_colours:
        ld a, INK_WHITE
        call set_ink
        ld a, 0
        call set_paper
        xor a
        call set_bright
        ret

; -----------------------------------------------------------------------------
; Print horizontal line of dashes
; Input: B = row, C = starting column, E = length
; -----------------------------------------------------------------------------
print_hline:
        call set_cursor
ph_loop:
        ld a, '-'
        rst $10
        dec e
        jr nz, ph_loop
        ret

; -----------------------------------------------------------------------------
; Print a number (0-99) at current position
; Input: A = number
; -----------------------------------------------------------------------------
print_number:
        cp 10
        jr c, pn_single

        ; Two digits
        ld b, 0
pn_tens:
        cp 10
        jr c, pn_print_tens
        sub 10
        inc b
        jr pn_tens

pn_print_tens:
        push af
        ld a, b
        add a, '0'
        rst $10
        pop af

pn_single:
        add a, '0'
        rst $10
        ret

; -----------------------------------------------------------------------------
; Draw the game screen frame
; -----------------------------------------------------------------------------
draw_game_screen:
        ; Title row
        ld bc, $0000            ; Row 0, Col 0
        call set_cursor
        ld hl, txt_title
        call print_string

        ; Player area divider (row 3)
        ld b, 3
        ld c, 0
        ld e, 32
        call print_hline

        ; Discard area divider (row 11)
        ld b, 11
        ld c, 0
        ld e, 32
        call print_hline

        ; Hand area divider (row 19)
        ld b, 19
        ld c, 0
        ld e, 32
        call print_hline

        ; Hand label
        ld bc, $0C00            ; Row 12, Col 0
        call set_cursor
        ld hl, txt_your_hand
        call print_string

        ret

txt_title:
        defb "RACHEL", 0

txt_your_hand:
        defb "YOUR HAND:", 0

; -----------------------------------------------------------------------------
; Print card suit character with appropriate colour
; Input: A = suit (0=hearts, 1=diamonds, 2=clubs, 3=spades)
; -----------------------------------------------------------------------------
print_suit:
        push af

        ; Set colour - red for hearts/diamonds
        cp 2
        jr nc, ps_black
        ld a, INK_RED
        call set_ink
        jr ps_print

ps_black:
        ld a, INK_WHITE
        call set_ink

ps_print:
        pop af

        ; Get UDG character code
        add a, UDG_HEART        ; 144 + suit = UDG code
        rst $10

        ; Reset to white
        ld a, INK_WHITE
        call set_ink
        ret
