; =============================================================================
; RUBP MODULE
; =============================================================================
; Rachel Unified Binary Protocol - 64-byte message handling
;
; Message format (64 bytes total):
;   Header (16 bytes):
;     0-3:   Magic "RACH"
;     4:     Version (0x01)
;     5:     Message type
;     6-7:   Sequence number (big-endian)
;     8-9:   Player ID (big-endian)
;     10-11: Game ID (big-endian)
;     12-15: Timestamp (big-endian, we use 0)
;   Payload (48 bytes): varies by message type

; =============================================================================
; RUBP ROUTINES
; =============================================================================

; -----------------------------------------------------------------------------
; Build message header in TX buffer
; Input: A = message type
; Clears TX buffer, writes header with magic, version, seq, player/game IDs
; -----------------------------------------------------------------------------
rubp_build_header:
        push af                 ; Save message type

        ; Clear TX buffer
        ld hl, NET_TX_BUF
        ld de, NET_TX_BUF + 1
        ld bc, RUBP_MSG_SIZE - 1
        ld (hl), 0
        ldir

        ; Magic bytes "RACH"
        ld hl, NET_TX_BUF + HDR_MAGIC
        ld (hl), 'R'
        inc hl
        ld (hl), 'A'
        inc hl
        ld (hl), 'C'
        inc hl
        ld (hl), 'H'

        ; Version
        ld a, $01
        ld (NET_TX_BUF + HDR_VERSION), a

        ; Message type
        pop af
        ld (NET_TX_BUF + HDR_TYPE), a

        ; Sequence number (big-endian: high byte first)
        ld a, (sequence + 1)    ; High byte
        ld (NET_TX_BUF + HDR_SEQUENCE), a
        ld a, (sequence)        ; Low byte
        ld (NET_TX_BUF + HDR_SEQUENCE + 1), a

        ; Increment sequence for next message
        ld hl, (sequence)
        inc hl
        ld (sequence), hl

        ; Player ID (big-endian)
        ld a, (player_id + 1)   ; High byte
        ld (NET_TX_BUF + HDR_PLAYER_ID), a
        ld a, (player_id)       ; Low byte
        ld (NET_TX_BUF + HDR_PLAYER_ID + 1), a

        ; Game ID (big-endian)
        ld a, (game_id + 1)     ; High byte
        ld (NET_TX_BUF + HDR_GAME_ID), a
        ld a, (game_id)         ; Low byte
        ld (NET_TX_BUF + HDR_GAME_ID + 1), a

        ; Timestamp = 0 (already cleared)
        ret

; -----------------------------------------------------------------------------
; Send TX buffer as complete 64-byte message
; Calls net_send (provided by network driver)
; -----------------------------------------------------------------------------
rubp_send:
        ld hl, NET_TX_BUF
        ld bc, RUBP_MSG_SIZE
        call net_send
        ret

; -----------------------------------------------------------------------------
; Receive 64-byte message into RX buffer
; Calls net_recv (provided by network driver)
; -----------------------------------------------------------------------------
rubp_receive:
        ld hl, NET_RX_BUF
        ld bc, RUBP_MSG_SIZE
        call net_recv
        ret

; -----------------------------------------------------------------------------
; Validate RX buffer has valid RUBP header
; Returns: Z flag set if valid (magic = "RACH"), Z clear if invalid
; -----------------------------------------------------------------------------
rubp_validate:
        ld hl, NET_RX_BUF + HDR_MAGIC
        ld a, (hl)
        cp 'R'
        ret nz
        inc hl
        ld a, (hl)
        cp 'A'
        ret nz
        inc hl
        ld a, (hl)
        cp 'C'
        ret nz
        inc hl
        ld a, (hl)
        cp 'H'
        ret                     ; Z if valid

; -----------------------------------------------------------------------------
; Get message type from RX buffer
; Returns: A = message type
; -----------------------------------------------------------------------------
rubp_get_type:
        ld a, (NET_RX_BUF + HDR_TYPE)
        ret

; -----------------------------------------------------------------------------
; Build and send HELLO message
; Input: HL = pointer to player name (null-terminated, max 16 chars)
; -----------------------------------------------------------------------------
rubp_send_hello:
        push hl                 ; Save name pointer

        ; Build header
        ld a, MSG_HELLO
        call rubp_build_header

        ; Copy player name to payload (max 16 chars)
        pop hl                  ; Source: player name
        ld de, NET_TX_BUF + PAYLOAD_START  ; Dest: payload
        ld b, 16                ; Max chars

rsh_copy:
        ld a, (hl)
        or a
        jr z, rsh_name_done
        ld (de), a
        inc hl
        inc de
        djnz rsh_copy

rsh_name_done:
        ; Platform ID at payload+16 (big-endian)
        ; ZX Spectrum = 0x0003
        ld a, $00
        ld (NET_TX_BUF + PAYLOAD_START + 16), a
        ld a, $03               ; Platform 3 = ZX Spectrum
        ld (NET_TX_BUF + PAYLOAD_START + 17), a

        ; Send message
        call rubp_send
        ret

; -----------------------------------------------------------------------------
; Parse WELCOME message from RX buffer
; Extracts: PlayerID, GameID, stores in variables
; -----------------------------------------------------------------------------
rubp_parse_welcome:
        ; Player ID (big-endian at payload+0,1)
        ld a, (NET_RX_BUF + PAYLOAD_START + 1)  ; Low byte
        ld (player_id), a
        ld a, (NET_RX_BUF + PAYLOAD_START)      ; High byte
        ld (player_id + 1), a

        ; Game ID (big-endian at payload+2,3)
        ld a, (NET_RX_BUF + PAYLOAD_START + 3)  ; Low byte
        ld (game_id), a
        ld a, (NET_RX_BUF + PAYLOAD_START + 2)  ; High byte
        ld (game_id + 1), a

        ; Player index at payload+5
        ld a, (NET_RX_BUF + PAYLOAD_START + 5)
        ld (my_index), a

        ; Update connection state
        ld a, CONN_WAITING
        ld (conn_state), a
        ret

