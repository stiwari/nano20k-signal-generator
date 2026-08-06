`timescale 1ns/1ps

module command_parser (
    input  wire        clk,
    input  wire        reset_n,

    input  wire [7:0]  rx_data,
    input  wire        rx_valid,

    output reg  [31:0] frequency_hz,
    output reg         frequency_valid,
    output reg         command_error
);

    localparam [1:0]
        STATE_IDLE   = 2'd0,
        STATE_NUMBER = 2'd1,
        STATE_ERROR  = 2'd2;

    reg [1:0]  state;
    reg [31:0] number;

    wire is_digit;

    assign is_digit =
        (rx_data >= "0") &&
        (rx_data <= "9");

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state           <= STATE_IDLE;
            number          <= 32'd0;
            frequency_hz    <= 32'd0;
            frequency_valid <= 1'b0;
            command_error   <= 1'b0;
        end else begin
            frequency_valid <= 1'b0;
            command_error   <= 1'b0;

            if (rx_valid) begin
                case (state)

                    STATE_IDLE: begin
                        if ((rx_data == "F") || (rx_data == "f")) begin
                            number <= 32'd0;
                            state  <= STATE_NUMBER;
                        end else if (
                            (rx_data == 8'h0D) ||
                            (rx_data == 8'h0A)
                        ) begin
                            // Ignore blank CR or LF characters.
                        end else begin
                            state <= STATE_ERROR;
                        end
                    end

                    STATE_NUMBER: begin
                        if (is_digit) begin
                            // number = number * 10 + new digit
                            number <=
                                (number << 3) +
                                (number << 1) +
                                (rx_data - "0");
                        end else if (
                            (rx_data == 8'h0D) ||
                            (rx_data == 8'h0A)
                        ) begin
                            frequency_hz    <= number;
                            frequency_valid <= 1'b1;
                            state           <= STATE_IDLE;
                        end else begin
                            state <= STATE_ERROR;
                        end
                    end

                    STATE_ERROR: begin
                        // Discard input until end of line.
                        if (
                            (rx_data == 8'h0D) ||
                            (rx_data == 8'h0A)
                        ) begin
                            command_error <= 1'b1;
                            state         <= STATE_IDLE;
                        end
                    end

                    default: begin
                        state <= STATE_IDLE;
                    end

                endcase
            end
        end
    end

endmodule
