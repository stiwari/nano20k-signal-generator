`timescale 1ns/1ps

module uart_rx (
    input  wire       clk,
    input  wire       reset_n,
    input  wire       rx_sync,
    input  wire       tick_16x,

    output reg  [7:0] rx_data,
    output reg        rx_valid,
    output reg        framing_error
);

    localparam [1:0]
        STATE_IDLE  = 2'd0,
        STATE_START = 2'd1,
        STATE_DATA  = 2'd2,
        STATE_STOP  = 2'd3;

    reg [1:0] state;
    reg [3:0] sample_count;
    reg [2:0] bit_count;
    reg [7:0] shift_reg;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state         <= STATE_IDLE;
            sample_count  <= 4'd0;
            bit_count     <= 3'd0;
            shift_reg     <= 8'd0;
            rx_data       <= 8'd0;
            rx_valid      <= 1'b0;
            framing_error <= 1'b0;
        end else begin
            rx_valid      <= 1'b0;
            framing_error <= 1'b0;

            case (state)

                STATE_IDLE: begin
                    sample_count <= 4'd0;
                    bit_count    <= 3'd0;

                    if (!rx_sync)
                        state <= STATE_START;
                end

                STATE_START: begin
                    if (tick_16x) begin
                        if (sample_count == 4'd7) begin
                            sample_count <= 4'd0;

                            if (!rx_sync) begin
                                state     <= STATE_DATA;
                                bit_count <= 3'd0;
                            end else begin
                                state <= STATE_IDLE;
                            end
                        end else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end
                end

                STATE_DATA: begin
                    if (tick_16x) begin
                        if (sample_count == 4'd15) begin
                            sample_count <= 4'd0;
                            shift_reg[bit_count] <= rx_sync;

                            if (bit_count == 3'd7) begin
                                bit_count <= 3'd0;
                                state     <= STATE_STOP;
                            end else begin
                                bit_count <= bit_count + 1'b1;
                            end
                        end else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end
                end

                STATE_STOP: begin
                    if (tick_16x) begin
                        if (sample_count == 4'd15) begin
                            sample_count <= 4'd0;

                            if (rx_sync) begin
                                rx_data  <= shift_reg;
                                rx_valid <= 1'b1;
                            end else begin
                                framing_error <= 1'b1;
                            end

                            state <= STATE_IDLE;
                        end else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end

            endcase
        end
    end

endmodule
