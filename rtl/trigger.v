// ---------------------------------------------------------------------------
// trigger.v
//
// Watchlist match. Holds up to N_SLOTS instrument symbols; when a decoded
// message names one of them, fire goes high for one cycle with the matching
// slot index.
//
// Comparison is fully parallel, so match latency is 1 cycle regardless of
// how many slots are populated.
// ---------------------------------------------------------------------------

`default_nettype none

module trigger #(
    parameter N_SLOTS = 8
)(
    input  wire        clk,
    input  wire        rst_n,

    // watchlist config
    input  wire        cfg_we,
    input  wire [2:0]  cfg_slot,
    input  wire [63:0] cfg_symbol,
    input  wire        cfg_enable,

    // decoded message in
    input  wire        msg_valid,
    input  wire [63:0] msg_stock,
    input  wire [31:0] msg_shares,

    // trigger out
    output reg         fire,
    output reg  [2:0]  fire_slot
);

    reg [63:0] symbol   [0:N_SLOTS-1];
    reg        enabled  [0:N_SLOTS-1];

    integer i;

    // parallel compare
    wire [N_SLOTS-1:0] hit;
    genvar g;
    generate
        for (g = 0; g < N_SLOTS; g = g + 1) begin : g_cmp
            assign hit[g] = enabled[g] && (symbol[g] == msg_stock);
        end
    endgenerate

    // lowest set bit wins
    reg [2:0] hit_idx;
    reg       hit_any;
    always @(*) begin
        hit_idx = 3'd0;
        hit_any = 1'b0;
        for (i = N_SLOTS-1; i >= 0; i = i - 1) begin
            if (hit[i]) begin
                hit_idx = i[2:0];
                hit_any = 1'b1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fire      <= 1'b0;
            fire_slot <= 3'd0;
            for (i = 0; i < N_SLOTS; i = i + 1) begin
                symbol[i]  <= 64'd0;
                enabled[i] <= 1'b0;
            end
        end else begin
            fire <= 1'b0;

            if (cfg_we) begin
                symbol[cfg_slot]  <= cfg_symbol;
                enabled[cfg_slot] <= cfg_enable;
            end

            if (msg_valid && hit_any) begin
                fire      <= 1'b1;
                fire_slot <= hit_idx;
            end
        end
    end

endmodule

`default_nettype wire
