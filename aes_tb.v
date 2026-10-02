// ============================================================
// aes_tb.v
// Testbench for aes_top. Applies the FIPS-197 Appendix B
// known-answer test vector and checks the resulting ciphertext.
// Also exposes phase_ce so it can be added to the waveform to
// demonstrate the phase-based clock enable feature.
//
//   key        = 000102030405060708090a0b0c0d0e0f
//   plaintext  = 00112233445566778899aabbccddeeff
//   ciphertext = 69c4e0d86a7b0430d8cdb78070b4c55a   (expected)
// ============================================================
`timescale 1ns/1ps

module aes_tb;

    reg         clk;
    reg         rst;
    reg         start;
    reg [127:0] plaintext;
    reg [127:0] key;
    wire [127:0] ciphertext;
    wire         done;
    wire         phase_ce;      // NEW - add this to the waveform to see the gating signal

    // ---- DUT ----
    aes_top DUT (
        .clk        (clk),
        .rst        (rst),
        .start      (start),
        .plaintext  (plaintext),
        .key        (key),
        .ciphertext (ciphertext),
        .done       (done),
        .phase_ce   (phase_ce)
    );

    // 100 MHz clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ---- Stimulus ----
    initial begin
        rst       = 1'b1;
        start     = 1'b0;
        plaintext = 128'h00112233445566778899aabbccddeeff;
        key       = 128'h000102030405060708090a0b0c0d0e0f;

        repeat (3) @(posedge clk);
        rst = 1'b0;
        @(posedge clk);

        // pulse start for one cycle
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // wait for the core to finish
        wait (done == 1'b1);

        $display("--------------------------------------------------");
        $display(" Plaintext  = %h", plaintext);
        $display(" Key        = %h", key);
        $display(" Ciphertext = %h", ciphertext);
        $display(" Expected   = 69c4e0d86a7b0430d8cdb78070b4c55a");
        if (ciphertext == 128'h69c4e0d86a7b0430d8cdb78070b4c55a)
            $display(" RESULT: TEST PASSED");
        else
            $display(" RESULT: TEST FAILED");
        $display("--------------------------------------------------");

        #20;
        $finish;
    end

    // Safety timeout
    initial begin
        #2000;
        $display("ERROR: Simulation timeout - 'done' never asserted");
        $finish;
    end

endmodule