; -----------------------------------------------------------------------------
; Parse GAME_STATE message from RX buffer
; Updates all game state variables
; -----------------------------------------------------------------------------
rubp_parse_game_state:
        ; Current player (payload+0)
        ld a, (NET_RX_BUF + PAYLOAD_START)
        ld (current_turn), a

        ; Direction (payload+1)
        ld a, (NET_RX_BUF + PAYLOAD_START + 1)
        ld (DIRECTION), a

        ; Top card (payload+2)
        ld a, (NET_RX_BUF + PAYLOAD_START + 2)
        ld (DISCARD_TOP), a

        ; Nominated suit (payload+3)
        ld a, (NET_RX_BUF + PAYLOAD_START + 3)
        ld (NOMINATED_SUIT), a

        ; Pending draws (payload+4)
        ld a, (NET_RX_BUF + PAYLOAD_START + 4)
        ld (PENDING_DRAWS), a

        ; Deck count (payload+6)
        ld a, (NET_RX_BUF + PAYLOAD_START + 6)
        ld (DECK_COUNT), a

        ; Player card counts (payload+7 to +14)
        ld hl, NET_RX_BUF + PAYLOAD_START + 7
        ld de, PLAYER_COUNTS
        ld bc, MAX_PLAYERS
        ldir

        ; Game over flag (payload+15)
        ld a, (NET_RX_BUF + PAYLOAD_START + 15)
        ld (GAME_OVER), a

        ; Winner index (payload+16)
        ld a, (NET_RX_BUF + PAYLOAD_START + 16)
        ld (WINNER_INDEX), a

        ret

; -----------------------------------------------------------------------------
; Parse GAME_START message (initial hand)
; Replaces hand with cards from message
; -----------------------------------------------------------------------------
rubp_parse_game_start:
        ; Card count at payload+0
        ld a, (NET_RX_BUF + PAYLOAD_START)
        ld (hand_count), a
        ld b, a                 ; B = count

        ; Copy cards to hand
        ld hl, NET_RX_BUF + PAYLOAD_START + 1
        ld de, MY_HAND
        or a
        ret z                   ; No cards

        ld c, 0                 ; BC = count (B already set, C=0)
        ldir
        ret

; -----------------------------------------------------------------------------
; Parse CARD_DRAWN message (append to hand)
; -----------------------------------------------------------------------------
rubp_parse_card_drawn:
        ; Card count at payload+0
        ld a, (NET_RX_BUF + PAYLOAD_START)
        ld b, a                 ; B = new cards count

        ; Get current hand end
        ld a, (hand_count)
        ld e, a
        ld d, 0
        ld hl, MY_HAND
        add hl, de              ; HL = end of hand

        push hl
        ex de, hl               ; DE = destination

        ; Copy new cards
        ld hl, NET_RX_BUF + PAYLOAD_START + 1
        ld c, 0                 ; BC = count
        ldir

        ; Update hand count
        pop hl                  ; Restore for calculation
        ld a, (hand_count)
        add a, b
        ld (hand_count), a

        ret

; -----------------------------------------------------------------------------
; Build and send PLAY_CARD message
; Plays cards marked in selected_mask
; Input: A = nominated suit ($FF if none)
; -----------------------------------------------------------------------------
rubp_send_play_card:
        push af                 ; Save nominated suit

        ; Build header
        ld a, MSG_PLAY_CARD
        call rubp_build_header

        ; Count selected cards and copy to payload
        ld hl, MY_HAND          ; Source
        ld de, NET_TX_BUF + PAYLOAD_START + 1  ; Dest (cards at +1)
        ld bc, (selected_mask)  ; Selection bitmask
        ld a, (hand_count)
        or a
        jr z, rspc_count_done

        push af                 ; Save hand count
        xor a
        ld (temp1), a           ; Card count in message

rspc_loop:
        ; Check if card selected (bit 0 of BC)
        bit 0, c
        jr z, rspc_not_sel

        ; Card selected - copy it
        push bc
        ld a, (hl)
        ld (de), a
        inc de
        ld a, (temp1)
        inc a
        ld (temp1), a
        pop bc

rspc_not_sel:
        inc hl                  ; Next card in hand
        srl b                   ; Shift bitmask right
        rr c

        pop af
        dec a
        push af
        jr nz, rspc_loop
        pop af

rspc_count_done:
        ; Store card count at payload+0
        ld a, (temp1)
        ld (NET_TX_BUF + PAYLOAD_START), a

        ; Nominated suit at payload+33
        pop af                  ; Restore nominated suit
        ld (NET_TX_BUF + PAYLOAD_START + 33), a

        ; Send
        call rubp_send
        ret

; -----------------------------------------------------------------------------
; Build and send DRAW_CARD message
; Input: A = reason (0=can't play, 1=attack penalty)
; -----------------------------------------------------------------------------
rubp_send_draw_card:
        push af                 ; Save reason

        ; Build header
        ld a, MSG_DRAW_CARD
        call rubp_build_header

        ; Reason at payload+0
        pop af
        ld (NET_TX_BUF + PAYLOAD_START), a

        ; Count at payload+1 (always 1 for manual draw)
        ld a, 1
        ld (NET_TX_BUF + PAYLOAD_START + 1), a

        ; Send
        call rubp_send
        ret
