; =============================================================================
; BUFFER DEFINITIONS
; =============================================================================
; Memory layout for Rachel ZX Spectrum client
;
; ZX Spectrum memory map:
;   $0000-$3FFF  ROM (16KB)
;   $4000-$57FF  Screen bitmap (6144 bytes)
;   $5800-$5AFF  Screen attributes (768 bytes)
;   $5B00-$5BFF  System variables (printer buffer)
;   $5C00-$5CBF  System variables
;   $5CC0-$FF57  Free RAM (available for BASIC/code)
;   $FF58-$FFFF  UDG area (168 bytes, 21 chars)
;
; We load at $6000 to stay clear of system variables.

; -----------------------------------------------------------------------------
; Program Origin
; -----------------------------------------------------------------------------
PROG_START      equ $6000

; -----------------------------------------------------------------------------
; Network Buffers (256 bytes at $7F00-$7FFF)
; High memory to avoid conflicts
; -----------------------------------------------------------------------------
NET_RX_BUF      equ $7F00       ; 64 bytes - receive buffer
NET_TX_BUF      equ $7F40       ; 64 bytes - transmit buffer
IP_INPUT_BUF    equ $7F80       ; 32 bytes - IP address input
AT_CMD_BUF      equ $7FA0       ; 48 bytes - AT command buffer
AT_RESP_BUF     equ $7FD0       ; 48 bytes - AT response buffer

; -----------------------------------------------------------------------------
; Game State Buffers (at $7E00-$7EFF)
; -----------------------------------------------------------------------------
PLAYER_NAMES    equ $7E00       ; 8 players x 16 chars = 128 bytes
PLAYER_COUNTS   equ $7E80       ; 8 bytes - card count per player
MY_HAND         equ $7E88       ; 32 bytes - our hand (max 32 cards)
DISCARD_TOP     equ $7EA8       ; 1 byte - top card of discard pile
NOMINATED_SUIT  equ $7EA9       ; 1 byte - nominated suit (0-3 or $FF=none)
PENDING_DRAWS   equ $7EAA       ; 1 byte - cards we must draw
PENDING_SKIPS   equ $7EAB       ; 1 byte - skips pending
DECK_COUNT      equ $7EAC       ; 1 byte - cards remaining in deck
DIRECTION       equ $7EAD       ; 1 byte - 0=clockwise, 1=counter-clockwise
GAME_OVER       equ $7EAE       ; 1 byte - 0=playing, 1=game over
WINNER_INDEX    equ $7EAF       ; 1 byte - winner player index

; -----------------------------------------------------------------------------
; Variables (at $7DB0-$7DFF)
; -----------------------------------------------------------------------------
VAR_BASE        equ $7DB0
player_id       equ VAR_BASE+0  ; 2 bytes - our player ID (big-endian)
game_id         equ VAR_BASE+2  ; 2 bytes - current game ID
sequence        equ VAR_BASE+4  ; 2 bytes - message sequence number
hand_count      equ VAR_BASE+6  ; 1 byte - cards in hand
cursor_pos      equ VAR_BASE+7  ; 1 byte - cursor position in hand
selected_mask   equ VAR_BASE+8  ; 2 bytes - selection bitmask (16 cards)
conn_state      equ VAR_BASE+10 ; 1 byte - connection state
current_turn    equ VAR_BASE+11 ; 1 byte - whose turn (player index)
my_index        equ VAR_BASE+12 ; 1 byte - our player index
socket_handle   equ VAR_BASE+13 ; 1 byte - Spectranet socket handle
temp1           equ VAR_BASE+14 ; 1 byte - scratch
temp2           equ VAR_BASE+15 ; 1 byte - scratch

; -----------------------------------------------------------------------------
; Connection States
; -----------------------------------------------------------------------------
CONN_DISCONNECTED equ 0
CONN_DIALING      equ 1
CONN_HANDSHAKE    equ 2
CONN_WAITING      equ 3
CONN_PLAYING      equ 4

; -----------------------------------------------------------------------------
; Constants
; -----------------------------------------------------------------------------
RUBP_MSG_SIZE   equ 64          ; RUBP protocol message size
MAX_HAND_SIZE   equ 32          ; Maximum cards in hand
MAX_PLAYERS     equ 8           ; Maximum players per game

; -----------------------------------------------------------------------------
; RUBP Message Types
; -----------------------------------------------------------------------------
MSG_HEARTBEAT   equ $00
MSG_HELLO       equ $01
MSG_WELCOME     equ $02
MSG_GAME_START  equ $03
MSG_PLAY_CARD   equ $04
MSG_DRAW_CARD   equ $05
MSG_CARD_DRAWN  equ $06
MSG_GAME_STATE  equ $07
MSG_TURN_START  equ $08
MSG_TURN_END    equ $09
MSG_PLAYER_WON  equ $0A
MSG_ERROR       equ $0B
MSG_PLAYER_LIST equ $0C

; -----------------------------------------------------------------------------
; RUBP Header Offsets
; -----------------------------------------------------------------------------
HDR_MAGIC       equ 0           ; 4 bytes "RACH"
HDR_VERSION     equ 4           ; 1 byte
HDR_TYPE        equ 5           ; 1 byte
HDR_SEQUENCE    equ 6           ; 2 bytes (big-endian)
HDR_PLAYER_ID   equ 8           ; 2 bytes (big-endian)
HDR_GAME_ID     equ 10          ; 2 bytes (big-endian)
HDR_TIMESTAMP   equ 12          ; 4 bytes (big-endian)
PAYLOAD_START   equ 16          ; Payload begins here

; -----------------------------------------------------------------------------
; Screen Constants
; -----------------------------------------------------------------------------
SCREEN_BASE     equ $4000       ; Screen bitmap
ATTR_BASE       equ $5800       ; Attribute RAM
UDG_ADDR        equ $FF58       ; UDG character definitions

; Colours (for attributes: FLASH.BRIGHT.PAPER.INK)
INK_BLACK       equ 0
INK_BLUE        equ 1
INK_RED         equ 2
INK_MAGENTA     equ 3
INK_GREEN       equ 4
INK_CYAN        equ 5
INK_YELLOW      equ 6
INK_WHITE       equ 7
PAPER_BLACK     equ 0
PAPER_BLUE      equ 8
PAPER_RED       equ 16
BRIGHT          equ 64
FLASH           equ 128

; -----------------------------------------------------------------------------
; ROM Routines
; -----------------------------------------------------------------------------
ROM_CLS         equ $0DAF       ; Clear screen
ROM_PRINT       equ $203C       ; Print string at DE, length BC
CHAN_OPEN       equ $1601       ; Open channel A
