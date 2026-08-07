`timescale 1ns/1ps

module fractional_tick #(
    parameter [31:0] INCREMENT = 32'd293203101
) (
    input  wire       clk,
    input  wire       reset_n,
    output reg        tick,
    output reg [31:0] accumulator
);

    wire [32:0] sum;

    assign sum =
        {1'b0, accumulator}
        + {1'b0, INCREMENT};

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            accumulator <= 32'd0;
            tick        <= 1'b0;
        end else begin
            accumulator <= sum[31:0];
            tick        <= sum[32];
        end
    end

endmodule