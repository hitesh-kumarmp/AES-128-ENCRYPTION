// ============================================================
// uart_rx.v
//
// UART receiver
//
// Clock     : 100 MHz
// Baud      : 115200
// Format    : 8N1
//
// Receives one byte and generates a one-clock data_valid pulse.
//
// ============================================================

module uart_rx #(
    parameter integer CLK_FREQ  = 100_000_000,
    parameter integer BAUD_RATE = 115200
)(
    input  wire      clk,
    input  wire      rst,

    input  wire      rx,

    output reg [7:0] data,
    output reg       data_valid
);

    localparam integer CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;


    // ========================================================
    // Synchronize asynchronous UART input
    // ========================================================

    reg rx_meta;
    reg rx_sync;

    always @(posedge clk) begin

        if (rst) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end
        else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end

    end


    // ========================================================
    // Receiver state
    // ========================================================

    localparam IDLE       = 2'd0;
    localparam START_BIT  = 2'd1;
    localparam DATA_BITS  = 2'd2;
    localparam STOP_BIT   = 2'd3;

    reg [1:0] state;

    reg [15:0] clk_count;
    reg [2:0]  bit_count;

    reg [7:0] rx_shift;


    // ========================================================
    // Receiver
    // ========================================================

    always @(posedge clk) begin

        if (rst) begin

            state      <= IDLE;

            clk_count  <= 16'd0;
            bit_count  <= 3'd0;

            rx_shift   <= 8'd0;

            data       <= 8'd0;
            data_valid <= 1'b0;

        end
        else begin

            // data_valid is a one-clock pulse
            data_valid <= 1'b0;


            case (state)

                // =================================================
                // IDLE
                // =================================================

                IDLE: begin

                    clk_count <= 16'd0;
                    bit_count <= 3'd0;

                    // UART line normally sits HIGH.
                    //
                    // Falling edge means start bit.
                    if (rx_sync == 1'b0) begin

                        state     <= START_BIT;
                        clk_count <= 16'd0;

                    end

                end


                // =================================================
                // START BIT
                // =================================================

                START_BIT: begin

                    if (clk_count == HALF_BIT - 1) begin

                        clk_count <= 16'd0;

                        // We should still be inside
                        // the LOW start bit.

                        if (rx_sync == 1'b0) begin

                            state     <= DATA_BITS;
                            bit_count <= 3'd0;

                        end
                        else begin

                            // False start
                            state <= IDLE;

                        end

                    end
                    else begin

                        clk_count <= clk_count + 1'b1;

                    end

                end


                // =================================================
                // DATA BITS
                // =================================================

                DATA_BITS: begin

                    if (clk_count == CLKS_PER_BIT - 1) begin

                        clk_count <= 16'd0;

                        // UART transmits LSB first.
                        rx_shift[bit_count] <= rx_sync;

                        if (bit_count == 3'd7) begin

                            state <= STOP_BIT;

                        end
                        else begin

                            bit_count <= bit_count + 1'b1;

                        end

                    end
                    else begin

                        clk_count <= clk_count + 1'b1;

                    end

                end


                // =================================================
                // STOP BIT
                // =================================================

                STOP_BIT: begin

                    if (clk_count == CLKS_PER_BIT - 1) begin

                        clk_count <= 16'd0;

                        // Stop bit should be HIGH.
                        if (rx_sync == 1'b1) begin

                            data       <= rx_shift;
                            data_valid <= 1'b1;

                        end

                        state <= IDLE;

                    end
                    else begin

                        clk_count <= clk_count + 1'b1;

                    end

                end


                default: begin

                    state <= IDLE;

                end

            endcase

        end

    end

endmodule