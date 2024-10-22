`timescale 1ns / 1ps

// Fields of IR
`define oper_type IR[31:27]
`define rdst      IR[26:22]
`define rsrc1     IR[21:17]
`define imm_mode  IR[16]
`define rsrc2     IR[15:11]
`define isrc      IR[15:0]

// Arithmetic operations
`define movsgpr        5'b00000
`define mov            5'b00001
`define add            5'b00010
`define sub            5'b00011
`define mul            5'b00100

// Logical operations
`define ror            5'b00101
`define rand           5'b00110
`define rxor           5'b00111
`define rxnor          5'b01000
`define rnand          5'b01001
`define rnor           5'b01010
`define rnot           5'b01011

// Load & Store instructions
`define storereg       5'b01101   // Store content of register in data memory
`define storedin       5'b01110   // Store content of din bus in data memory
`define senddout       5'b01111   // Send data from DM to dout bus
`define sendreg        5'b10001   // Send data from DM to register

// Jump and Branch instructions
`define jump           5'b10010  // Jump to address
`define jcarry         5'b10011  // Jump if carry
`define jnocarry       5'b10100
`define jsign          5'b10101  // Jump if sign
`define jnosign        5'b10110
`define jzero          5'b10111  // Jump if zero
`define jnozero        5'b11000
`define joverflow      5'b11001  // Jump if overflow
`define jnooverflow    5'b11010

