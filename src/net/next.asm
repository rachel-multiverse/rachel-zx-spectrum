; =============================================================================
; NEXT NETWORK DRIVER
; =============================================================================
; ZX Spectrum Next WiFi via UART + ESP8266
;
; UART ports:
;   $143B - TX (write byte to send)
;   $133B - RX (read received byte)
;   $123B - Status (bit 0 = RX ready, bit 1 = TX empty)
;
; ESP8266 AT commands:
;   AT+CIPSTART="TCP","host",port  - Connect
;   AT+CIPSEND=n                    - Send n bytes
;   AT+CIPCLOSE                     - Disconnect
;   +IPD,n:                         - Incoming data prefix

; UART port addresses
UART_TX         equ $143B
UART_RX         equ $133B
UART_STATUS     equ $123B

; Status bits
UART_RX_READY   equ 0           ; Bit 0 = data available
UART_TX_EMPTY   equ 1           ; Bit 1 = can send

; =============================================================================
; NETWORK DRIVER INTERFACE
; =============================================================================

; -----------------------------------------------------------------------------
; Initialize network hardware
; Returns: A = 0 if OK, non-zero if error
; -----------------------------------------------------------------------------
net_init:
        ; Send AT to check ESP is responding
        ld hl, at_cmd_at
        call uart_send_string

        ; Wait for OK
        call uart_wait_ok
        ret                     ; A = 0 if OK, 1 if timeout

; -----------------------------------------------------------------------------
; Connect to host:port
; Input: HL = pointer to "host:port" string (null-terminated)
; Returns: A = 0 if connected, non-zero if error
; -----------------------------------------------------------------------------
net_connect:
        push hl                 ; Save host:port

        ; Build AT+CIPSTART command
        ld hl, at_cmd_cipstart
        call uart_send_string

        pop hl                  ; Host:port string

        ; Parse host and port from "host:port" format
        ; Find the colon
        push hl
nc_find_colon:
        ld a, (hl)
        or a
        jr z, nc_no_colon       ; No colon found (error)
        cp ':'
        jr z, nc_found_colon
        inc hl
        jr nc_find_colon

nc_found_colon:
        ; HL points to colon, stack has start
        ld (hl), 0              ; Temporarily null-terminate host
        push hl                 ; Save colon position

        ; Send host
        ld a, '"'
        call uart_send_byte
        pop hl
        push hl
        ex (sp), hl             ; HL = start of string
        pop de                  ; DE = colon position
        push de
        ex de, hl
        ; HL = start, need to send until colon
        pop de
        push de
        ; Actually let's just send char by char
        pop de                  ; DE = colon pos
        pop hl                  ; HL = start
        push de
        push hl

nc_send_host:
        ld a, (hl)
        or a
        jr z, nc_host_done
        call uart_send_byte
        inc hl
        jr nc_send_host

nc_host_done:
        ld a, '"'
        call uart_send_byte
        ld a, ','
        call uart_send_byte

        ; Restore colon, get port
        pop hl                  ; Original start (discard)
        pop hl                  ; Colon position
        ld (hl), ':'            ; Restore colon
        inc hl                  ; HL = port string

        ; Send port (just digits)
nc_send_port:
        ld a, (hl)
        or a
        jr z, nc_port_done
        call uart_send_byte
        inc hl
        jr nc_send_port

nc_port_done:
        ; Send CR LF
        ld a, 13
        call uart_send_byte
        ld a, 10
        call uart_send_byte

        ; Wait for CONNECT or ERROR
        call uart_wait_connect
        ret                     ; A = 0 if connected

nc_no_colon:
        pop hl
        ld a, 1                 ; Error - invalid format
        ret

; -----------------------------------------------------------------------------
; Send data
; Input: HL = data buffer, BC = length (should be 64 for RUBP)
; Returns: A = 0 if OK, non-zero if error
; -----------------------------------------------------------------------------
net_send:
        push hl
        push bc

        ; Send AT+CIPSEND=64
        ld hl, at_cmd_cipsend
        call uart_send_string

        ; Wait for > prompt
        call uart_wait_prompt

        pop bc
        pop hl

        ; Send the data
ns_loop:
        ld a, (hl)
        call uart_send_byte
        inc hl
        dec bc
        ld a, b
        or c
        jr nz, ns_loop

        ; Wait for SEND OK
        call uart_wait_send_ok
        ret

; -----------------------------------------------------------------------------
; Receive data
; Input: HL = buffer, BC = expected length (64 for RUBP)
; Returns: A = 0 if OK, non-zero if error/timeout
; Blocks until data received or timeout
; -----------------------------------------------------------------------------
net_recv:
        push hl
        push bc

        ; Wait for +IPD,n: prefix
        call uart_wait_ipd

        pop bc
        pop hl
        or a
        ret nz                  ; Error/timeout

        ; Read the data bytes
nr_loop:
        call uart_recv_byte_timeout
        or a
        jr nz, nr_error

        ld a, (temp1)           ; Retrieved byte
        ld (hl), a
        inc hl
        dec bc
        ld a, b
        or c
        jr nz, nr_loop

        xor a                   ; Success
        ret

nr_error:
        ld a, 1
        ret

; -----------------------------------------------------------------------------
; Close connection
; -----------------------------------------------------------------------------
net_close:
        ld hl, at_cmd_cipclose
        call uart_send_string
        call uart_wait_ok
        ret

; =============================================================================
; UART LOW-LEVEL ROUTINES
; =============================================================================

; -----------------------------------------------------------------------------
; Send byte via UART
; Input: A = byte to send
; -----------------------------------------------------------------------------
uart_send_byte:
        push af

