library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

use     work.JtagTapPkg.all;

entity JtagTap is
   generic (
      CFG_G            : JtagTapInstructionArray;
      -- index of ID instruction in CFG_G if supported
      ID_INSTRUCTION_G : integer := -1
   );
   port (
      clk              : in  std_logic;
      rst              : in  std_logic;

      tck              : in  std_logic;
      tms              : in  std_logic;
      tdi              : in  std_logic;
      tdo              : out std_logic;

      tckRising        : out std_logic;
      tckFalling       : out std_logic;

      state            : out JtagTapStateType;
      instructionIdx   : out integer range -1 to numInstructions(CFG_G) - 1;
      -- two lsbits of instruction capture are "01" according to std.
      instructionCapt  : in  std_logic_vector(instructionSize(CFG_G) - 1 downto  2) := (others => '0');
      instructionSel   : out std_logic_vector(numInstructions(CFG_G) - 1 downto  0);
      tdoSel           : in  std_logic_vector(numInstructions(CFG_G) - 1 downto  0);
      captureD         : out std_logic;
      shiftD           : out std_logic;
      updateD          : out std_logic
   );
end entity JtagTap;

architecture rtl of JtagTap is

   subtype  InstructionType is std_logic_vector(instructionSize(CFG_G) - 1 downto 0);

   constant I_BYPASS_C      : InstructionType := (others => '1');
   constant BYPASS_IDX_C    : integer         := -1;

   function DEFAULT_INSTRUCTION return integer is
   begin
      if ( ID_INSTRUCTION_G >= 0 and ID_INSTRUCTION_G < numInstructions(CFG_G) ) then
         return ID_INSTRUCTION_G;
      else
         return BYPASS_IDX_C;
      end if;
   end function DEFAULT_INSTRUCTION;

   type RegType is record
      state            : JtagTapStateType;
      ltck             : std_logic;
      dly              : std_logic;
      tdo              : std_logic;
      sr               : InstructionType;
      instructionIdx   : integer range -1 to numInstructions(CFG_G) - 1;
   end record RegType;

   constant REG_INIT_C : RegType := (
      state            => TEST_LOGIC_RESET,
      ltck             => '1',
      dly              => '0',
      tdo              => '0',
      sr               => (others => '0'),
      instructionIdx   => DEFAULT_INSTRUCTION
   );

   signal r            : RegType := REG_INIT_C;
   signal rin          : RegType;
