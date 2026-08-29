# ITCH decoder: build, run, and waveform targets
IVERILOG ?= iverilog
VVP      ?= vvp
N        ?= 64
SEED     ?= 1

RTL := rtl/itch_decoder.v rtl/trigger.v
TB  := tb/tb_itch_decoder.v

.PHONY: all sim clean waves seeds

all: sim

build/sim: $(RTL) $(TB)
	@mkdir -p build
	$(IVERILOG) -g2012 -o $@ $(RTL) $(TB)

build/packets.hex: py/gen_packets.py
	@mkdir -p build
	python3 py/gen_packets.py --n $(N) --seed $(SEED)

sim: build/sim build/packets.hex
	./build/sim +nmsgs=$(N)

# regression across several seeds
seeds: build/sim
	@for s in 1 7 42 99 1234; do \
		python3 py/gen_packets.py --n $(N) --seed $$s > /dev/null; \
		printf "seed %-6s " $$s; \
		./build/sim +nmsgs=$(N) | grep -E "failures|result" | tr '\n' ' '; \
		echo ""; \
	done

waves: sim
	gtkwave sim.vcd &

clean:
	rm -rf build sim.vcd