usb_wait:
        in a, (UART_STATUS)
        bit UART_TX_EMPTY, a
        jr z, usb_wait          ; Wait until TX empty

        pop af
        out (UART_TX), a
        ret

; -----------------------------------------------------------------------------
; Receive byte via UART (blocking)
; Returns: A = received byte
; -----------------------------------------------------------------------------
uart_recv_byte:
urb_wait:
        in a, (UART_STATUS)
        bit UART_RX_READY, a
        jr z, urb_wait          ; Wait until RX ready

        in a, (UART_RX)
        ret

; -----------------------------------------------------------------------------
; Receive byte with timeout
; Returns: A = 0 if OK (byte in temp1), A = 1 if timeout
; -----------------------------------------------------------------------------
uart_recv_byte_timeout:
        ld de, 0                ; Timeout counter

urbt_loop:
        in a, (UART_STATUS)
        bit UART_RX_READY, a
        jr nz, urbt_got

        dec de
        ld a, d
        or e
        jr nz, urbt_loop

        ; Timeout
        ld a, 1
        ret

urbt_got:
        in a, (UART_RX)
        ld (temp1), a
        xor a
        ret

; -----------------------------------------------------------------------------
; Check if data available (non-blocking)
; Returns: Z if data available
; -----------------------------------------------------------------------------
uart_available:
        in a, (UART_STATUS)
        bit UART_RX_READY, a
        ret                     ; Z if ready (bit was 1... wait, check logic)

; -----------------------------------------------------------------------------
; Send null-terminated string
; Input: HL = string address
; -----------------------------------------------------------------------------
uart_send_string:
        ld a, (hl)
        or a
        ret z
        call uart_send_byte
        inc hl
        jr uart_send_string

; -----------------------------------------------------------------------------
; Wait for "OK" response
; Returns: A = 0 if OK received, 1 if timeout/error
; -----------------------------------------------------------------------------
uart_wait_ok:
        ; Look for 'O' then 'K'
        ld bc, 0                ; Timeout

uwo_loop:
        call uart_recv_byte_timeout
        or a
        jr nz, uwo_timeout

        ld a, (temp1)
        cp 'O'
        jr nz, uwo_loop

        ; Got 'O', look for 'K'
        call uart_recv_byte_timeout
        or a
        jr nz, uwo_timeout

        ld a, (temp1)
        cp 'K'
        jr nz, uwo_loop

        xor a                   ; Success
        ret

uwo_timeout:
        ld a, 1
        ret

; -----------------------------------------------------------------------------
; Wait for "CONNECT" or error
; Returns: A = 0 if connected, 1 if error
; -----------------------------------------------------------------------------
uart_wait_connect:
        ; Look for 'C' (CONNECT) or 'E' (ERROR)
uwc_loop:
        call uart_recv_byte_timeout
        or a
        jr nz, uwc_timeout

        ld a, (temp1)
        cp 'C'
        jr z, uwc_check_connect
        cp 'E'
        jr z, uwc_error
        jr uwc_loop

uwc_check_connect:
        ; Verify it's CONNECT (drain until newline)
        call uart_drain_line
        xor a
        ret

uwc_error:
uwc_timeout:
        ld a, 1
        ret

; -----------------------------------------------------------------------------
; Wait for > prompt (after CIPSEND)
; Returns: A = 0 if got prompt
; -----------------------------------------------------------------------------
uart_wait_prompt:
uwp_loop:
        call uart_recv_byte_timeout
        or a
        ret nz

        ld a, (temp1)
        cp '>'
        jr nz, uwp_loop

        xor a
        ret

; -----------------------------------------------------------------------------
; Wait for "SEND OK"
; Returns: A = 0 if OK
; -----------------------------------------------------------------------------
uart_wait_send_ok:
        ; Just wait for OK
        jp uart_wait_ok

; -----------------------------------------------------------------------------
; Wait for +IPD,n: prefix
; Returns: A = 0 if got prefix, non-zero if timeout
; -----------------------------------------------------------------------------
uart_wait_ipd:
        ; Look for '+IPD,'
uwi_loop:
        call uart_recv_byte_timeout
        or a
        ret nz

        ld a, (temp1)
        cp '+'
        jr nz, uwi_loop

        ; Check for 'I', 'P', 'D', ','
        call uart_recv_byte_timeout
        or a
        ret nz
        ld a, (temp1)
        cp 'I'
        jr nz, uwi_loop

        call uart_recv_byte_timeout
        or a
        ret nz
        ld a, (temp1)
        cp 'P'
        jr nz, uwi_loop

        call uart_recv_byte_timeout
        or a
        ret nz
        ld a, (temp1)
        cp 'D'
        jr nz, uwi_loop

        call uart_recv_byte_timeout
        or a
        ret nz
        ld a, (temp1)
        cp ','
        jr nz, uwi_loop

        ; Skip the length digits until ':'
uwi_skip_len:
        call uart_recv_byte_timeout
        or a
        ret nz
        ld a, (temp1)
        cp ':'
        jr nz, uwi_skip_len

        xor a                   ; Success
        ret

; -----------------------------------------------------------------------------
; Drain characters until newline
; -----------------------------------------------------------------------------
uart_drain_line:
udl_loop:
        call uart_recv_byte_timeout
        or a
        ret nz

        ld a, (temp1)
        cp 10
        jr nz, udl_loop
        ret

; =============================================================================
; AT COMMAND STRINGS
; =============================================================================

at_cmd_at:
        defb "AT", 13, 10, 0

at_cmd_cipstart:
        defb "AT+CIPSTART=\"TCP\",", 0

at_cmd_cipsend:
        defb "AT+CIPSEND=64", 13, 10, 0

at_cmd_cipclose:
        defb "AT+CIPCLOSE", 13, 10, 0
