; =============================================================================
; GAME MODULE
; =============================================================================
; Card display and game state rendering

; Card Encoding (from RUBP spec):
;   Bits 7-6: Suit (00=Hearts, 01=Diamonds, 10=Clubs, 11=Spades)
;   Bits 5-0: Rank (2-14, where 11=J, 12=Q, 13=K, 14=A)

; =============================================================================
; CARD DISPLAY
; =============================================================================

; -----------------------------------------------------------------------------
; Decode card byte
; Input: A = encoded card
; Output: B = suit (0-3), C = rank (2-14)
; -----------------------------------------------------------------------------
decode_card:
        ld c, a
        and $3F                 ; Mask lower 6 bits = rank
        ld b, a                 ; Save rank temporarily

        ld a, c
        rrca
        rrca
        rrca
        rrca
        rrca
        rrca                    ; Shift suit to bits 0-1
        and $03
        ld c, b                 ; C = rank
        ld b, a                 ; B = suit
        ret

; -----------------------------------------------------------------------------
; Print card (e.g., "7♥")
; Input: A = encoded card
; Clobbers: AF, BC, DE, HL
; -----------------------------------------------------------------------------
print_card:
        call decode_card        ; B=suit, C=rank

        ; Print rank character
        push bc
        ld a, c                 ; Rank
        ld hl, rank_chars
        ld d, 0
        ld e, a
        add hl, de
        ld a, (hl)
        rst $10
        pop bc

        ; Print suit (with colour)
        ld a, b
        call print_suit

        ; Space after card
        ld a, ' '
        rst $10
        ret

rank_chars:
        defb "??23456789TJQKA"

; -----------------------------------------------------------------------------
; Draw player's hand (rows 13-16)
; Shows cards with >< selection brackets
; -----------------------------------------------------------------------------
draw_hand:
        ; Position at row 13
        ld b, 13
        ld c, 0
        call set_cursor

        ; Get hand count
        ld a, (hand_count)
        or a
        ret z                   ; No cards

        ld ixl, a               ; Card count in IXL
        ld ixh, 0               ; Card index in IXH

        ld hl, MY_HAND
        ld de, (selected_mask)  ; DE = selection bitmask

dh_loop:
        ; Check if at cursor position (highlight)
        ld a, (cursor_pos)
        cp ixh
        jr nz, dh_not_cursor

        ; Highlight - set bright
        ld a, 1
        call set_bright

dh_not_cursor:
        ; Check if selected (bit 0 of DE)
        bit 0, e
        jr z, dh_not_selected

        ; Selected - print >
        ld a, '>'
        rst $10
        jr dh_print_card

dh_not_selected:
        ld a, ' '
        rst $10

dh_print_card:
        ld a, (hl)
        push de
        push hl
        call print_card
        pop hl
        pop de

        ; Closing bracket if selected
        bit 0, e
        jr z, dh_no_close

        ld a, '<'
        rst $10
        jr dh_next

dh_no_close:
        ld a, ' '
        rst $10

dh_next:
        ; Reset brightness
        xor a
        call set_bright

        inc hl                  ; Next card
        inc ixh                 ; Increment index

        ; Shift selection mask
        srl d
        rr e

        ; Check for row wrap (6 cards per row)
        ld a, ixh
        cp 6
        jr nz, dh_no_wrap

        ; New row
        push hl
        push de
        ld b, 15                ; Row 15
        ld c, 0
        call set_cursor
        pop de
        pop hl

dh_no_wrap:
        ; More cards?
        ld a, ixh
        cp ixl
        jr c, dh_loop

        ret

; -----------------------------------------------------------------------------
; Draw discard pile (centered, rows 6-8)
; -----------------------------------------------------------------------------
draw_discard:
        ; Position
        ld b, 6
        ld c, 12
        call set_cursor

        ; Top of box
        ld hl, discard_top_line
        call print_string

        ; Middle row with card
        ld b, 7
        ld c, 12
        call set_cursor

        ld a, '|'
        rst $10
        ld a, ' '
        rst $10

        ; Print the top card
        ld a, (DISCARD_TOP)
        call print_card

        ld a, '|'
        rst $10

        ; Show nominated suit if active
        ld a, (NOMINATED_SUIT)
        cp $FF
        jr z, dd_no_nom

        ld a, ' '
        rst $10
        ld a, (NOMINATED_SUIT)
        call print_suit

