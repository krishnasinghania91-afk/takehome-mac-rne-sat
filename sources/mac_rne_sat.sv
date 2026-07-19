`timescale 1ns/1ps
//
// mac_rne_sat -- golden solution implemented per docs/spec.md.
//
// Signed 8x8 multiply-accumulate with a round-half-to-even + saturating
// readout port and a sticky overflow flag. All state is synchronous to the
// rising edge of clk; reset is synchronous and active-high.
//
module mac_rne_sat (
    input  logic               clk,
    input  logic               rst,       // synchronous, active-high
    input  logic               en,        // accumulate a*b this cycle
    input  logic               clr,       // clear accumulator this cycle
    input  logic               rd,        // request readout snapshot this cycle
    input  logic signed [7:0]  a,
    input  logic signed [7:0]  b,
    output logic signed [15:0] res,       // rounded + saturated snapshot
    output logic               res_valid, // 1-cycle pulse, one cycle after rd
    output logic               ovf        // sticky saturation flag
);

    // 28-bit signed accumulator (spec section 3).
    logic signed [27:0] acc;

    // p = a*b is a signed 16-bit product, sign-extended to 28 bits.
    logic signed [15:0] prod;
    logic signed [27:0] prod_ext;

    // Combinational readout math on the *current* acc (the pre-update
    // snapshot for a rd sampled this cycle).
    logic signed [19:0] q;        // floor(acc / 256) == arithmetic acc >>> 8
    logic        [7:0]  rem;      // acc mod 256, always in [0, 255]
    logic               round_up;
    logic signed [20:0] rq;       // q (+1) with headroom before saturation
    logic               sat;
    logic signed [15:0] rres;     // rounded + saturated readout value

    // Continuous assignments keep the part-selects (acc[7:0], rq[15:0]) out of
    // an always_* process, which Icarus Verilog does not fully support.
    assign prod     = a * b;
    assign prod_ext = {{12{prod[15]}}, prod};

    // Round-half-to-even at the 8 LSBs (spec section 4).
    assign q        = acc >>> 8;   // arithmetic shift -> floor for negatives too
    assign rem      = acc[7:0];    // non-negative remainder r, 0..255
    assign round_up = (rem > 8'h80) || ((rem == 8'h80) && q[0]);
    assign rq       = $signed({q[19], q}) + (round_up ? 21'sd1 : 21'sd0);

    // Saturate the *rounded* value to signed 16-bit (spec section 4).
    assign sat      = (rq > 21'sd32767) || (rq < -21'sd32768);
    assign rres     = (rq > 21'sd32767)  ? 16'sd32767  :
                      (rq < -21'sd32768) ? -16'sd32768 : rq[15:0];

    always_ff @(posedge clk) begin
        if (rst) begin
            // Synchronous reset overrides en/clr/rd (spec section 6).
            acc       <= '0;
            res       <= '0;
            res_valid <= 1'b0;
            ovf       <= 1'b0;
        end else begin
            // Registered readout (spec section 4): res_valid pulses one cycle
            // after rd; res latches the snapshot and holds otherwise.
            res_valid <= rd;
            if (rd)
                res <= rres;

            // Sticky overflow (spec section 5): a saturating readout sets ovf
            // and wins over a same-cycle clr; otherwise clr clears it.
            ovf <= (clr ? 1'b0 : ovf) | ((rd && sat) ? 1'b1 : 1'b0);

            // Accumulator update (spec section 3). clr+en loads the product
            // alone (clear-then-accumulate); the rd snapshot above already
            // used the pre-update acc, so rd+clr returns the pre-clear value.
            if (clr && en)
                acc <= prod_ext;
            else if (clr)
                acc <= '0;
            else if (en)
                acc <= acc + prod_ext;
        end
    end

endmodule
