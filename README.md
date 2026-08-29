# FPGA Market-Data Decoder

An ITCH-style exchange-feed decoder in Verilog. Byte-serial input, fixed-format
message parsing in a finite state machine, a configurable trigger module, and a
self-checking testbench driven by a Python packet generator.

**Status:** in development. Add Order (message type `A`) is implemented and
verified. Other message types are not yet handled.

## Result

    make sim

    checks run    : 1600
    failures      : 0
    latency cycles: min 1  max 1  avg 1
    result        : PASS

Latency is measured as clock cycles from the last byte entering the decoder to
`out_valid` asserting. Currently 1 cycle, deterministic across all test vectors.

## Layout

    rtl/itch_decoder.v   byte-serial FSM parser, 36-byte Add Order message
    rtl/trigger.v        parallel watchlist compare, 8 configurable slots
    tb/tb_itch_decoder.v self-checking testbench with latency measurement
    py/gen_packets.py    stimulus generator, corner cases plus randomized

## Running it

Requires Icarus Verilog and Python 3.

    make sim              # 64 messages, seed 1
    make sim N=500        # more messages
    make sim SEED=42      # different randomization
    make seeds            # regression across five seeds
    make waves            # open sim.vcd in GTKWave
    make clean

The generator writes `build/params.vh`, which the testbench includes so its
memories are sized to exactly the message count being run.

## Message format

ITCH 5.0 Add Order, 36 bytes, big-endian:

| Offset | Len | Field |
|---|---|---|
| 0 | 1 | message type, `A` |
| 1 | 2 | stock locate |
| 3 | 2 | tracking number |
| 5 | 6 | timestamp, ns since midnight |
| 11 | 8 | order reference |
| 19 | 1 | side, `B` or `S` |
| 20 | 4 | shares |
| 24 | 8 | stock symbol, space padded |
| 32 | 4 | price, 4 implied decimals |

## Verification approach

The generator emits six deliberate corner cases before any random vectors:
all zeros, all ones, single bit set, high bit only, bytes colliding with the
message-type marker, and one realistic message for waveform readability.
Uniform random values essentially never hit these boundaries, and they are
where shift-register and truncation bugs actually live.

The testbench compares all eight decoded fields per message against values
computed independently in Python, so a bug in the Verilog cannot mask itself.

## Next

- Additional message types (Order Executed, Cancel, Replace)
- Back-to-back messages with no idle cycles between them
- Multi-byte-per-cycle input path for higher throughput
- Timing closure on real hardware, currently simulation only