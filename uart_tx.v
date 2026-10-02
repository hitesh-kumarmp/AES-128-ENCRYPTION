// ============================================================
// uart_tx.v
//
// 115200 baud, 8N1 UART transmitter
// 100 MHz system clock
//
// Input:
//   start = one-clock pulse
//   data  = byte to transmit
//
// Outputs:
//   tx    = UART TX line
//   busy  = high while transmitting
// ============================================================

module uart_tx #(
    parameter integer CLK_FREQ  = 100_000_000,
    parameter integer BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst,

    input  wire [7:0] data,
    input  wire       start,

    output reg        tx,
    output reg        busy
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    reg [15:0] clk_count;
    reg [3:0]  bit_count;

    reg [9:0] tx_shift;


    always @(posedge clk) begin

        if (rst) begin

            tx        <= 1'b1;
            busy      <= 1'b0;

            clk_count <= 16'd0;
            bit_count <= 4'd0;

            tx_shift  <= 10'b1111111111;

        end
        else begin

            // ------------------------------------------------
            // IDLE
            // ------------------------------------------------

            if (!busy) begin

                tx        <= 1'b1;
                clk_count <= 16'd0;
                bit_count <= 4'd0;

                if (start) begin

                    // UART frame:
                    //
                    // bit 0  = start = 0
                    // bit 1-8 = data
                    // bit 9 = stop = 1
                    //
                    // LSB transmitted first.

                    tx_shift <= {
                        1'b1,
                        data,
                        1'b0
                    };

                    busy      <= 1'b1;
                    tx        <= 1'b0;

                    clk_count <= 16'd0;
                    bit_count <= 4'd0;

                end

            end


            // ------------------------------------------------
            // TRANSMITTING
            // ------------------------------------------------

            else begin

                if (clk_count == CLKS_PER_BIT - 1) begin

                    clk_count <= 16'd0;

                    if (bit_count == 4'd9) begin

                        // Entire frame transmitted
                        busy <= 1'b0;
                        tx   <= 1'b1;

                    end
                    else begin

                        bit_count <= bit_count + 1'b1;

                        tx_shift <= {
                            1'b1,
                            tx_shift[9:1]
                        };

                        tx <= tx_shift[1];

                    end

                end
                else begin

                    clk_count <= clk_count + 1'b1;

                end

            end

        end

    end

endmodule