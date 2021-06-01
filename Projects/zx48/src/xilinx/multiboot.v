//-------------------------------------------------------------------------------------------------
module multiboot
//-------------------------------------------------------------------------------------------------
#
(
	parameter ADDR = 24'd0	// lx25 = 24'h0B0000, lx16 = 24'h098000, lx9 24'h058000
)
(
	input wire clock,
	input wire boot
);
//-------------------------------------------------------------------------------------------------

reg[4:0] q;
reg reboot;

always @(posedge clock)
begin
	q  <= { q[3:0], boot };
	reboot <= q[4] && !q[3] && !q[2] && !q[1];
end

//-------------------------------------------------------------------------------------------------

reg[15:0] icap_din;
reg       icap_ce;
reg       icap_wr;

reg[15:0] ff_icap_din;
reg       ff_icap_ce;
reg       ff_icap_wr;

ICAP_SPARTAN6 IcapSpartan6
(
	.CLK  (clock      ),
	.CE   (ff_icap_ce ),
	.I    (ff_icap_din),
	.O    (           ),
	.BUSY (           ),
	.WRITE(ff_icap_wr )
);

//  -------------------------------------------------
//  --  State Machine for ICAP_SPARTAN6 MultiBoot  --
//  -------------------------------------------------

parameter         IDLE     = 0,
                  SYNC_H   = 1,
                  SYNC_L   = 2,

                  CWD_H    = 3,
                  CWD_L    = 4,

                  GEN1_H   = 5,
                  GEN1_L   = 6,

                  GEN2_H   = 7,
                  GEN2_L   = 8,

                  GEN3_H   = 9,
                  GEN3_L   = 10,

                  GEN4_H   = 11,
                  GEN4_L   = 12,

                  GEN5_H   = 13,
                  GEN5_L   = 14,

                  NUL_H    = 15,
                  NUL_L    = 16,

                  MOD_H    = 17,
                  MOD_L    = 18,

                  HCO_H    = 19,
                  HCO_L    = 20,

                  RBT_H    = 21,
                  RBT_L    = 22,

                  NOOP_0   = 23,
                  NOOP_1   = 24,
                  NOOP_2   = 25,
                  NOOP_3   = 26;

reg[4:0] state = IDLE;
reg[4:0] next_state;

always @(posedge clock) state <= next_state;

always @*
   begin: COMB

      case (state)

         IDLE:
            begin
               if (reboot)
                  begin
                     next_state  = SYNC_H;
                     icap_ce     = 0;
                     icap_wr     = 0;
                     icap_din    = 16'hAA99;  // Sync word 1
                  end
               else
                  begin
                     next_state  = IDLE;
                     icap_ce     = 1;
                     icap_wr     = 1;
                     icap_din    = 16'hFFFF;  // Null
                  end
            end

         SYNC_H:
            begin
               next_state  = SYNC_L;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h5566;    // Sync word 2
            end

         SYNC_L:
            begin
               next_state  = NUL_H;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h30A1;    //  Write to Command Register....
            end

        NUL_H:
            begin
              // next_state  = NUL_L;
	       next_state  = GEN1_H;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h0000;   //  Null Command issued....  value = 0x0000
            end

//Q

         GEN1_H:
            begin
               next_state  = GEN1_L;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h3261;    //  Escritura a reg GENERAL_1 (bit boot en caliente)
            end

        GEN1_L:
            begin
               next_state  = GEN2_H;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = ADDR[15:0]; //16'hC000;   //  dreccion SPI BAJA
            end

         GEN2_H:
            begin
               next_state  = GEN2_L;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h3281;   //  Escritura a reg GENERAL_2
            end

        GEN2_L:
            begin
               next_state  = NUL_L; //MOD_H;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = {8'h03, ADDR[23:16]}; // 16'h030A;   //  03 lectura SPI opcode + direccion SPI ALTA (03 = 1x, 6B = 4x)
            end

///////	Registro MODE (para carga a 4x tras reboot)

        MOD_H:
            begin
               next_state  = MOD_L;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h3301;   //  Escritura a reg MODE
            end

        MOD_L:
            begin
               next_state  = NUL_L;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h2100; // Activamos bit de lectura a modo 4x en el proceso de Config
            end
/////

        NUL_L:
            begin
               next_state  = RBT_H;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h30A1;    //  Write to Command Register....
            end

        RBT_H:
            begin
               next_state  = RBT_L;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h000E;    // REBOOT Command 0x000E
            end

//--------------------

        RBT_L:
            begin
               next_state  = NOOP_0;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h2000;    //  NOOP
            end

        NOOP_0:
            begin
               next_state  = NOOP_1;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h2000;    // NOOP
            end

        NOOP_1:
            begin
               next_state  = NOOP_2;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h2000;    // NOOP
            end

        NOOP_2:
            begin
               next_state  = NOOP_3;
               icap_ce     = 0;
               icap_wr     = 0;
               icap_din    = 16'h2000;    // NOOP
            end

//--------------------

        NOOP_3:
            begin
               next_state  = IDLE;
               icap_ce     = 1;
               icap_wr     = 1;
               icap_din    = 16'h1111;    // NULL value
            end

        default:
            begin
               next_state  = IDLE;
               icap_ce     = 1;
               icap_wr     = 1;
               icap_din    = 16'h1111;    //  16'h1111"
            end

      endcase
   end

always @(posedge clock)
begin: ICAP_FF
	ff_icap_din[ 0] <= icap_din[ 7]; //need to reverse bits to ICAP module since D0 bit is read first
	ff_icap_din[ 1] <= icap_din[ 6];
	ff_icap_din[ 2] <= icap_din[ 5];
	ff_icap_din[ 3] <= icap_din[ 4];
	ff_icap_din[ 4] <= icap_din[ 3];
	ff_icap_din[ 5] <= icap_din[ 2];
	ff_icap_din[ 6] <= icap_din[ 1];
	ff_icap_din[ 7] <= icap_din[ 0];
	ff_icap_din[ 8] <= icap_din[15];
	ff_icap_din[ 9] <= icap_din[14];
	ff_icap_din[10] <= icap_din[13];
	ff_icap_din[11] <= icap_din[12];
	ff_icap_din[12] <= icap_din[11];
	ff_icap_din[13] <= icap_din[10];
	ff_icap_din[14] <= icap_din[ 9];
	ff_icap_din[15] <= icap_din[ 8];

	ff_icap_ce  <= icap_ce;
	ff_icap_wr  <= icap_wr;
end

endmodule