dd_no_nom:
        ; Bottom of box
        ld b, 8
        ld c, 12
        call set_cursor

        ld hl, discard_bot_line
        call print_string

        ret

discard_top_line:
        defb "+----+", 0
discard_bot_line:
        defb "+----+", 0

; -----------------------------------------------------------------------------
; Draw player list (rows 1-2)
; -----------------------------------------------------------------------------
draw_players:
        ld ixl, 0               ; Player index

dp_loop:
        ld a, ixl
        cp MAX_PLAYERS
        ret z

        ; Check if player exists
        ld hl, PLAYER_COUNTS
        ld d, 0
        ld e, ixl
        add hl, de
        ld a, (hl)
        or a
        jr nz, dp_has_player

        ; Check if it's us
        ld a, (my_index)
        cp ixl
        jr nz, dp_next

dp_has_player:
        ; Calculate position: row = 1 + (index/4), col = (index mod 4) * 8
        ld a, ixl
        and $03                 ; mod 4
        rlca
        rlca
        rlca                    ; * 8
        ld c, a                 ; Column

        ld a, ixl
        rrca
        rrca                    ; / 4
        and $01
        inc a                   ; + 1
        ld b, a                 ; Row

        push bc
        call set_cursor

        ; Check if current turn
        ld a, (current_turn)
        cp ixl
        jr nz, dp_not_turn

        ld a, '>'
        rst $10
        jr dp_print_info

dp_not_turn:
        ld a, ' '
        rst $10

dp_print_info:
        ; Print "Pn:"
        ld a, 'P'
        rst $10
        ld a, ixl
        add a, '1'
        rst $10
        ld a, ':'
        rst $10

        ; Print card count
        ld hl, PLAYER_COUNTS
        ld d, 0
        ld e, ixl
        add hl, de
        ld a, (hl)
        call print_number

        pop bc

dp_next:
        inc ixl
        jr dp_loop

; -----------------------------------------------------------------------------
; Draw game info (row 10)
; -----------------------------------------------------------------------------
draw_game_info:
        ld b, 10
        ld c, 5
        call set_cursor

        ld hl, txt_deck
        call print_string

        ld a, (DECK_COUNT)
        call print_number

        ; Pending draws
        ld a, (PENDING_DRAWS)
        or a
        ret z

        ld a, ' '
        rst $10
        rst $10

        ld hl, txt_draw
        call print_string

        ld a, '+'
        rst $10

        ld a, (PENDING_DRAWS)
        call print_number

        ret

txt_deck:
        defb "DECK:", 0
txt_draw:
        defb "DRAW ", 0

; -----------------------------------------------------------------------------
; Draw status line (row 23)
; -----------------------------------------------------------------------------
draw_status:
        ld b, 23
        ld c, 0
        call set_cursor

        ; Clear line
        ld b, 32
ds_clear:
        ld a, ' '
        rst $10
        djnz ds_clear

        ; Reposition
        ld b, 23
        ld c, 0
        call set_cursor

        ; Check whose turn
        ld a, (current_turn)
        ld hl, my_index
        cp (hl)
        jr nz, ds_not_my_turn

        ld hl, txt_your_turn
        jr ds_print

ds_not_my_turn:
        ld hl, txt_waiting

ds_print:
        call print_string
        ret

txt_your_turn:
        defb "YOUR TURN - ARROWS, SPACE, P/D", 0
txt_waiting:
        defb "WAITING FOR OTHER PLAYERS...", 0

; -----------------------------------------------------------------------------
; Redraw entire game state
; -----------------------------------------------------------------------------
redraw_game:
        call draw_game_screen
        call draw_players
        call draw_discard
        call draw_game_info
        call draw_hand
        call draw_status
        ret

; -----------------------------------------------------------------------------
; Show winner screen
; -----------------------------------------------------------------------------
show_winner:
        ld b, 12
        ld c, 8
        call set_cursor

        ld a, (WINNER_INDEX)
        ld hl, my_index
        cp (hl)
        jr nz, sw_lose

        ld hl, txt_you_win
        call print_string
        ret

sw_lose:
        ld hl, txt_you_lose
        call print_string

        ld a, (WINNER_INDEX)
        add a, '1'
        rst $10
        ret

txt_you_win:
        defb "*** YOU WIN! ***", 0
txt_you_lose:
        defb "PLAYER ", 0
