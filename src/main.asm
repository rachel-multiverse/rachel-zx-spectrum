; =============================================================================
; RACHEL ZX SPECTRUM - MAIN ENTRY POINT
; =============================================================================
; A render-only client for the Rachel card game.
; Connects to iOS host via Next WiFi or Spectranet.
;
; Assemble with Pasmo:
;   pasmo --equ NEXT=1 src/main.asm build/rachel-next.bin
;   pasmo --tapbas --equ SPECTRANET=1 src/main.asm build/rachel-snet.tap

; =============================================================================
; INCLUDES - DEFINITIONS ONLY (no code)
; =============================================================================

        include "src/buffers.asm"

; =============================================================================
; PROGRAM START
; =============================================================================

        org PROG_START          ; $6000

; =============================================================================
; ENTRY POINT
; =============================================================================

start:
        ; Disable interrupts during setup
        di

        ; Initialize variables
        call init_variables

        ; Initialize display
        call display_init

        ; Draw initial screen
        call draw_game_screen

        ; Show welcome message
        ld b, 10
        ld c, 6
        call set_cursor
        ld hl, txt_welcome
        call print_string

        ; Show instructions
        ld b, 23
        ld c, 0
        call set_cursor
        ld hl, txt_press_key
        call print_string

        ; Enable interrupts
        ei

        ; Wait for keypress
        call wait_key

connect_loop:
        ; Get IP address
        call input_ip_address
        or a
        jr z, start             ; Empty, restart

        ; Attempt connection
        call do_connect
        or a
        jr nz, conn_failed

        ; Wait for game to start
        call wait_for_game
        or a
        jr nz, conn_failed

        ; Enter game loop
        jr game_loop

conn_failed:
        call wait_key
        jr start

; =============================================================================
; MAIN GAME LOOP
; =============================================================================

game_loop:
        ; Initial draw
        call redraw_game

gl_main:
        ; Check for network messages
        call check_network

        ; Check for keyboard input
        call check_game_input

        ; Small delay
        halt                    ; Wait for vsync

        jr gl_main

; -----------------------------------------------------------------------------
; Check for incoming network messages
; -----------------------------------------------------------------------------
check_network:
        ; TODO: Non-blocking check
        ; For now, this is blocking which isn't ideal
        ; Would need uart_available check first
        ret

; -----------------------------------------------------------------------------
; Check for keyboard input during game
; -----------------------------------------------------------------------------
check_game_input:
        call check_key
        or a
        ret z                   ; No key

        ; Check if our turn
        ld hl, current_turn
        ld b, (hl)
        ld a, (my_index)
        cp b
        ret nz                  ; Not our turn

        ; Handle input
        ld a, (temp1)           ; Get key back... actually check_key returns in A

        ; Re-read key
        call check_key
        or a
        ret z

        ; Cursor left (O or 5)
        cp 'o'
        jr z, cgi_left
        cp 'O'
        jr z, cgi_left
        cp '5'
        jr z, cgi_left

        ; Cursor right (P or 8)
        cp 'p'
        jr z, cgi_right
        cp 'P'
        jr z, cgi_right
        cp '8'
        jr z, cgi_right

        ; Select (SPACE)
        cp ' '
        jr z, cgi_select

        ; Play (ENTER)
        cp 13
        jr z, cgi_play

        ; Draw (D)
        cp 'd'
        jr z, cgi_draw
        cp 'D'
        jr z, cgi_draw

        ret

cgi_left:
        ld a, (cursor_pos)
        or a
        jr z, cgi_wrap_left
        dec a
        ld (cursor_pos), a
        jr cgi_update

cgi_wrap_left:
        ld a, (hand_count)
        dec a
        ld (cursor_pos), a
        jr cgi_update

cgi_right:
        ld a, (cursor_pos)
        inc a
        ld hl, hand_count
        cp (hl)
        jr c, cgi_right_ok
        xor a                   ; Wrap to 0
cgi_right_ok:
        ld (cursor_pos), a
        jr cgi_update

