// Combinational instruction ROM. File parsing/diagnostics are simulation support.
module instruction_memory #(
    parameter int unsigned WORDS = 1024,
    parameter logic [63:0] BASE_ADDR = 64'h0000000080000000,
    parameter string INIT_FILE = ""
) (
    input logic [63:0] address,
    output logic [31:0] instruction,
    output logic address_fault
);
    localparam logic [63:0] CAPACITY_BYTES = 64'(WORDS) * 64'd4;
    logic [31:0] mem [0:WORDS-1];
    logic [63:0] offset;

    initial begin : initialize_rom
        for (int i = 0; i < WORDS; i++) mem[i] = 32'h00000013;
`ifndef SYNTHESIS
        begin : validate_image
            integer fd, status, count;
            string token;
            if (WORDS == 0 || BASE_ADDR[1:0] != 0 ||
                BASE_ADDR > (64'hffffffffffffffff - (CAPACITY_BYTES - 1)))
                $fatal(1, "IMEM_CONFIG: invalid base or capacity");
            if (INIT_FILE == "") $fatal(1, "IMEM_FILE: empty filename");
            fd = $fopen(INIT_FILE, "r");
            if (fd == 0) $fatal(1, "IMEM_FILE: cannot open %s", INIT_FILE);
            count = 0;
            status = $fscanf(fd, "%s", token);
            while (status == 1) begin
                if (count >= WORDS) $fatal(1, "IMEM_SIZE: image exceeds capacity");
                if (token.len() != 8) $fatal(1, "IMEM_FORMAT: expected eight hex digits");
                for (int j = 0; j < token.len(); j++) begin
                    if (!((token[j] >= "0" && token[j] <= "9") ||
                          (token[j] >= "a" && token[j] <= "f") ||
                          (token[j] >= "A" && token[j] <= "F")))
                        $fatal(1, "IMEM_FORMAT: non-hex digit");
                end
                count++;
                status = $fscanf(fd, "%s", token);
            end
            $fclose(fd);
            if (count == 0) $fatal(1, "IMEM_FORMAT: empty image");
        end
`endif
        // Validated dense word format: no @address, comments, X/Z or byte tokens.
        $readmemh(INIT_FILE, mem);
    end

    always_comb begin
        offset = address - BASE_ADDR;
        address_fault = address[1:0] != 0 || address < BASE_ADDR || offset >= CAPACITY_BYTES;
        instruction = 32'h00000013;
        if (!address_fault) instruction = mem[int'(offset >> 2)];
    end
endmodule
