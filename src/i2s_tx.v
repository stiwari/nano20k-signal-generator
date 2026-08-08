`timescale 1ns/1ps

module i2s_tx (
    input  wire               clk,
    input  wire               reset_n,
    input  wire               i2s_half_bclk_ce,
    input  wire signed [15:0] sample,

    output reg                i2s_bclk,
    output reg                i2s_lrck,
    output reg                i2s_data
);

    reg [5:0]  bit_count;
    reg [63:0] shift_reg;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            bit_count <= 6'd0;
            shift_reg <= 64'd0;

            i2s_bclk <= 1'b0;
            i2s_lrck <= 1'b0;
            i2s_data <= 1'b0;
        end

        else if (i2s_half_bclk_ce) begin

            //--------------------------------------------------
            // Falling BCLK edge:
            // prepare DATA for the next rising edge
            //--------------------------------------------------

            if (i2s_bclk) begin
                i2s_bclk <= 1'b0;

                i2s_data <= shift_reg[63];
                shift_reg <= {shift_reg[62:0], 1'b0};
            end

            //--------------------------------------------------
            // Rising BCLK edge:
            // receiver samples DATA
            //--------------------------------------------------

            else begin
                i2s_bclk <= 1'b1;

                if (bit_count == 6'd63) begin
                    bit_count <= 6'd0;

                    // 16-bit mono sample in 32-bit slots.
                    // Same sample sent to L and R.
                    shift_reg <= {
                        sample, 16'd0,
                        sample, 16'd0
                    };
                end
                else begin
                    bit_count <= bit_count + 1'b1;
                end

                // Left channel for bits 0-31,
                // right channel for bits 32-63.
                if (bit_count < 6'd32)
                    i2s_lrck <= 1'b0;
                else
                    i2s_lrck <= 1'b1;
            end
        end
    end
endmodule
