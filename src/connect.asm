; =============================================================================
; CONNECT MODULE
; =============================================================================
; Handles connection flow: IP input -> connect -> handshake -> wait for game

; =============================================================================
; CONNECTION ROUTINES
; =============================================================================

; -----------------------------------------------------------------------------
; Input IP address from user
; Returns: A = length of input (0 if empty)
; Stores result in IP_INPUT_BUF
; -----------------------------------------------------------------------------
input_ip_address:
        ; Position cursor
        ld b, 22
        ld c, 0
        call set_cursor

        ; Show prompt
        ld hl, txt_ip_prompt
        call print_string

        ; Input line
        ld hl, IP_INPUT_BUF
        ld b, 30                ; Max length
        call input_line

        ret                     ; A = length

txt_ip_prompt:
        defb "HOST:PORT> ", 0

; -----------------------------------------------------------------------------
; Perform full connection sequence
; Returns: A = 0 if connected, non-zero if failed
; -----------------------------------------------------------------------------
do_connect:
        ; Show status
        call show_status_connecting

        ; Initialize network
        call net_init
        or a
        jr nz, dc_fail

        ; Connect to host
        ld hl, IP_INPUT_BUF
        call net_connect
        or a
        jr nz, dc_fail

        ; Update state
        ld a, CONN_HANDSHAKE
        ld (conn_state), a

        ; Show handshake status
        call show_status_handshake

        ; Send HELLO
        ld hl, player_name
        call rubp_send_hello

        ; Wait for WELCOME
        call rubp_receive
        call rubp_validate
        jr nz, dc_fail

        call rubp_get_type
        cp MSG_WELCOME
        jr nz, dc_fail

        ; Parse WELCOME
        call rubp_parse_welcome

        ; Update state
        ld a, CONN_WAITING
        ld (conn_state), a

        ; Show waiting status
        call show_status_waiting

        xor a                   ; Success
        ret

dc_fail:
        call show_status_failed
        ld a, 1
        ret

player_name:
        defb "ZX PLAYER", 0

; -----------------------------------------------------------------------------
; Wait for GAME_START message
; Returns: A = 0 when game starts, non-zero if cancelled
; -----------------------------------------------------------------------------
wait_for_game:
wfg_loop:
        ; Check for BREAK key (cancel)
        ld a, $FE               ; Row CAPS-V
        in a, ($FE)
        bit 0, a                ; CAPS
        jr nz, wfg_check_space
        ld a, $7F               ; Row SPACE-B
        in a, ($FE)
        bit 0, a                ; SPACE
        jr z, wfg_cancel        ; CAPS+SPACE = BREAK

wfg_check_space:
        ; Try to receive message
        call rubp_receive
        call rubp_validate
        jr nz, wfg_loop         ; Invalid, keep waiting

        ; Check message type
        call rubp_get_type

        cp MSG_GAME_START
        jr z, wfg_game_start

        cp MSG_GAME_STATE
        jr z, wfg_game_state

        jr wfg_loop

wfg_game_start:
        call rubp_parse_game_start
        ld a, CONN_PLAYING
        ld (conn_state), a
        xor a
        ret

wfg_game_state:
        call rubp_parse_game_state
        ld a, CONN_PLAYING
        ld (conn_state), a
        xor a
        ret

wfg_cancel:
        ld a, 1
        ret

; -----------------------------------------------------------------------------
; Status display helpers
; -----------------------------------------------------------------------------
show_status_connecting:
        ld b, 23
        ld c, 0
        call set_cursor
        ld hl, txt_connecting
        call print_string
        ret

show_status_handshake:
        ld b, 23
        ld c, 0
        call set_cursor
        ld hl, txt_handshake
        call print_string
        ret

show_status_waiting:
        ld b, 23
        ld c, 0
        call set_cursor
        ld hl, txt_waiting_game
        call print_string
        ret

show_status_failed:
        ld b, 23
        ld c, 0
        call set_cursor
        ld hl, txt_failed
        call print_string
        ret

txt_connecting:
        defb "CONNECTING...                   ", 0
txt_handshake:
        defb "HANDSHAKING...                  ", 0
txt_waiting_game:
        defb "WAITING FOR GAME...             ", 0
txt_failed:
        defb "CONNECTION FAILED               ", 0
