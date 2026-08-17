`timescale 1ns/1ps

module block_integrator (
    input  wire               clk,
    input  wire               reset_n,
    input  wire               sample_ce,

    input  wire signed [31:0] sample_in,

    output reg  signed [41:0] sum_out,
    output reg                sum_valid
);

    reg signed [41:0] accumulator;
    reg        [9:0]  sample_count;   // 0..1023

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            accumulator <= 42'sd0;
            sample_count <= 10'd0;
            sum_out      <= 42'sd0;
            sum_valid    <= 1'b0;
        end else begin
            sum_valid <= 1'b0;

            if (sample_ce) begin

                if (sample_count == 10'd1023) begin
                    // Include the final sample in this block.
                    sum_out <= accumulator + sample_in;

                    // Start a new integration window.
                    accumulator <= 42'sd0;
                    sample_count <= 10'd0;

                    // One-clock pulse saying sum_out is ready.
                    sum_valid <= 1'b1;
                end else begin
                    accumulator <= accumulator + sample_in;
                    sample_count <= sample_count + 1'b1;
                end

            end
        end
    end

endmodule