// Halt instruction
`define halt           5'b11011

module top(
    input clk,
    input sys_rst,
    input [15:0] din,
    output reg [15:0] dout
);

    // Program and Data Memory
    reg [31:0] inst_mem [0:15]; // Program memory
    reg [15:0] data_mem [0:15]; // Data memory

    reg [31:0] IR; // Instruction Register
    // GPRs and SGPR
    reg [15:0] GPR [0:31]; // General Purpose Registers
    reg [15:0] SGPR;       // Special Register (MSB of multiplication result)
    reg [31:0] mul_res;

    // Condition flags
    reg sign = 0, zero = 0, overflow = 0, carry = 0;
    reg [16:0] temp_sum;

    // Control signals
    reg jmp_flag = 0;
    reg stop = 0;

    // Program Counter
    integer PC = 0;

    // Instruction Decode and Execute
    task decode_inst;
    begin
        jmp_flag = 1'b0;
        stop     = 1'b0;

        case (`oper_type)
            // Move SGPR to GPR
            `movsgpr: begin
                GPR[`rdst] = SGPR;
            end

            // Move operations
            `mov: begin
                if (`imm_mode)
                    GPR[`rdst] = `isrc;
                else
                    GPR[`rdst] = GPR[`rsrc1];
            end

            // Add operations
            `add: begin
                if (`imm_mode)
                    GPR[`rdst] = GPR[`rsrc1] + `isrc;
                else
                    GPR[`rdst] = GPR[`rsrc1] + GPR[`rsrc2];
            end

            // Subtract operations
            `sub: begin
                if (`imm_mode)
                    GPR[`rdst] = GPR[`rsrc1] - `isrc;
                else
                    GPR[`rdst] = GPR[`rsrc1] - GPR[`rsrc2];
            end

            // Multiply operations
            `mul: begin
                if (`imm_mode)
                    mul_res = GPR[`rsrc1] * `isrc;
                else
                    mul_res = GPR[`rsrc1] * GPR[`rsrc2];
                GPR[`rdst] = mul_res[15:0];
                SGPR = mul_res[31:16];
            end

            // Logical OR
            `ror: begin
                if (`imm_mode)
                    GPR[`rdst] = GPR[`rsrc1] | `isrc;
                else
                    GPR[`rdst] = GPR[`rsrc1] | GPR[`rsrc2];
            end

            // Logical AND
            `rand: begin
                if (`imm_mode)
                    GPR[`rdst] = GPR[`rsrc1] & `isrc;
                else
                    GPR[`rdst] = GPR[`rsrc1] & GPR[`rsrc2];
            end

            // Logical XOR
            `rxor: begin
                if (`imm_mode)
                    GPR[`rdst] = GPR[`rsrc1] ^ `isrc;
                else
                    GPR[`rdst] = GPR[`rsrc1] ^ GPR[`rsrc2];
            end

            // Logical XNOR
            `rxnor: begin
                if (`imm_mode)
                    GPR[`rdst] = ~(GPR[`rsrc1] ^ `isrc);
                else
                    GPR[`rdst] = ~(GPR[`rsrc1] ^ GPR[`rsrc2]);
            end

            // Logical NAND
            `rnand: begin
                if (`imm_mode)
                    GPR[`rdst] = ~(GPR[`rsrc1] & `isrc);
                else
                    GPR[`rdst] = ~(GPR[`rsrc1] & GPR[`rsrc2]);
            end

            // Logical NOR
            `rnor: begin
                if (`imm_mode)
                    GPR[`rdst] = ~(GPR[`rsrc1] | `isrc);
                else
                    GPR[`rdst] = ~(GPR[`rsrc1] | GPR[`rsrc2]);
            end

            // Logical NOT
            `rnot: begin
                if (`imm_mode)
                    GPR[`rdst] = ~`isrc;
                else
                    GPR[`rdst] = ~GPR[`rsrc1];
            end

            // Store din to data memory
            `storedin: begin
                data_mem[`isrc] = din;
            end

            // Store register to data memory
            `storereg: begin
                data_mem[`isrc] = GPR[`rsrc1];
            end

            // Send data memory content to dout
            `senddout: begin
                dout = data_mem[`isrc];
            end

            // Send data memory content to register
            `sendreg: begin
                GPR[`rdst] = data_mem[`isrc];
            end

            // Jump and Branch Instructions
            `jump: begin
                jmp_flag = 1'b1;
            end

            `jcarry: begin
                if (carry)
                    jmp_flag = 1'b1;
            end

            `jnocarry: begin
                if (!carry)
                    jmp_flag = 1'b1;
            end

            `jsign: begin
                if (sign)
                    jmp_flag = 1'b1;
            end

            `jnosign: begin
                if (!sign)
                    jmp_flag = 1'b1;
            end

            `jzero: begin
                if (zero)
                    jmp_flag = 1'b1;
            end

            `jnozero: begin
                if (!zero)
                    jmp_flag = 1'b1;
            end

            `joverflow: begin
                if (overflow)
                    jmp_flag = 1'b1;
            end

            `jnooverflow: begin
                if (!overflow)
                    jmp_flag = 1'b1;
            end

            // Halt instruction
            `halt: begin
                stop = 1'b1;
            end

            default: begin
                // Handle default case if needed
            end
        endcase
    end
    endtask

    // Condition Flag Logic
    task decode_condflag;
    begin
        // Sign flag
        if (`oper_type == `mul)
            sign = SGPR[15];
        else
            sign = GPR[`rdst][15];

        // Carry flag
        if (`oper_type == `add)
        begin
            if (`imm_mode)
            begin
                temp_sum = GPR[`rsrc1] + `isrc;
                carry = temp_sum[16];
            end
            else
            begin
                temp_sum = GPR[`rsrc1] + GPR[`rsrc2];
                carry = temp_sum[16];
            end
        end
        else
            carry = 1'b0;

        // Zero flag
        if (`oper_type == `mul)
            zero = ~(|SGPR | |GPR[`rdst]);
        else
            zero = ~|GPR[`rdst];

        // Overflow flag
        if (`oper_type == `add)
        begin
            if (`imm_mode)
                overflow = (~GPR[`rsrc1][15] & ~`isrc[15] & GPR[`rdst][15]) | (GPR[`rsrc1][15] & `isrc[15] & ~GPR[`rdst][15]);
            else
                overflow = (~GPR[`rsrc1][15] & ~GPR[`rsrc2][15] & GPR[`rdst][15]) | (GPR[`rsrc1][15] & GPR[`rsrc2][15] & ~GPR[`rdst][15]);
        end
        else if (`oper_type == `sub)
        begin
            if (`imm_mode)
                overflow = (~GPR[`rsrc1][15] & `isrc[15] & GPR[`rdst][15]) | (GPR[`rsrc1][15] & ~`isrc[15] & ~GPR[`rdst][15]);
            else
                overflow = (~GPR[`rsrc1][15] & GPR[`rsrc2][15] & GPR[`rdst][15]) | (GPR[`rsrc1][15] & ~GPR[`rsrc2][15] & ~GPR[`rdst][15]);
        end
        else
            overflow = 1'b0;
    end
    endtask

    // Instruction Fetch and Execution FSM
    parameter idle = 3'd0, fetch_inst = 3'd1, dec_exec_inst = 3'd2, delay_next_inst = 3'd3, next_inst = 3'd4, sense_halt = 3'd5;
    reg [2:0] state = idle;
    reg [2:0] next_state = idle;
    reg [2:0] count = 0;

    // FSM State Register
    always @(posedge clk or posedge sys_rst)
    begin
        if (sys_rst)
            state <= idle;
        else
            state <= next_state;
    end

    // FSM Next State Logic and Output Logic
    always @(*)
    begin
        next_state = state;
        case (state)
            idle: begin
                IR = 32'h0;
                PC = 0;
                next_state = fetch_inst;
            end

            fetch_inst: begin
                IR = inst_mem[PC];
                next_state = dec_exec_inst;
            end

            dec_exec_inst: begin
                decode_inst();
                decode_condflag();
                next_state = delay_next_inst;
            end

            delay_next_inst: begin
                if (count < 4)
                    next_state = delay_next_inst;
                else
                    next_state = next_inst;
            end

            next_inst: begin
                if (jmp_flag)
                    PC = `isrc;
                else
                    PC = PC + 1;
                next_state = sense_halt;
            end

            sense_halt: begin
                if (stop)
                    next_state = sense_halt;
                else if (sys_rst)
                    next_state = idle;
                else
                    next_state = fetch_inst;
            end

            default: begin
                next_state = idle;
            end
        endcase
    end

    // Count Update
    always @(posedge clk or posedge sys_rst)
    begin
        if (sys_rst)
            count <= 0;
        else if (state == delay_next_inst)
            count <= count + 1;
        else
            count <= 0;
    end

    // Initialize Program Memory
    initial begin
        // Load instructions into inst_mem
        $readmemb("inst_data.mem", inst_mem);
    end

endmodule

// Testbench Module
module tb;

    reg clk = 0;
    reg sys_rst = 0;
    reg [15:0] din = 0;
    wire [15:0] dout;

    top dut (
        .clk(clk),
        .sys_rst(sys_rst),
        .din(din),
        .dout(dout)
    );

    // Clock generation
    always #5 clk = ~clk;

    initial begin
        sys_rst = 1'b1;
        repeat(2) @(posedge clk);
        sys_rst = 1'b0;

        // Provide test inputs if needed
        // For example, set din values, monitor dout, etc.

        // Simulation duration
        #1000;
        $finish;
    end

endmodule