cgi_select:
        ; Toggle selection bit
        ld a, (cursor_pos)
        cp 8
        ret nc                  ; Only first 8 cards selectable

        ld b, a
        ld a, 1

cgi_shift:
        dec b
        jp m, cgi_toggle
        rlca
        jr cgi_shift

cgi_toggle:
        ld hl, selected_mask
        xor (hl)
        ld (hl), a
        jr cgi_update

cgi_play:
        ; Check if any selected
        ld a, (selected_mask)
        or a
        ret z

        ; Check for Ace (need suit nomination)
        call check_for_ace
        or a
        jr z, cgi_send_play

        ; Get suit nomination
        call get_suit_nomination
        jr cgi_send_play_suit

cgi_send_play:
        ld a, $FF               ; No nomination
        call rubp_send_play_card
        jr cgi_clear_sel

cgi_send_play_suit:
        ; A already has suit from get_suit_nomination
        call rubp_send_play_card

cgi_clear_sel:
        xor a
        ld (selected_mask), a
        ld (selected_mask + 1), a

cgi_update:
        call draw_hand
        ret

cgi_draw:
        xor a                   ; Reason: can't play
        call rubp_send_draw_card
        ret

; -----------------------------------------------------------------------------
; Check if any selected card is an Ace (rank 14)
; Returns: A = 0 if no ace, 1 if ace selected
; -----------------------------------------------------------------------------
check_for_ace:
        ld hl, MY_HAND
        ld de, (selected_mask)
        ld a, (hand_count)
        ld b, a

cfa_loop:
        bit 0, e
        jr z, cfa_next

        ; Selected - check rank
        ld a, (hl)
        and $3F
        cp 14                   ; Ace?
        jr z, cfa_found

cfa_next:
        inc hl
        srl d
        rr e
        djnz cfa_loop

        xor a                   ; No ace
        ret

cfa_found:
        ld a, 1
        ret

; -----------------------------------------------------------------------------
; Get suit nomination from user
; Returns: A = suit (0-3)
; -----------------------------------------------------------------------------
get_suit_nomination:
        ld b, 23
        ld c, 0
        call set_cursor
        ld hl, txt_nominate
        call print_string

gsn_wait:
        call wait_key

        cp 'h'
        jr z, gsn_hearts
        cp 'H'
        jr z, gsn_hearts
        cp 'd'
        jr z, gsn_diamonds
        cp 'D'
        jr z, gsn_diamonds
        cp 'c'
        jr z, gsn_clubs
        cp 'C'
        jr z, gsn_clubs
        cp 's'
        jr z, gsn_spades
        cp 'S'
        jr z, gsn_spades

        jr gsn_wait

gsn_hearts:
        xor a
        ret
gsn_diamonds:
        ld a, 1
        ret
gsn_clubs:
        ld a, 2
        ret
gsn_spades:
        ld a, 3
        ret

txt_nominate:
        defb "SUIT? H/D/C/S                   ", 0

; =============================================================================
; INITIALIZATION
; =============================================================================

init_variables:
        ; Clear variable area
        ld hl, VAR_BASE
        ld de, VAR_BASE + 1
        ld bc, 31
        ld (hl), 0
        ldir

        ; Clear game buffers
        ld hl, PLAYER_COUNTS
        ld de, PLAYER_COUNTS + 1
        ld bc, 127
        ld (hl), 0
        ldir

        ; Initialize sequence to 1
        ld a, 1
        ld (sequence), a

        ret

; =============================================================================
; DATA
; =============================================================================

txt_welcome:
        defb "RACHEL ZX SPECTRUM", 0

txt_press_key:
        defb "PRESS ANY KEY TO CONNECT...", 0

; =============================================================================
; MODULE INCLUDES
; =============================================================================

        include "src/display.asm"
        include "src/input.asm"
        include "src/rubp.asm"
        include "src/game.asm"
        include "src/connect.asm"

; Network driver - conditional
        IF NEXT
        include "src/net/next.asm"
        ENDIF

        IF SPECTRANET
        include "src/net/spectranet.asm"
        ENDIF

; =============================================================================
; END
; =============================================================================
