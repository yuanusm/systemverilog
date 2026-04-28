`timescale 1ns/1ps

module testbenchActividad3;
    localparam int M = 8;
    localparam int K = 2;

    logic [M-1:0] A;
    logic [M-1:0] B;
    logic [K-1:0] OpCode;
    logic [M-1:0] Result;
    logic [5:0] Flags;

    logic [M-1:0] exp_result;
    logic [5:0] exp_flags;

    int unsigned total_tests = 0;
    int unsigned error_count = 0;

    S4_Actividad3 #(.M(M), .K(K)) dut (
        .A(A),
        .B(B),
        .OpCode(OpCode),
        .Result(Result),
        .Flags(Flags)
    );

    task automatic compute_expected(
        input  logic [M-1:0] a_i,
        input  logic [M-1:0] b_i,
        input  logic [K-1:0] op_i,
        output logic [M-1:0] r_o,
        output logic [5:0] f_o
    );
        logic [M:0] a_ext, b_ext;
        logic [M:0] add_ext;
        logic [M:0] sub_ext;
        logic [M-1:0] r_pow;
    begin
        a_ext = {1'b0, a_i};
        b_ext = {1'b0, b_i};
        add_ext = a_ext + b_ext;
        sub_ext = a_ext - b_ext;
        f_o = '0;

        unique case (op_i)
            2'd0: begin r_o = a_i & b_i; f_o[1] = 1'b0; end
            2'd1: begin r_o = a_i | b_i; f_o[1] = 1'b0; end
            2'd2: begin r_o = add_ext[M-1:0]; f_o[1] = add_ext[M]; end
            2'd3: begin r_o = sub_ext[M-1:0]; f_o[1] = sub_ext[M]; end
            default: begin r_o = '0; f_o[1] = 1'b0; end
        endcase

        // V flag según implementación del DUT
        if ((op_i == 2'd2) && (a_i[M-1] == b_i[M-1]) && (r_o[M-1] != a_i[M-1]))
            f_o[0] = 1'b1;
        else if ((op_i == 2'd3) && (a_i[M-1] != b_i[M-1]) && (r_o[M-1] != a_i[M-1]))
            f_o[0] = 1'b1;
        else
            f_o[0] = 1'b0;

        // Z y S
        if (r_o == '0) begin
            f_o[5] = 1'b1;
            f_o[2] = 1'b0;
        end else begin
            f_o[5] = 1'b0;
            r_pow = r_o & (r_o - 1'b1);
            f_o[2] = (r_pow == '0);
        end

        // P (paridad par) y N
        f_o[3] = (^r_o == 1'b0);
        f_o[4] = r_o[M-1];
    end
    endtask

    task automatic check_case(
        input logic [M-1:0] a_i,
        input logic [M-1:0] b_i,
        input logic [K-1:0] op_i,
        input string tag
    );
    begin
        A = a_i;
        B = b_i;
        OpCode = op_i;
        #1;

        compute_expected(a_i, b_i, op_i, exp_result, exp_flags);
        total_tests++;

        if ((Result !== exp_result) || (Flags !== exp_flags)) begin
            error_count++;
            $display("[ERROR][%0s] op=%0d A=0x%0h B=0x%0h | DUT R=0x%0h F=%06b | EXP R=0x%0h F=%06b",
                     tag, op_i, a_i, b_i, Result, Flags, exp_result, exp_flags);
        end
    end
    endtask

    initial begin
        $display("==== Inicio testbenchActividad3 (M=%0d) ====", M);

        // Casos dirigidos para cubrir condiciones de bandera
        check_case(8'h00, 8'h00, 2'd0, "AND_zero");
        check_case(8'hFF, 8'h0F, 2'd0, "AND_basic");
        check_case(8'h00, 8'h00, 2'd1, "OR_zero");
        check_case(8'h80, 8'h01, 2'd1, "OR_sign");

        check_case(8'h7F, 8'h01, 2'd2, "ADD_overflow_pos");
        check_case(8'h80, 8'h80, 2'd2, "ADD_overflow_neg_and_carry");
        check_case(8'hFF, 8'h01, 2'd2, "ADD_carry_only");

        check_case(8'h00, 8'h01, 2'd3, "SUB_borrow");
        check_case(8'h80, 8'h01, 2'd3, "SUB_overflow_neg_minus_pos");
        check_case(8'h7F, 8'hFF, 2'd3, "SUB_overflow_pos_minus_neg");

        // Barrido exhaustivo: todas las combinaciones A,B,OpCode
        for (int op = 0; op < (1<<K); op++) begin
            for (int a = 0; a < (1<<M); a++) begin
                for (int b = 0; b < (1<<M); b++) begin
                    check_case(a[M-1:0], b[M-1:0], op[K-1:0], "EXH");
                end
            end
            $display("Progreso: OpCode=%0d completado", op);
        end

        $display("==== Fin testbenchActividad3 ==== Total=%0d Errores=%0d", total_tests, error_count);
        if (error_count == 0) begin
            $display("RESULTADO: PASS");
        end else begin
            $display("RESULTADO: FAIL");
        end
        $finish;
    end
endmodule
