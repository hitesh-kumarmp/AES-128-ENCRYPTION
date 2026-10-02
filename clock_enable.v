// ============================================================
// clock_enable.v
// Phase-based clock enable generator - the energy-efficiency
// feature from the project title.
//
// Concept: the datapath register only needs to actually update
// on cycles where real work is happening (loading the initial
// state, doing a round, or capturing the final ciphertext). On
// any other cycle, ce_out is low, meaning (on a real low-power
// implementation) that register's clock enable (CE) pin would
// be held low and it would not toggle at all that cycle -
// directly reducing dynamic switching power.
//
// On Xilinx FPGAs the correct way to use this is as the CE input
// of the target flip-flops (NOT by physically gating the clock
// net itself, which risks glitches and timing-closure problems).
// ============================================================
module clock_enable (
    input  wire clk,
    input  wire rst,          // synchronous, active-high
    input  wire phase_active, // high on any cycle the datapath register must update
    output reg  ce_out
);

    always @(posedge clk) begin
        if (rst)
            ce_out <= 1'b0;
        else
            ce_out <= phase_active;
    end

endmodule