begin

   P_COMB : process ( r, tck, tms, tdi, instructionCapt, tdoSel ) is
      variable v : RegType;
   begin
      v                := r;
      v.ltck           := tck;
      v.dly            := '1'; -- wait for ltck being valid
      if ( r.dly = '1' ) then
         if ( r.ltck /= tck ) then
            if ( tck = '1' ) then -- rising edge
               case ( r.state ) is
                  when TEST_LOGIC_RESET =>
                     if ( tms = '0' ) then
                        v.state := RUN_TEST_IDLE;
                     end if;
                  when RUN_TEST_IDLE =>
                     if ( tms = '1' ) then
                        v.state := SELECT_DR_SCAN;
                     end if;
                  when SELECT_DR_SCAN =>
                     if ( tms = '1' ) then
                        v.state := SELECT_IR_SCAN;
                     else
                        v.state := CAPTURE_DR;
                     end if;
                  when CAPTURE_DR =>
                     if ( tms = '1' ) then
                        v.state := EXIT1_DR;
                     else
                        v.state := SHIFT_DR;
                     end if;
                     if ( r.instructionIdx < 0 ) then
                        -- bypass reg. initialized to '0'
                        v.sr(0) := '0';
                     end if;
                  when SHIFT_DR =>
                     if ( tms = '1' ) then
                        v.state := EXIT1_DR;
                     end if;
                     if ( r.instructionIdx < 0 ) then
                        -- bypass reg
                        v.sr(0) := tdi;
                     end if;
                  when EXIT1_DR =>
                     if ( tms = '1' ) then
                        v.state := UPDATE_DR;
                     else
                        v.state := PAUSE_DR;
                     end if;
                  when PAUSE_DR =>
                     if ( tms = '1' ) then
                        v.state := EXIT2_DR;
                     end if;
                  when EXIT2_DR =>
                     if ( tms = '1' ) then
                        v.state := UPDATE_DR;
                     else
                        v.state := SHIFT_DR;
                     end if;
                  when UPDATE_DR =>
                     if ( tms = '1' ) then
                        v.state := SELECT_DR_SCAN;
                     else
                        v.state := RUN_TEST_IDLE;
                     end if;
                  when SELECT_IR_SCAN =>
                     if ( tms = '1' ) then
                        v.state := TEST_LOGIC_RESET;
                     else
                        v.state := CAPTURE_IR;
                     end if;
                  when CAPTURE_IR =>
                     v.sr(instructionCapt'range) := instructionCapt;
                     v.sr(     1 downto       0) := "01";
                     if ( tms = '1' ) then
                        v.state := EXIT1_IR;
                     else
                        v.state := SHIFT_IR;
                     end if;
                  when SHIFT_IR =>
                     v.sr      := tdi & r.sr(r.sr'left downto 1); 
                     if ( tms = '1' ) then
                        v.state := EXIT1_IR;
                     end if;
                  when EXIT1_IR =>
                     if ( tms = '1' ) then
                        v.state := UPDATE_IR;
                     else
                        v.state := PAUSE_IR;
                     end if;
                  when PAUSE_IR =>
                     if ( tms = '1' ) then
                        v.state := EXIT2_IR;
                     end if;
                  when EXIT2_IR =>
                     if ( tms = '1' ) then
                        v.state := UPDATE_IR;
                     else
                        v.state := SHIFT_IR;
                     end if;
                  when UPDATE_IR =>
                     if ( tms = '1' ) then
                        v.state := SELECT_DR_SCAN;
                     else
                        v.state := RUN_TEST_IDLE;
                     end if;
               end case;
            else -- falling edge
               case ( r.state ) is

                  when TEST_LOGIC_RESET =>
                     v.instructionIdx := DEFAULT_INSTRUCTION;

                  when SHIFT_DR =>
                     v.tdo := r.sr(0); -- bypass
                     
                  when SHIFT_IR =>
                     v.tdo := r.sr(0);
                  when UPDATE_IR =>
                     v.instructionIdx := -1;
                     for idx in 0 to numInstructions(CFG_G) - 1 loop
                        if ( toSlv(CFG_G, idx) = r.sr ) then
                           v.instructionIdx := idx;
                        end if;
                     end loop;
                  when others =>
               end case;
            end if;
         end if;
      end if;
      instructionSel   <= (others => '0');
      captureD         <= '0';
      shiftD           <= '0';
      updateD          <= '0';
      if ( r.state = CAPTURE_DR ) then
         captureD <= '1';
      end if;
      if ( r.state = SHIFT_DR ) then
         shiftD   <= '1';
      end if;
      if ( r.state = UPDATE_DR ) then
         updateD  <= '1';
      end if;
      if ( r.instructionIdx >= 0 ) then
         instructionSel( r.instructionIdx ) <= '1';
      end if;
      rin              <= v;
      tckRising        <= tck and not r.ltck;
      tckFalling       <= r.ltck and not tck;
      tdo              <= r.tdo;
      if ( r.instructionIdx >= 0 ) then
         tdo <= tdoSel(r.instructionIdx);
      end if;
   end process P_COMB;

   P_SEQ : process ( clk ) is
   begin
      if ( rising_edge( clk ) ) then
         if ( rst = '1' ) then
            r <= REG_INIT_C;
         else
            r <= rin;
         end if;
      end if;
   end process P_SEQ;

   state          <= r.state;
   instructionIdx <= r.instructionIdx;
end architecture rtl;
