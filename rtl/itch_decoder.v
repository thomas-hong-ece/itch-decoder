// ---------------------------------------------------------------------------
// itch_decoder.v
//
// Byte-serial decoder for a fixed-format ITCH-style "Add Order" message.
// One byte per clock in, decoded fields out.
//
// Message layout (36 bytes, big-endian, matches ITCH 5.0 Add Order):
//   off  len  field
//    0    1   msg_type      'A'
//    1    2   stock_locate
//    3    2   tracking_num
//    5    6   timestamp     nanoseconds since midnight
//   11    8   order_ref
//   19    1   side          'B' or 'S'
//   20    4   shares
//   24    8   stock         8 chars, space padded
//   32    4   price         fixed point, 4 implied decimals
//
// Latency metric: out_valid asserts on the clock edge following the last
// byte, so last-byte-in to valid-out is 1 cycle.
// ---------------------------------------------------------------------------

`default_nettype none

module itch_decoder #(
    parameter MSG_LEN = 36
)(
    input  wire        clk,
    input  wire        rst_n,

    // byte-serial input
    input  wire        in_valid,     // in_byte is good this cycle
    input  wire [7:0]  in_byte,
    input  wire        in_start,     // first byte of a message

    // decoded output, held until the next message completes
    output reg         out_valid,
    output reg  [15:0] stock_locate,
    output reg  [15:0] tracking_num,
    output reg  [47:0] timestamp,
    output reg  [63:0] order_ref,
    output reg  [7:0]  side,
    output reg  [31:0] shares,
    output reg  [63:0] stock,
    output reg  [31:0] price,

    // error flag: message did not start with 'A'
    output reg         bad_type
);

    localparam [7:0] MSG_ADD_ORDER = 8'h41;  // 'A'

    // ---- state ----
    localparam S_IDLE = 1'b0,
               S_RECV = 1'b1;

    reg        state;
    reg [5:0]  cnt;          // byte index within the message

    // shift registers, filled MSB first as bytes arrive
    reg [15:0] sr_locate;
    reg [15:0] sr_track;
    reg [47:0] sr_time;
    reg [63:0] sr_ref;
    reg [31:0] sr_shares;
    reg [63:0] sr_stock;
    reg [31:0] sr_price;

    wire last_byte = (cnt == MSG_LEN - 1);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_IDLE;
            cnt          <= 6'd0;
            out_valid    <= 1'b0;
            bad_type     <= 1'b0;
            sr_locate    <= 16'd0;
            sr_track     <= 16'd0;
            sr_time      <= 48'd0;
            sr_ref       <= 64'd0;
            sr_shares    <= 32'd0;
            sr_stock     <= 64'd0;
            sr_price     <= 32'd0;
            stock_locate <= 16'd0;
            tracking_num <= 16'd0;
            timestamp    <= 48'd0;
            order_ref    <= 64'd0;
            side         <= 8'd0;
            shares       <= 32'd0;
            stock        <= 64'd0;
            price        <= 32'd0;
        end else begin
            out_valid <= 1'b0;   // one-cycle pulse by default

            case (state)

            // -----------------------------------------------------------
            S_IDLE: begin
                if (in_valid && in_start) begin
                    bad_type <= (in_byte != MSG_ADD_ORDER);
                    cnt      <= 6'd1;
                    state    <= S_RECV;
                end
            end

            // -----------------------------------------------------------
            S_RECV: begin
                if (in_valid) begin
                    // route the incoming byte to its field by offset
                    case (cnt)
                        6'd1,  6'd2:                    sr_locate <= {sr_locate[7:0],  in_byte};
                        6'd3,  6'd4:                    sr_track  <= {sr_track[7:0],   in_byte};
                        6'd5,  6'd6,  6'd7,
                        6'd8,  6'd9,  6'd10:            sr_time   <= {sr_time[39:0],   in_byte};
                        6'd11, 6'd12, 6'd13, 6'd14,
                        6'd15, 6'd16, 6'd17, 6'd18:     sr_ref    <= {sr_ref[55:0],    in_byte};
                        6'd19:                          side      <= in_byte;
                        6'd20, 6'd21, 6'd22, 6'd23:     sr_shares <= {sr_shares[23:0], in_byte};
                        6'd24, 6'd25, 6'd26, 6'd27,
                        6'd28, 6'd29, 6'd30, 6'd31:     sr_stock  <= {sr_stock[55:0],  in_byte};
                        6'd32, 6'd33, 6'd34, 6'd35:     sr_price  <= {sr_price[23:0],  in_byte};
                        default: ;
                    endcase

                    if (last_byte) begin
                        // publish every field on the same edge
                        stock_locate <= sr_locate;
                        tracking_num <= sr_track;
                        timestamp    <= sr_time;
                        order_ref    <= sr_ref;
                        shares       <= sr_shares;
                        stock        <= sr_stock;
                        price        <= {sr_price[23:0], in_byte};
                        out_valid    <= ~bad_type;
                        cnt          <= 6'd0;
                        state        <= S_IDLE;
                    end else begin
                        cnt <= cnt + 6'd1;
                    end
                end
            end

            endcase
        end
    end

endmodule

`default_nettype wire
