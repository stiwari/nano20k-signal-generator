`timescale 1ns/1ps

module mixer (
    input  wire signed [15:0] signal_in,
    input  wire signed [15:0] lo_in,

    output wire signed [31:0] product
);

    assign product = signal_in * lo_in;

endmodule
