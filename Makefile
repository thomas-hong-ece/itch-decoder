# ITCH decoder: build, run, and waveform targets
IVERILOG ?= iverilog
N        ?= 64
SEED     ?= 1

RTL := rtl/itch_decoder.v rtl/trigger.v
TB  := tb/tb_itch_decoder.v

.PHONY: all sim seeds waves clean

all: sim

# stimulus first: it generates params.vh, which the testbench includes
build/params.hex build/params.vh: py/gen_packets.py
	@mkdir -p build
	@python3 py/gen_packets.py --n $(N) --seed $(SEED)

build/sim: $(RTL) $(TB) build/params.vh
	@mkdir -p build
	$(IVERILOG) -g2012 -I build -o $@ $(RTL) $(TB)

sim: build/sim
	@./build/sim

# regression across several seeds
seeds:
	@for s in 1 7 42 99 1234; do \
		python3 py/gen_packets.py --n $(N) --seed $$s > /dev/null; \
		$(IVERILOG) -g2012 -I build -o build/sim $(RTL) $(TB); \
		printf "seed %-6s " $$s; \
		./build/sim | grep -E "failures|result" | tr -d '\n' | sed 's/  */ /g'; \
		echo ""; \
	done

waves: sim
	gtkwave sim.vcd &

clean:
	@rm -rf build sim.vcd