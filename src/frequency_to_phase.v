`timescale 1ns/1ps

module frequency_to_phase #(
    parameter integer SAMPLE_RATE_HZ = 48_000
) (
    input  wire        clk,
    input  wire        reset_n,

    input  wire [31:0] frequency_hz,
    input  wire        frequency_valid,

    output reg  [31:0] phase_inc,
    output reg         phase_inc_valid
);

    wire [63:0] scaled_frequency;
    wire [63:0] rounded_numerator;
    wire [63:0] calculated_phase_inc;

    // frequency_hz * 2^32
    assign scaled_frequency = {frequency_hz, 32'd0};

    // Add half the divisor so integer division rounds to nearest.
    assign rounded_numerator =
        scaled_frequency + (SAMPLE_RATE_HZ / 2);

    assign calculated_phase_inc =
        rounded_numerator / SAMPLE_RATE_HZ;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            phase_inc       <= 32'd0;
            phase_inc_valid <= 1'b0;
        end else begin
            phase_inc_valid <= 1'b0;

            if (frequency_valid) begin
                phase_inc       <= calculated_phase_inc[31:0];
                phase_inc_valid <= 1'b1;
            end
        end
    end

endmodule
