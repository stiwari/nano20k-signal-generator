`timescale 1ns/1ps

module signal_generator_top (
    input  wire clk_27m,
    input  wire uart_rx_pin,
    output wire uart_tx_pin,
    output wire test_led
);

    localparam [31:0] UART_16X_INCREMENT = 32'd293203101;

    //--------------------------------------------------
    // Startup reset
    //--------------------------------------------------

    reg [7:0] reset_counter = 8'd0;
    wire reset_n;

    always @(posedge clk_27m) begin
        if (reset_counter != 8'hFF)
            reset_counter <= reset_counter + 1'b1;
    end

    assign reset_n = (reset_counter == 8'hFF);

    //--------------------------------------------------
    // Synchronize asynchronous UART RX input
    //--------------------------------------------------

    wire uart_rx_sync;

    synchronizer #(
        .RESET_VALUE(1'b1)
    ) rx_sync_inst (
        .clk      (clk_27m),
        .reset_n  (reset_n),
        .async_in (uart_rx_pin),
        .sync_out (uart_rx_sync)
    );

    //--------------------------------------------------
    // Generate 16x UART oversampling tick
    //--------------------------------------------------

    wire tick_16x;
    wire [31:0] tick_accumulator;

    fractional_tick #(
        .INCREMENT(UART_16X_INCREMENT)
    ) uart_tick_inst (
        .clk         (clk_27m),
        .reset_n     (reset_n),
        .tick        (tick_16x),
        .accumulator (tick_accumulator)
    );

    //--------------------------------------------------
    // UART receiver
    //--------------------------------------------------

    wire [7:0] rx_data;
    wire       rx_valid;
    wire       framing_error;

    uart_rx rx_inst (
        .clk           (clk_27m),
        .reset_n       (reset_n),
        .rx_sync       (uart_rx_sync),
        .tick_16x      (tick_16x),
        .rx_data       (rx_data),
        .rx_valid      (rx_valid),
        .framing_error (framing_error)
    );

    //--------------------------------------------------
    // UART transmitter
    //--------------------------------------------------

    reg  [7:0] tx_data;
    reg        tx_start;
    wire       tx_busy;
    wire       tx_done;

    uart_tx tx_inst (
        .clk      (clk_27m),
        .reset_n  (reset_n),
        .tick_16x (tick_16x),
        .tx_data  (tx_data),
        .tx_start (tx_start),
        .uart_tx  (uart_tx_pin),
        .tx_busy  (tx_busy),
        .tx_done  (tx_done)
    );

    //--------------------------------------------------
    // Diagnostic:
    // transmit the low nibble of rx_data as one
    // hexadecimal ASCII character
    //--------------------------------------------------
//--------------------------------------------------
// Echo controller FSM
//--------------------------------------------------

localparam
    ST_IDLE     = 2'd0,
    ST_LOAD     = 2'd1,
    ST_START    = 2'd2,
    ST_WAIT     = 2'd3;

reg [1:0] state;
reg [7:0] pending_byte;

always @(posedge clk_27m or negedge reset_n) begin

    if (!reset_n) begin

        state        <= ST_IDLE;
        pending_byte <= 8'd0;

        tx_data      <= 8'd0;
        tx_start     <= 1'b0;

    end
    else begin

        tx_start <= 1'b0;

        case(state)

        //------------------------------------------
        ST_IDLE:
        //------------------------------------------

        begin
            if (rx_valid) begin
                pending_byte <= rx_data;
                state <= ST_LOAD;
            end
        end

        //------------------------------------------
        ST_LOAD:
        //------------------------------------------

        begin
            tx_data <= pending_byte;
            state   <= ST_START;
        end

        //------------------------------------------
        ST_START:
        //------------------------------------------

        begin
            tx_start <= 1'b1;
            state    <= ST_WAIT;
        end

        //------------------------------------------
        ST_WAIT:
        //------------------------------------------

        begin
            if (tx_done)
                state <= ST_IDLE;
        end

        endcase

    end

end

/*    always @(posedge clk_27m or negedge reset_n) begin
        if (!reset_n) begin
            tx_data  <= "0";
            tx_start <= 1'b0;
        end else begin
            // Default low so tx_start lasts one clock.
            tx_start <= 1'b0;

            if (rx_valid && !tx_busy) begin
                if (rx_data[3:0] < 4'd10)
                    tx_data <= "0" + rx_data[3:0];
                else
                    tx_data <= "A" + (rx_data[3:0] - 4'd10);

                tx_start <= 1'b1;
            end
        end
    end
*/
    //--------------------------------------------------
    // LED indicator
    //--------------------------------------------------
    //
    // Tang Nano 20K LED is active-low.
    //
    // LED turns on briefly while:
    // - a received byte is valid
    // - the transmitter is busy
    // - a framing error occurs
    //--------------------------------------------------

    assign test_led =
        ~(rx_valid | tx_busy | framing_error);

endmodule
