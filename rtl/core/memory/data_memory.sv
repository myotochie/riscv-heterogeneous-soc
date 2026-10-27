module data_memory #(
    parameter int unsigned MEM_SIZE_BYTES = 4096,
    parameter string INIT_FILE = ""
) (
    input  logic        clk,
    input  logic        reset,

    input  logic        mem_read,
    input  logic        mem_write,

    input  logic [63:0] address,
    input  logic [63:0] write_data,

    output logic [63:0] read_data,
    output logic        access_fault,
    output logic        misaligned_fault,
    output logic        out_of_range_fault
);

    // Byte-addressable memory.
    logic [7:0] mem [0:MEM_SIZE_BYTES-1];

    // Optional initialization for RTL simulation.
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end
    end

    localparam int unsigned ADDR_BITS = $clog2(MEM_SIZE_BYTES);

    logic address_valid;
    logic address_aligned;
    logic address_in_range;
    logic [ADDR_BITS-1:0] byte_index;

    // Only naturally aligned 64-bit accesses are supported.
    always_comb begin
        address_aligned = (address[2:0] == 3'b000);
        address_in_range =
            (address <= (64'(MEM_SIZE_BYTES) - 64'd8));

        address_valid = address_aligned && address_in_range;

        byte_index = address[ADDR_BITS-1:0];
    end

    // Classify memory address faults.
    always_comb begin
        misaligned_fault   = 1'b0;
        out_of_range_fault = 1'b0;

        if (mem_read || mem_write) begin
            misaligned_fault   = !address_aligned;
            out_of_range_fault = address_aligned && !address_in_range;
        end
    end

    // Combinational 64-bit read, little-endian.
    always_comb begin
        read_data = 64'b0;
        access_fault = 1'b0;

        if (mem_read || mem_write) begin
            if (!address_valid) begin
                access_fault = 1'b1;
            end else if (mem_read) begin
                for (int i = 0; i < 8; i++) begin
                    read_data[i*8 +: 8] = mem[byte_index + ADDR_BITS'(i)];
                end
            end
        end
    end

    // Synchronous 64-bit write.
    always_ff @(posedge clk) begin
        if (!reset && mem_write && address_valid) begin
            for (int i = 0; i < 8; i++) begin
                mem[byte_index + ADDR_BITS'(i)] <= write_data[i*8 +: 8];
            end
        end
    end

endmodule
