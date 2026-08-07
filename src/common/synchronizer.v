`timescale 1ns/1ps

module synchronizer #(
    parameter RESET_VALUE = 1'b1
)(
    input  wire clk,
    input  wire reset_n,
    input  wire async_in,
    output wire sync_out
);

    reg ff1;
    reg ff2;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            ff1 <= RESET_VALUE;
            ff2 <= RESET_VALUE;
        end
        else begin
            ff1 <= async_in;
            ff2 <= ff1;
        end
    end

    assign sync_out = ff2;

endmodule
