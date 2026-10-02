// ============================================================
// aes_top.v
// Single-file, fully procedural AES-128 encryption core.
// Deliberately monolithic (no generate blocks, no submodule
// hierarchy, no arrays of net/wire) for maximum simulator/tool
// compatibility.
//
// 11 clock cycles from 'start' pulse to 'done' pulse:
//   cycle 1     : AddRoundKey (round key 0)
//   cycles 2-9  : full rounds 1..9 (SubBytes,ShiftRows,MixColumns,AddRoundKey)
//   cycle 10    : final round 10   (SubBytes,ShiftRows,AddRoundKey - no MixColumns)
//   cycle 11    : done asserted, ciphertext valid
//
// phase_ce (NEW): phase-based clock enable output. High on every
// cycle the datapath register actually updates (load/round/final),
// low otherwise (idle, waiting for start, the done cycle). This is
// purely an observability/power-analysis signal - it is not used
// to gate anything internally, so it cannot affect ciphertext
// correctness. See clock_enable.v for details.
// ============================================================
module aes_top (
    input  wire         clk,
    input  wire         rst,        // synchronous, active-high
    input  wire         start,      // pulse high for 1 cycle to begin
    input  wire [127:0] plaintext,
    input  wire [127:0] key,
    output reg  [127:0] ciphertext,
    output reg          done,
    output wire         phase_ce    // NEW: phase-based clock enable (demo signal)
);

    // ------------------------------------------------------------
    // S-box (function form - no ROM module, no instantiation)
    // ------------------------------------------------------------
    function [7:0] sbox_f;
        input [7:0] in;
        begin
            case (in)
                8'h00: sbox_f = 8'h63;
                8'h01: sbox_f = 8'h7c;
                8'h02: sbox_f = 8'h77;
                8'h03: sbox_f = 8'h7b;
                8'h04: sbox_f = 8'hf2;
                8'h05: sbox_f = 8'h6b;
                8'h06: sbox_f = 8'h6f;
                8'h07: sbox_f = 8'hc5;
                8'h08: sbox_f = 8'h30;
                8'h09: sbox_f = 8'h01;
                8'h0a: sbox_f = 8'h67;
                8'h0b: sbox_f = 8'h2b;
                8'h0c: sbox_f = 8'hfe;
                8'h0d: sbox_f = 8'hd7;
                8'h0e: sbox_f = 8'hab;
                8'h0f: sbox_f = 8'h76;
                8'h10: sbox_f = 8'hca;
                8'h11: sbox_f = 8'h82;
                8'h12: sbox_f = 8'hc9;
                8'h13: sbox_f = 8'h7d;
                8'h14: sbox_f = 8'hfa;
                8'h15: sbox_f = 8'h59;
                8'h16: sbox_f = 8'h47;
                8'h17: sbox_f = 8'hf0;
                8'h18: sbox_f = 8'had;
                8'h19: sbox_f = 8'hd4;
                8'h1a: sbox_f = 8'ha2;
                8'h1b: sbox_f = 8'haf;
                8'h1c: sbox_f = 8'h9c;
                8'h1d: sbox_f = 8'ha4;
                8'h1e: sbox_f = 8'h72;
                8'h1f: sbox_f = 8'hc0;
                8'h20: sbox_f = 8'hb7;
                8'h21: sbox_f = 8'hfd;
                8'h22: sbox_f = 8'h93;
                8'h23: sbox_f = 8'h26;
                8'h24: sbox_f = 8'h36;
                8'h25: sbox_f = 8'h3f;
                8'h26: sbox_f = 8'hf7;
                8'h27: sbox_f = 8'hcc;
                8'h28: sbox_f = 8'h34;
                8'h29: sbox_f = 8'ha5;
                8'h2a: sbox_f = 8'he5;
                8'h2b: sbox_f = 8'hf1;
                8'h2c: sbox_f = 8'h71;
                8'h2d: sbox_f = 8'hd8;
                8'h2e: sbox_f = 8'h31;
                8'h2f: sbox_f = 8'h15;
                8'h30: sbox_f = 8'h04;
                8'h31: sbox_f = 8'hc7;
                8'h32: sbox_f = 8'h23;
                8'h33: sbox_f = 8'hc3;
                8'h34: sbox_f = 8'h18;
                8'h35: sbox_f = 8'h96;
                8'h36: sbox_f = 8'h05;
                8'h37: sbox_f = 8'h9a;
                8'h38: sbox_f = 8'h07;
                8'h39: sbox_f = 8'h12;
                8'h3a: sbox_f = 8'h80;
                8'h3b: sbox_f = 8'he2;
                8'h3c: sbox_f = 8'heb;
                8'h3d: sbox_f = 8'h27;
                8'h3e: sbox_f = 8'hb2;
                8'h3f: sbox_f = 8'h75;
                8'h40: sbox_f = 8'h09;
                8'h41: sbox_f = 8'h83;
                8'h42: sbox_f = 8'h2c;
                8'h43: sbox_f = 8'h1a;
                8'h44: sbox_f = 8'h1b;
                8'h45: sbox_f = 8'h6e;
                8'h46: sbox_f = 8'h5a;
                8'h47: sbox_f = 8'ha0;
                8'h48: sbox_f = 8'h52;
                8'h49: sbox_f = 8'h3b;
                8'h4a: sbox_f = 8'hd6;
                8'h4b: sbox_f = 8'hb3;
                8'h4c: sbox_f = 8'h29;
                8'h4d: sbox_f = 8'he3;
                8'h4e: sbox_f = 8'h2f;
                8'h4f: sbox_f = 8'h84;
                8'h50: sbox_f = 8'h53;
                8'h51: sbox_f = 8'hd1;
                8'h52: sbox_f = 8'h00;
                8'h53: sbox_f = 8'hed;
                8'h54: sbox_f = 8'h20;
                8'h55: sbox_f = 8'hfc;
                8'h56: sbox_f = 8'hb1;
                8'h57: sbox_f = 8'h5b;
                8'h58: sbox_f = 8'h6a;
                8'h59: sbox_f = 8'hcb;
                8'h5a: sbox_f = 8'hbe;
                8'h5b: sbox_f = 8'h39;
                8'h5c: sbox_f = 8'h4a;
                8'h5d: sbox_f = 8'h4c;
                8'h5e: sbox_f = 8'h58;
                8'h5f: sbox_f = 8'hcf;
                8'h60: sbox_f = 8'hd0;
                8'h61: sbox_f = 8'hef;
                8'h62: sbox_f = 8'haa;
                8'h63: sbox_f = 8'hfb;
                8'h64: sbox_f = 8'h43;
                8'h65: sbox_f = 8'h4d;
                8'h66: sbox_f = 8'h33;
                8'h67: sbox_f = 8'h85;
                8'h68: sbox_f = 8'h45;
                8'h69: sbox_f = 8'hf9;
                8'h6a: sbox_f = 8'h02;
                8'h6b: sbox_f = 8'h7f;
                8'h6c: sbox_f = 8'h50;
                8'h6d: sbox_f = 8'h3c;
                8'h6e: sbox_f = 8'h9f;
                8'h6f: sbox_f = 8'ha8;
                8'h70: sbox_f = 8'h51;
                8'h71: sbox_f = 8'ha3;
                8'h72: sbox_f = 8'h40;
                8'h73: sbox_f = 8'h8f;
                8'h74: sbox_f = 8'h92;
                8'h75: sbox_f = 8'h9d;
                8'h76: sbox_f = 8'h38;
                8'h77: sbox_f = 8'hf5;
                8'h78: sbox_f = 8'hbc;
                8'h79: sbox_f = 8'hb6;
                8'h7a: sbox_f = 8'hda;
                8'h7b: sbox_f = 8'h21;
                8'h7c: sbox_f = 8'h10;
                8'h7d: sbox_f = 8'hff;
                8'h7e: sbox_f = 8'hf3;
                8'h7f: sbox_f = 8'hd2;
                8'h80: sbox_f = 8'hcd;
                8'h81: sbox_f = 8'h0c;
                8'h82: sbox_f = 8'h13;
                8'h83: sbox_f = 8'hec;
                8'h84: sbox_f = 8'h5f;
                8'h85: sbox_f = 8'h97;
                8'h86: sbox_f = 8'h44;
                8'h87: sbox_f = 8'h17;
                8'h88: sbox_f = 8'hc4;
                8'h89: sbox_f = 8'ha7;
                8'h8a: sbox_f = 8'h7e;
                8'h8b: sbox_f = 8'h3d;
                8'h8c: sbox_f = 8'h64;
                8'h8d: sbox_f = 8'h5d;
                8'h8e: sbox_f = 8'h19;
                8'h8f: sbox_f = 8'h73;
                8'h90: sbox_f = 8'h60;
                8'h91: sbox_f = 8'h81;
                8'h92: sbox_f = 8'h4f;
                8'h93: sbox_f = 8'hdc;
                8'h94: sbox_f = 8'h22;
                8'h95: sbox_f = 8'h2a;
                8'h96: sbox_f = 8'h90;
                8'h97: sbox_f = 8'h88;
                8'h98: sbox_f = 8'h46;
                8'h99: sbox_f = 8'hee;
                8'h9a: sbox_f = 8'hb8;
                8'h9b: sbox_f = 8'h14;
                8'h9c: sbox_f = 8'hde;
                8'h9d: sbox_f = 8'h5e;
                8'h9e: sbox_f = 8'h0b;
                8'h9f: sbox_f = 8'hdb;
                8'ha0: sbox_f = 8'he0;
                8'ha1: sbox_f = 8'h32;
                8'ha2: sbox_f = 8'h3a;
                8'ha3: sbox_f = 8'h0a;
                8'ha4: sbox_f = 8'h49;
                8'ha5: sbox_f = 8'h06;
                8'ha6: sbox_f = 8'h24;
                8'ha7: sbox_f = 8'h5c;
                8'ha8: sbox_f = 8'hc2;
                8'ha9: sbox_f = 8'hd3;
                8'haa: sbox_f = 8'hac;
                8'hab: sbox_f = 8'h62;
                8'hac: sbox_f = 8'h91;
                8'had: sbox_f = 8'h95;
                8'hae: sbox_f = 8'he4;
                8'haf: sbox_f = 8'h79;
                8'hb0: sbox_f = 8'he7;
                8'hb1: sbox_f = 8'hc8;
                8'hb2: sbox_f = 8'h37;
                8'hb3: sbox_f = 8'h6d;
                8'hb4: sbox_f = 8'h8d;
                8'hb5: sbox_f = 8'hd5;
                8'hb6: sbox_f = 8'h4e;
                8'hb7: sbox_f = 8'ha9;
                8'hb8: sbox_f = 8'h6c;
                8'hb9: sbox_f = 8'h56;
                8'hba: sbox_f = 8'hf4;
                8'hbb: sbox_f = 8'hea;
                8'hbc: sbox_f = 8'h65;
                8'hbd: sbox_f = 8'h7a;
                8'hbe: sbox_f = 8'hae;
                8'hbf: sbox_f = 8'h08;
                8'hc0: sbox_f = 8'hba;
                8'hc1: sbox_f = 8'h78;
                8'hc2: sbox_f = 8'h25;
                8'hc3: sbox_f = 8'h2e;
                8'hc4: sbox_f = 8'h1c;
                8'hc5: sbox_f = 8'ha6;
                8'hc6: sbox_f = 8'hb4;
                8'hc7: sbox_f = 8'hc6;
                8'hc8: sbox_f = 8'he8;
                8'hc9: sbox_f = 8'hdd;
                8'hca: sbox_f = 8'h74;
                8'hcb: sbox_f = 8'h1f;
                8'hcc: sbox_f = 8'h4b;
                8'hcd: sbox_f = 8'hbd;
                8'hce: sbox_f = 8'h8b;
                8'hcf: sbox_f = 8'h8a;
                8'hd0: sbox_f = 8'h70;
                8'hd1: sbox_f = 8'h3e;
                8'hd2: sbox_f = 8'hb5;
                8'hd3: sbox_f = 8'h66;
                8'hd4: sbox_f = 8'h48;
                8'hd5: sbox_f = 8'h03;
                8'hd6: sbox_f = 8'hf6;
                8'hd7: sbox_f = 8'h0e;
                8'hd8: sbox_f = 8'h61;
                8'hd9: sbox_f = 8'h35;
                8'hda: sbox_f = 8'h57;
                8'hdb: sbox_f = 8'hb9;
                8'hdc: sbox_f = 8'h86;
                8'hdd: sbox_f = 8'hc1;
                8'hde: sbox_f = 8'h1d;
                8'hdf: sbox_f = 8'h9e;
                8'he0: sbox_f = 8'he1;
                8'he1: sbox_f = 8'hf8;
                8'he2: sbox_f = 8'h98;
                8'he3: sbox_f = 8'h11;
                8'he4: sbox_f = 8'h69;
                8'he5: sbox_f = 8'hd9;
                8'he6: sbox_f = 8'h8e;
                8'he7: sbox_f = 8'h94;
                8'he8: sbox_f = 8'h9b;
                8'he9: sbox_f = 8'h1e;
                8'hea: sbox_f = 8'h87;
                8'heb: sbox_f = 8'he9;
                8'hec: sbox_f = 8'hce;
                8'hed: sbox_f = 8'h55;
                8'hee: sbox_f = 8'h28;
                8'hef: sbox_f = 8'hdf;
                8'hf0: sbox_f = 8'h8c;
                8'hf1: sbox_f = 8'ha1;
                8'hf2: sbox_f = 8'h89;
                8'hf3: sbox_f = 8'h0d;
                8'hf4: sbox_f = 8'hbf;
                8'hf5: sbox_f = 8'he6;
                8'hf6: sbox_f = 8'h42;
                8'hf7: sbox_f = 8'h68;
                8'hf8: sbox_f = 8'h41;
                8'hf9: sbox_f = 8'h99;
                8'hfa: sbox_f = 8'h2d;
                8'hfb: sbox_f = 8'h0f;
                8'hfc: sbox_f = 8'hb0;
                8'hfd: sbox_f = 8'h54;
                8'hfe: sbox_f = 8'hbb;
                8'hff: sbox_f = 8'h16;
                default: sbox_f = 8'h00;
            endcase
        end
    endfunction

    // ------------------------------------------------------------
    // Key expansion: W[0..43], recomputed whenever 'key' changes.
    // Standard reg-array-in-procedural-block style (no unpacked
    // net arrays, no generate).
    // ------------------------------------------------------------
    reg  [31:0] W [0:43];
    integer     k;
    reg  [31:0] wtemp;
    reg  [7:0]  rc;

    always @* begin
        W[0] = key[127:96];
        W[1] = key[95:64];
        W[2] = key[63:32];
        W[3] = key[31:0];

        for (k = 4; k < 44; k = k + 1) begin
            wtemp = W[k-1];
            if (k % 4 == 0) begin
                wtemp = { wtemp[23:0], wtemp[31:24] };                                  // RotWord
                wtemp = { sbox_f(wtemp[31:24]), sbox_f(wtemp[23:16]),
                           sbox_f(wtemp[15:8]),  sbox_f(wtemp[7:0]) };                    // SubWord
                case (k/4)
                    1:  rc = 8'h01;
                    2:  rc = 8'h02;
                    3:  rc = 8'h04;
                    4:  rc = 8'h08;
                    5:  rc = 8'h10;
                    6:  rc = 8'h20;
                    7:  rc = 8'h40;
                    8:  rc = 8'h80;
                    9:  rc = 8'h1b;
                    10: rc = 8'h36;
                    default: rc = 8'h00;
                endcase
                wtemp = wtemp ^ { rc, 24'h000000 };
            end
            W[k] = W[k-4] ^ wtemp;
        end
    end

    function [127:0] round_key;
        input [3:0] r;
        begin
            round_key = { W[4*r], W[4*r+1], W[4*r+2], W[4*r+3] };
        end
    endfunction

    // ------------------------------------------------------------
    // Round transforms (function form)
    // ------------------------------------------------------------
    function [127:0] sub_bytes_f;
        input [127:0] s;
        integer i;
        reg [127:0] o;
        begin
            for (i = 0; i < 16; i = i + 1)
                o[127 - i*8 -: 8] = sbox_f(s[127 - i*8 -: 8]);
            sub_bytes_f = o;
        end
    endfunction

    function [127:0] shift_rows_f;
        input [127:0] s;
        reg [7:0] b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14,b15;
        begin
            b0=s[127:120];  b1=s[119:112]; b2=s[111:104]; b3=s[103:96];
            b4=s[95:88];    b5=s[87:80];   b6=s[79:72];   b7=s[71:64];
            b8=s[63:56];    b9=s[55:48];   b10=s[47:40];  b11=s[39:32];
            b12=s[31:24];   b13=s[23:16];  b14=s[15:8];   b15=s[7:0];
            shift_rows_f = { b0,b5,b10,b15,  b4,b9,b14,b3,  b8,b13,b2,b7,  b12,b1,b6,b11 };
        end
    endfunction

    function [7:0] xtime;
        input [7:0] x;
        begin
            xtime = x[7] ? ((x << 1) ^ 8'h1b) : (x << 1);
        end
    endfunction

    function [127:0] mix_columns_f;
        input [127:0] s;
        integer c;
        reg [7:0] s0,s1,s2,s3;
        reg [127:0] o;
        begin
            for (c = 0; c < 4; c = c + 1) begin
                s0 = s[127 - (c*4+0)*8 -: 8];
                s1 = s[127 - (c*4+1)*8 -: 8];
                s2 = s[127 - (c*4+2)*8 -: 8];
                s3 = s[127 - (c*4+3)*8 -: 8];
                o[127 - (c*4+0)*8 -: 8] = xtime(s0) ^ (xtime(s1)^s1) ^ s2 ^ s3;
                o[127 - (c*4+1)*8 -: 8] = s0 ^ xtime(s1) ^ (xtime(s2)^s2) ^ s3;
                o[127 - (c*4+2)*8 -: 8] = s0 ^ s1 ^ xtime(s2) ^ (xtime(s3)^s3);
                o[127 - (c*4+3)*8 -: 8] = (xtime(s0)^s0) ^ s1 ^ s2 ^ xtime(s3);
            end
            mix_columns_f = o;
        end
    endfunction

    // ------------------------------------------------------------
    // Combinational per-cycle round datapath, driven purely by
    // functions (no submodule instances, no hierarchy)
    // ------------------------------------------------------------
    wire [127:0] sb_out = sub_bytes_f(state);
    wire [127:0] sr_out = shift_rows_f(sb_out);
    wire [127:0] mc_out = mix_columns_f(sr_out);

    // ------------------------------------------------------------
    // Control FSM + state register
    // ------------------------------------------------------------
    localparam IDLE = 2'd0, ROUND = 2'd1, FINAL = 2'd2, DONE_ST = 2'd3;

    reg [1:0]   fsm_state;
    reg [127:0] state;
    reg [3:0]   round_cnt;

    always @(posedge clk) begin
        if (rst) begin
            fsm_state  <= IDLE;
            state      <= 128'b0;
            round_cnt  <= 4'd0;
            done       <= 1'b0;
            ciphertext <= 128'b0;
        end else begin
            case (fsm_state)

                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state     <= plaintext ^ round_key(0);
                        round_cnt <= 4'd1;
                        fsm_state <= ROUND;
                    end
                end

                ROUND: begin
                    state <= mc_out ^ round_key(round_cnt);
                    if (round_cnt == 4'd9) begin
                        round_cnt <= 4'd10;
                        fsm_state <= FINAL;
                    end else begin
                        round_cnt <= round_cnt + 1'b1;
                    end
                end

                FINAL: begin
                    ciphertext <= sr_out ^ round_key(10);
                    done       <= 1'b1;
                    fsm_state  <= DONE_ST;
                end

                DONE_ST: begin
                    done      <= 1'b0;
                    fsm_state <= IDLE;
                end

                default: fsm_state <= IDLE;

            endcase
        end
    end

    // ------------------------------------------------------------
    // Phase-based clock enable (NEW)
    // High exactly on cycles where 'state', 'ciphertext' or the
    // FSM registers actually need to update; low on idle cycles.
    // Purely observational - does not feed back into any existing
    // signal, so it cannot change the ciphertext result.
    // ------------------------------------------------------------
    wire phase_active = (fsm_state == IDLE  && start) ||
                         (fsm_state == ROUND)          ||
                         (fsm_state == FINAL);

    clock_enable u_clock_enable (
        .clk          (clk),
        .rst          (rst),
        .phase_active (phase_active),
        .ce_out       (phase_ce)
    );

endmodule
