`timescale 1ns/1ps

module sine_rom (
    input  wire [7:0]         addr,
    output wire signed [15:0] data
);

    reg signed [15:0] rom [0:255];

    initial begin
        $readmemh("sine.hex", rom);
    end

    assign data = rom[addr];

endmodule
