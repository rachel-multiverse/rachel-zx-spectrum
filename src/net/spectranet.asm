; =============================================================================
; SPECTRANET NETWORK DRIVER
; =============================================================================
; Spectranet Ethernet cartridge socket API
;
; Uses RST $08 with function codes in A:
;   $F1 - SOCKET
;   $F3 - CONNECT
;   $F5 - SEND
;   $F6 - RECV
;   $F9 - CLOSE

; Spectranet calls via RST $08
SOCK_SOCKET     equ $F1
SOCK_CONNECT    equ $F3
SOCK_SEND       equ $F5
SOCK_RECV       equ $F6
SOCK_CLOSE      equ $F9

; Socket types
SOCK_STREAM     equ 1           ; TCP

; =============================================================================
; NETWORK DRIVER INTERFACE
; =============================================================================

; -----------------------------------------------------------------------------
; Initialize network hardware
; Returns: A = 0 if OK
; -----------------------------------------------------------------------------
net_init:
        ; Create TCP socket
        ld a, SOCK_SOCKET
        ld b, SOCK_STREAM
        rst $08
        jr c, ni_error

        ; Store socket handle
        ld (socket_handle), a
        xor a
        ret

ni_error:
        ld a, 1
        ret

; -----------------------------------------------------------------------------
; Connect to host:port
; Input: HL = pointer to "host:port" string
; Returns: A = 0 if connected
; -----------------------------------------------------------------------------
net_connect:
        ; Parse host:port and connect
        ; Spectranet CONNECT takes host and port separately
        ; For now, simplified implementation

        ; Get socket handle
        ld a, (socket_handle)
        ld c, a

        ; Call connect
        ld a, SOCK_CONNECT
        ; DE = host string, BC = port (need to parse)
        ; This is a stub - full implementation would parse the string

        rst $08
        jr c, nc_error

        xor a
        ret

nc_error:
        ld a, 1
        ret

; -----------------------------------------------------------------------------
; Send data
; Input: HL = buffer, BC = length
; Returns: A = 0 if OK
; -----------------------------------------------------------------------------
net_send:
        push hl
        push bc

        ld a, (socket_handle)
        ld e, a

        pop bc
        pop hl

        ld a, SOCK_SEND
        rst $08
        jr c, ns_error

        xor a
        ret

ns_error:
        ld a, 1
        ret

; -----------------------------------------------------------------------------
; Receive data
; Input: HL = buffer, BC = length
; Returns: A = 0 if OK
; -----------------------------------------------------------------------------
net_recv:
        push hl
        push bc

        ld a, (socket_handle)
        ld e, a

        pop bc
        pop hl

        ld a, SOCK_RECV
        rst $08
        jr c, nr_error

        xor a
        ret

nr_error:
        ld a, 1
        ret

; -----------------------------------------------------------------------------
; Close connection
; -----------------------------------------------------------------------------
net_close:
        ld a, (socket_handle)
        ld c, a
        ld a, SOCK_CLOSE
        rst $08
        ret
