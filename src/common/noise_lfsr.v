`timescale 1ns/1ps

module noise_lfsr (
    input  wire               clk,
    input  wire               reset_n,
    input  wire               sample_ce,
    output wire signed [15:0] noise_sample
);

    // 16-bit maximal-length LFSR
    reg [15:0] lfsr;

    wire feedback;

    assign feedback =
        lfsr[15] ^
        lfsr[13] ^
        lfsr[12] ^
        lfsr[10];

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            lfsr <= 16'hACE1;   // non-zero seed
        else if (sample_ce)
            lfsr <= {lfsr[14:0], feedback};
    end

    // Reinterpret the pseudo-random 16-bit pattern
    // as a signed audio sample.
    assign noise_sample = lfsr;

endmodule
