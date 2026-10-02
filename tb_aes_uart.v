// ============================================================
// tb_aes_uart.v  (rewritten)
//
// Fixes vs. previous version:
//   - .rst connected
//   - receiver runs concurrently with the sender (fork/join), so the
//     first TX start bit is never missed
//   - receive task returns at mid-stop-bit (the old extra #BIT_TIME
//     skipped past the next byte's start bit)
//   - two vectors back-to-back (FIPS-197 C.1 and Appendix B), which
//     also proves the core restarts cleanly
// ============================================================
`timescale 1ns/1ps

module tb_aes_uart;

    reg  clk = 1'b0;
    reg  rst = 1'b1;
    reg  uart_rx = 1'b1;
    wire uart_tx;

    aes_uart_top #(.CLK_FREQ(100_000_000), .BAUD_RATE(115200)) DUT (
        .clk(clk), .rst(rst), .uart_rx(uart_rx), .uart_tx(uart_tx)
    );

    always #5 clk = ~clk;                   // 100 MHz

    localparam integer BIT_TIME = 8680;     // 868 clks * 10 ns

    // ---------- UART byte send (tb -> FPGA) ----------
    task uart_send_byte;
        input [7:0] b;
        integer i;
        begin
            uart_rx = 1'b0;  #(BIT_TIME);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx = b[i];  #(BIT_TIME);
            end
            uart_rx = 1'b1;  #(BIT_TIME);
        end
    endtask

    // ---------- UART byte receive (FPGA -> tb) ----------
    // Returns at the MIDDLE of the stop bit, so the next call's
    // @(negedge) still catches the following start bit.
    task uart_receive_byte;
        output [7:0] b;
        integer i;
        begin
            b = 8'h00;
            @(negedge uart_tx);
            #(BIT_TIME/2);
            if (uart_tx !== 1'b0) $display("ERROR: bad start bit @%0t", $time);
            #(BIT_TIME);
            for (i = 0; i < 8; i = i + 1) begin
                b[i] = uart_tx;
                #(BIT_TIME);
            end
            if (uart_tx !== 1'b1) $display("ERROR: bad stop bit @%0t", $time);
        end
    endtask

    // ---------- packet send / response receive ----------
    task send_packet;
        input [127:0] pt;
        input [127:0] key;
        integer i;
        begin
            uart_send_byte(8'hA5);
            for (i = 0; i < 16; i = i + 1) uart_send_byte(pt [127 - 8*i -: 8]);
            for (i = 0; i < 16; i = i + 1) uart_send_byte(key[127 - 8*i -: 8]);
        end
    endtask

    reg [127:0] got_ct;
    reg         got_hdr_ok;

    task recv_response;
        reg [7:0] b;
        integer i;
        begin
            got_ct = 128'h0;
            uart_receive_byte(b);
            got_hdr_ok = (b == 8'h5A);
            for (i = 0; i < 16; i = i + 1) begin
                uart_receive_byte(b);
                got_ct[127 - 8*i -: 8] = b;
            end
        end
    endtask

    integer errors = 0;

    task run_test;
        input [127:0] pt;
        input [127:0] key;
        input [127:0] expected;
        begin
            fork
                send_packet(pt, key);
                recv_response;
            join
            $display("  plaintext  = %h", pt);
            $display("  key        = %h", key);
            $display("  expected   = %h", expected);
            $display("  received   = %h  (header %s)", got_ct, got_hdr_ok ? "5A ok" : "BAD");
            if (got_hdr_ok && got_ct === expected)
                $display("  -> PASS\n");
            else begin
                $display("  -> FAIL\n");
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        #200 rst = 1'b0;
        #200;

        $display("\n=== AES-128 UART TEST ===");

        $display("Test 1: FIPS-197 C.1");
        run_test(128'h00112233445566778899aabbccddeeff,
                 128'h000102030405060708090a0b0c0d0e0f,
                 128'h69c4e0d86a7b0430d8cdb78070b4c55a);

        $display("Test 2: FIPS-197 Appendix B");
        run_test(128'h3243f6a8885a308d313198a2e0370734,
                 128'h2b7e151628aed2a6abf7158809cf4f3c,
                 128'h3925841d02dc09fbdc118597196a0b32);

        if (errors == 0) $display("==== ALL UART AES TESTS PASSED ====\n");
        else             $display("==== %0d TEST(S) FAILED ====\n", errors);
        $finish;
    end

    initial begin
        #40_000_000;                        // 40 ms
        $display("ERROR: TIMEOUT");
        $finish;
    end

endmodule