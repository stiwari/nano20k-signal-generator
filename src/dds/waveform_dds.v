`timescale 1ns/1ps

module waveform_dds (
    input  wire               clk,
    input  wire               reset_n,
    input  wire               sample_ce,
    input  wire [31:0]        phase_inc,

    output reg  [31:0]        phase,
    output wire [7:0]         rom_addr,
    output wire signed [15:0] sample
);

    assign rom_addr = phase[31:24];

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            phase <= 32'd0;
        else if (sample_ce)
            phase <= phase + phase_inc;
    end

    sine_rom rom_inst (
        .addr (rom_addr),
        .data (sample)
    );

endmodule
