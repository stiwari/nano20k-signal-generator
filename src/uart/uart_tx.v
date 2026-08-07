`timescale 1ns/1ps

module uart_tx (
    input  wire       clk,
    input  wire       reset_n,
    input  wire       tick_16x,

    input  wire [7:0] tx_data,
    input  wire       tx_start,

    output reg        uart_tx,
    output reg        tx_busy,
    output reg        tx_done
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
            state        <= STATE_IDLE;
            sample_count <= 4'd0;
            bit_count    <= 3'd0;
            shift_reg    <= 8'd0;

            uart_tx      <= 1'b1;
            tx_busy      <= 1'b0;
            tx_done      <= 1'b0;
        end else begin
            tx_done <= 1'b0;

            case (state)

                STATE_IDLE: begin
                    uart_tx      <= 1'b1;
                    tx_busy      <= 1'b0;
                    sample_count <= 4'd0;
                    bit_count    <= 3'd0;

                    if (tx_start) begin
                        shift_reg <= tx_data;
                        uart_tx   <= 1'b0;
                        tx_busy   <= 1'b1;
                        state     <= STATE_START;
                    end
                end

                STATE_START: begin
                    if (tick_16x) begin
                        if (sample_count == 4'd15) begin
                            sample_count <= 4'd0;
                            uart_tx      <= shift_reg[0];
                            state        <= STATE_DATA;
                        end else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end
                end

                STATE_DATA: begin
                    if (tick_16x) begin
                        if (sample_count == 4'd15) begin
                            sample_count <= 4'd0;

                            if (bit_count == 3'd7) begin
                                uart_tx   <= 1'b1;
                                bit_count <= 3'd0;
                                state     <= STATE_STOP;
                            end else begin
                                bit_count <= bit_count + 1'b1;
                                shift_reg <= shift_reg >> 1;
                                uart_tx   <= shift_reg[1];
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
                            uart_tx      <= 1'b1;
                            tx_busy      <= 1'b0;
                            tx_done      <= 1'b1;
                            state        <= STATE_IDLE;
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
