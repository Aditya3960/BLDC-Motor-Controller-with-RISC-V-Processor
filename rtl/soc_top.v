module soc_top(
input clk,
input resetn
);

// PicoRV32 memory interface
wire mem_valid;
wire mem_instr;
wire mem_ready;

wire [31:0] mem_addr;
wire [31:0] mem_wdata;
wire [3:0]  mem_wstrb;

wire [31:0] mem_rdata;

// RAM output
wire [31:0] ram_rdata;

// --------------------------------------------------
// PicoRV32 CPU
// --------------------------------------------------

picorv32 #(
    .PROGADDR_RESET(32'h00000000)
) cpu (

.clk(clk),
.resetn(resetn),

.mem_valid(mem_valid),
.mem_instr(mem_instr),
.mem_ready(mem_ready),

.mem_addr(mem_addr),
.mem_wdata(mem_wdata),
.mem_wstrb(mem_wstrb),
.mem_rdata(mem_rdata)

);

// --------------------------------------------------
// RAM
// --------------------------------------------------

ram ram0(

.clk(clk),
.mem_valid(mem_valid),
.mem_write(|mem_wstrb),
.mem_addr(mem_addr),
.mem_wdata(mem_wdata),
.mem_rdata(ram_rdata)

);

// --------------------------------------------------
// Bus connection
// --------------------------------------------------

assign mem_rdata = ram_rdata;
assign mem_ready = mem_valid;

endmodule
