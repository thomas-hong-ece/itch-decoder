// ---------------------------------------------------------------------------
// tb_itch_decoder.v
//
// Self-checking testbench. Reads packets and expected values produced by
// py/gen_packets.py, drives them in byte by byte, and compares every decoded
// field. Also measures last-byte-in to valid-out latency in clock cycles.
//
//   iverilog -g2012 -o sim rtl/*.v tb/tb_itch_decoder.v && ./sim
// ---------------------------------------------------------------------------

`timescale 1ns/1ps
`default_nettype none

module tb_itch_decoder;

`include "params.vh"

    localparam MSG_LEN  = 36;
    localparam MAX_MSGS = `N_MSGS;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    always #5 clk = ~clk;      // 100 MHz

    reg        in_valid = 1'b0;
    reg  [7:0] in_byte  = 8'd0;
    reg        in_start = 1'b0;

    wire        out_valid;
    wire [15:0] stock_locate, tracking_num;
    wire [47:0] timestamp;
    wire [63:0] order_ref, stock;
    wire [7:0]  side;
    wire [31:0] shares, price;
    wire        bad_type;

    itch_decoder dut (
        .clk(clk), .rst_n(rst_n),
        .in_valid(in_valid), .in_byte(in_byte), .in_start(in_start),
        .out_valid(out_valid),
        .stock_locate(stock_locate), .tracking_num(tracking_num),
        .timestamp(timestamp), .order_ref(order_ref), .side(side),
        .shares(shares), .stock(stock), .price(price), .bad_type(bad_type)
    );

    // ---- stimulus and expected values, loaded from the generator ----
    reg [7:0]  pkt_mem [0:MAX_MSGS*MSG_LEN-1];
    reg [63:0] exp_mem [0:MAX_MSGS*8-1];   // 8 expected fields per message
    integer    n_msgs;

    integer errors = 0;
    integer checks = 0;
    integer i, j;
    integer t_last, t_valid, lat, wait_cnt;
    integer lat_min = 1000, lat_max = 0, lat_sum = 0, lat_n = 0;

    task check_field(input [255:0] name, input [63:0] got, input [63:0] want);
        begin
            checks = checks + 1;
            if (got !== want) begin
                errors = errors + 1;
                $display("  FAIL %0s: got %h want %h", name, got, want);
            end
        end
    endtask

    initial begin
        $dumpfile("sim.vcd");
        $dumpvars(0, tb_itch_decoder);

        n_msgs = `N_MSGS;
        $readmemh("build/packets.hex",  pkt_mem);
        $readmemh("build/expected.hex", exp_mem);

        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        $display("running %0d messages", n_msgs);

        for (i = 0; i < n_msgs; i = i + 1) begin
            // drive one message, one byte per clock
            for (j = 0; j < MSG_LEN; j = j + 1) begin
                @(negedge clk);
                in_valid = 1'b1;
                in_start = (j == 0);
                in_byte  = pkt_mem[i*MSG_LEN + j];
                if (j == MSG_LEN-1) t_last = $time;
            end
            // out_valid is a one-cycle level, not an edge to wait on, so
            // sample it just after each rising edge instead
            wait_cnt = 0;
            lat      = 0;
            @(posedge clk); #1;
            lat = 1;
            while (!out_valid && wait_cnt < 20) begin
                @(posedge clk); #1;
                lat      = lat + 1;
                wait_cnt = wait_cnt + 1;
            end

            if (!out_valid) begin
                $display("  FAIL msg %0d: out_valid never asserted", i);
                errors = errors + 1;
            end else begin
                if (lat < lat_min) lat_min = lat;
                if (lat > lat_max) lat_max = lat;
                lat_sum = lat_sum + lat;
                lat_n   = lat_n + 1;
            end

            @(negedge clk);
            in_valid = 1'b0;
            in_start = 1'b0;

            check_field("stock_locate", {48'd0, stock_locate}, exp_mem[i*8 + 0]);
            check_field("tracking_num", {48'd0, tracking_num}, exp_mem[i*8 + 1]);
            check_field("timestamp",    {16'd0, timestamp},    exp_mem[i*8 + 2]);
            check_field("order_ref",    order_ref,             exp_mem[i*8 + 3]);
            check_field("side",         {56'd0, side},         exp_mem[i*8 + 4]);
            check_field("shares",       {32'd0, shares},       exp_mem[i*8 + 5]);
            check_field("stock",        stock,                 exp_mem[i*8 + 6]);
            check_field("price",        {32'd0, price},        exp_mem[i*8 + 7]);

            repeat (2) @(posedge clk);
        end

        $display("");
        $display("----------------------------------------");
        $display(" checks run    : %0d", checks);
        $display(" failures      : %0d", errors);
        if (lat_n > 0)
            $display(" latency cycles: min %0d  max %0d  avg %0d",
                     lat_min, lat_max, lat_sum / lat_n);
        $display(" result        : %0s", (errors == 0) ? "PASS" : "FAIL");
        $display("----------------------------------------");

        if (errors != 0) $fatal(1);
        $finish;
    end

endmodule

`default_nettype wire
