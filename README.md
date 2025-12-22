# Rachel ZX Spectrum

A render-only client for the Rachel card game, written in Z80 assembly for the ZX Spectrum.

## Hardware Targets

- **ZX Spectrum Next** - Built-in WiFi via ESP8266
- **Spectranet** - Ethernet cartridge for 48K/128K Spectrums

## Building

Requires [Pasmo](http://pasmo.speccy.org/) cross-assembler.

```bash
# Build for ZX Spectrum Next
make next

# Build for Spectranet
make spectranet

# Build both
make all

# Clean build artifacts
make clean
```

## Output Files

- `build/rachel-next.nex` - ZX Spectrum Next executable
- `build/rachel-snet.tap` - Spectranet TAP file

## Project Structure

```
src/
├── main.asm        # Entry point, initialization, main loop
├── display.asm     # Screen routines, UDG setup
├── input.asm       # Keyboard handling
├── rubp.asm        # 64-byte RUBP protocol
├── game.asm        # Card and game state display
├── connect.asm     # Connection flow
├── buffers.asm     # Memory definitions
└── net/
    ├── next.asm        # Next UART/ESP driver
    └── spectranet.asm  # Socket API driver
```

## Protocol

Uses RUBP (Rachel Unified Binary Protocol) - 64-byte fixed messages over TCP. Same protocol as the C64 client and iOS host.

## Testing

- **Fuse** - Quick iteration, Spectranet plugin available
- **CSpect** - ZX Spectrum Next emulator
- **Real hardware** - Load via SD card (Next) or network boot (Spectranet)
