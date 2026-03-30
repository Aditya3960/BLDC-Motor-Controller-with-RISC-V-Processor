module ram(
input clk,
input mem_valid,
input mem_write,
input [31:0] mem_addr,
input [31:0] mem_wdata,
output [31:0] mem_rdata
);

reg [31:0] memory [0:65535];

initial begin
    $readmemh("program.hex", memory);
end

assign mem_rdata = memory[mem_addr[17:2]];

always @(posedge clk) begin
    if (mem_valid && mem_write)
        memory[mem_addr[17:2]] <= mem_wdata;
end

endmodule
